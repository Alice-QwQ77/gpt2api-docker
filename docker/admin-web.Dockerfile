# syntax=docker/dockerfile:1.7

ARG NODE_VERSION=20
ARG UPSTREAM_ARCHIVE_URL=https://codeload.github.com/432539/gpt2api/tar.gz/main

FROM --platform=$BUILDPLATFORM alpine:3.20 AS source
ARG UPSTREAM_ARCHIVE_URL
WORKDIR /src
RUN apk add --no-cache ca-certificates curl tar
RUN curl -fsSL "${UPSTREAM_ARCHIVE_URL}" | tar -xz --strip-components=1 -C /src

FROM --platform=$BUILDPLATFORM node:${NODE_VERSION}-alpine AS build
WORKDIR /repo
RUN corepack enable
COPY --from=source /src/frontend/pnpm-workspace.yaml /src/frontend/pnpm-lock.yaml /src/frontend/package.json ./
COPY --from=source /src/frontend/tsconfig.base.json ./
COPY --from=source /src/frontend/packages ./packages
COPY --from=source /src/frontend/apps/admin ./apps/admin
RUN --mount=type=cache,target=/root/.local/share/pnpm/store pnpm install --frozen-lockfile=false
RUN pnpm --filter @kleinai/admin build

FROM nginx:1.27-alpine AS runtime
COPY --from=build /repo/apps/admin/dist /usr/share/nginx/html
COPY --from=source /src/frontend/apps/admin/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

