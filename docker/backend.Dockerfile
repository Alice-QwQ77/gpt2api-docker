# syntax=docker/dockerfile:1.7

ARG GO_VERSION=1.24
ARG GOOSE_VERSION=v3.24.3
ARG BUILD_DATE=unknown
ARG VERSION=dev
ARG UPSTREAM_ARCHIVE_URL=https://codeload.github.com/432539/gpt2api/tar.gz/main

FROM --platform=$BUILDPLATFORM alpine:3.20 AS source
ARG UPSTREAM_ARCHIVE_URL
WORKDIR /src
RUN apk add --no-cache ca-certificates curl tar
RUN curl -fsSL "${UPSTREAM_ARCHIVE_URL}" | tar -xz --strip-components=1 -C /src

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS builder
ARG BUILD_DATE
ARG GOOSE_VERSION
ARG VERSION
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src/backend
RUN apk add --no-cache git ca-certificates tzdata
COPY --from=source /src/backend/go.mod /src/backend/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY --from=source /src/backend ./
COPY docker/patches/backend-config-env.patch /tmp/backend-config-env.patch
COPY docker/patches/backend-migrations-goose.patch /tmp/backend-migrations-goose.patch
RUN git apply /tmp/backend-config-env.patch && \
    git apply /tmp/backend-migrations-goose.patch
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-$(go env GOARCH)} \
    go build -trimpath \
      -ldflags="-s -w -X github.com/kleinai/backend/pkg/version.Build=${VERSION} -X github.com/kleinai/backend/pkg/version.Time=${BUILD_DATE}" \
      -o /out/api ./cmd/api && \
    CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-$(go env GOARCH)} \
    go build -trimpath \
      -ldflags="-s -w -X github.com/kleinai/backend/pkg/version.Build=${VERSION}" \
      -o /out/admin ./cmd/admin && \
    CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-$(go env GOARCH)} \
    go build -trimpath \
      -ldflags="-s -w -X github.com/kleinai/backend/pkg/version.Build=${VERSION}" \
      -o /out/openai ./cmd/openai && \
    CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-$(go env GOARCH)} \
    go build -trimpath \
      -ldflags="-s -w -X github.com/kleinai/backend/pkg/version.Build=${VERSION}" \
      -o /out/worker ./cmd/worker
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    mkdir -p /tmp/goose-src && \
    cd /tmp/goose-src && \
    go mod init goose-wrapper && \
    go get github.com/pressly/goose/v3/cmd/goose@${GOOSE_VERSION} && \
    go run github.com/pressly/goose/v3/cmd/goose -dir /src/backend/migrations validate && \
    CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-$(go env GOARCH)} \
    go build -trimpath -ldflags="-s -w" -o /out/goose github.com/pressly/goose/v3/cmd/goose
RUN mkdir -p /out/runtime/logs /out/runtime/storage/public

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /out/api /app/api
COPY --from=builder /out/admin /app/admin
COPY --from=builder /out/openai /app/openai
COPY --from=builder /out/worker /app/worker
COPY --from=builder /out/goose /app/goose
COPY --from=builder /src/backend/configs /app/configs
COPY --from=builder /src/backend/migrations /app/migrations
COPY --from=builder --chown=65532:65532 /out/runtime/logs /app/logs
COPY --from=builder --chown=65532:65532 /out/runtime/storage /app/storage
ENV TZ=Asia/Shanghai
USER 65532:65532
EXPOSE 17180 17188 17200
CMD ["/app/api"]
