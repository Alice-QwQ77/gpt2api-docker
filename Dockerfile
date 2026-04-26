# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.20
ARG GO_VERSION=1.22.12
ARG NODE_VERSION=20.19.0
ARG GOOSE_VERSION=v3.20.0
ARG UPSTREAM_REPO=https://github.com/432539/gpt2api.git
ARG UPSTREAM_REF=main
ARG UPSTREAM_REF_SHORT=main
ARG UPSTREAM_ARCHIVE_URL=https://codeload.github.com/432539/gpt2api/tar.gz/main
ARG BUILD_DATE=unknown

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS source
ARG UPSTREAM_ARCHIVE_URL
WORKDIR /src
RUN apk add --no-cache ca-certificates curl tar
RUN curl -fsSL "${UPSTREAM_ARCHIVE_URL}" | tar -xz --strip-components=1 -C /src

FROM --platform=$BUILDPLATFORM node:${NODE_VERSION}-alpine AS web-build
WORKDIR /src/web
COPY --from=source /src/web/package.json /src/web/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY --from=source /src/web ./
RUN npm run build

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS go-build
ARG GOOSE_VERSION
ARG UPSTREAM_REF_SHORT
ARG BUILD_DATE
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src
RUN apk add --no-cache ca-certificates git
COPY --from=source /src/go.mod /src/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY --from=source /src ./
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-$(go env GOARCH)} \
    go build -trimpath \
      -ldflags "-s -w -X main.version=upstream-${UPSTREAM_REF_SHORT} -X main.buildTime=${BUILD_DATE}" \
      -o /out/gpt2api ./cmd/server
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    GOBIN=/out GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-$(go env GOARCH)} CGO_ENABLED=0 \
    go install github.com/pressly/goose/v3/cmd/goose@${GOOSE_VERSION}

FROM alpine:${ALPINE_VERSION}
ARG UPSTREAM_REPO
ARG UPSTREAM_REF
ARG BUILD_DATE
LABEL org.opencontainers.image.title="gpt2api" \
      org.opencontainers.image.description="Automated Docker build for 432539/gpt2api" \
      org.opencontainers.image.vendor="GitHub Actions" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="${UPSTREAM_REPO}" \
      org.opencontainers.image.revision="${UPSTREAM_REF}"

RUN apk add --no-cache ca-certificates tzdata curl bash mariadb-client \
    && update-ca-certificates \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

WORKDIR /app

COPY --from=go-build /out/gpt2api /app/gpt2api
COPY --from=go-build /out/goose /usr/local/bin/goose
COPY --from=web-build /src/web/dist /app/web/dist
COPY --from=source /src/sql /app/sql
COPY --from=source /src/configs /app/configs
COPY deploy/entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/gpt2api /usr/local/bin/goose /app/entrypoint.sh \
    && cp /app/configs/config.example.yaml /app/configs/config.yaml \
    && mkdir -p /app/data/backups /app/logs

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://localhost:8080/healthz || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/gpt2api", "-c", "/app/configs/config.yaml"]
