# gpt2api-docker

这个仓库是 [`432539/gpt2api`](https://github.com/432539/gpt2api) 的自动化 Docker 打包与部署仓库。

它不把上游源码提交进来，而是通过 [`upstream.lock.json`](upstream.lock.json) 锁定一个上游提交，在 GitHub Actions 中下载该提交的源码，构建多架构镜像并推送到 GHCR。

仓库地址：<https://github.com/Alice-QwQ77/gpt2api-docker>

## 当前适配的上游结构

上游现在是 `KleinAI v2` 结构，实际运行时不是单进程应用，而是后端四个二进制加两个前端应用。

| 组件 | 上游路径 | 容器内端口 | 主要路径 | 说明 |
| --- | --- | ---: | --- | --- |
| 用户 API | `backend/cmd/api` | `17180` | `/api/v1` | 用户注册、登录、Key、账单、生成任务、资源缓存 |
| 管理 API | `backend/cmd/admin` | `17188` | `/admin/api/v1` | 管理员登录、用户、账号池、代理池、系统配置、日志 |
| OpenAI API | `backend/cmd/openai` | `17200` | `/v1` | OpenAI 兼容接口，支持模型列表、chat、图片、视频 |
| Worker | `backend/cmd/worker` | 无 | 无 | Redis/asynq worker，目前主要处理 Grok CF 刷新和后台任务 |
| 用户前台 | `frontend/apps/user` | `80` | `/` | 默认请求 `/api/v1` 和 `/v1` |
| 管理后台 | `frontend/apps/admin` | `80` | `/` | 默认请求 `/admin/api/v1` |

## 发布镜像

工作流固定发布下面三套 GHCR 镜像，不需要在仓库变量里手动填写镜像名。

| 镜像 | 内容 | 默认用途 |
| --- | --- | --- |
| `ghcr.io/alice-qwq77/gpt2api:latest` | 后端四个二进制、`goose`、迁移文件、配置文件 | `api`、`admin`、`openai`、`worker`、`migrate` 服务共用 |
| `ghcr.io/alice-qwq77/gpt2api-admin-web:latest` | 管理后台静态文件和 nginx | 管理后台页面 |
| `ghcr.io/alice-qwq77/gpt2api-user-web:latest` | 用户前台静态文件和 nginx | 用户前台页面 |

每套镜像都会发布：

- `linux/amd64`
- `linux/arm64`

每次构建会推送这些标签：

- `latest`
- `upstream-<上游短 SHA>`
- `git-<本仓库短 SHA>`，仅 `Docker Publish` 工作流推送

## 自动更新流程

本仓库有两个工作流：

| 工作流 | 触发方式 | 作用 |
| --- | --- | --- |
| `Sync Upstream` | 每天一次，也可手动运行 | 检查上游 `main`，有新提交时更新锁文件、构建镜像、推回本仓库 |
| `Docker Publish` | 推送构建相关文件或手动运行 | 按当前 `upstream.lock.json` 重新构建并发布镜像 |

`Sync Upstream` 的顺序是：

1. 读取 `432539/gpt2api` 的 `main` 最新提交。
2. 如果上游提交变化，更新 `upstream.lock.json`。
3. 下载该上游源码归档，解析 Go 版本和上游布局。
4. 构建并推送三套镜像。
5. 镜像成功发布后，把新的 `upstream.lock.json` 提交回本仓库。

这样可以避免“锁文件已经更新但镜像构建失败”的半成品状态。

## 本仓库对上游的兼容修正

上游当前文档和代码有几处不完全一致，本仓库按源码实际行为做了包装层修正。

| 问题 | 本仓库处理 |
| --- | --- |
| 上游后端 Dockerfile 写死 `GOARCH=amd64` | 本仓库使用 buildx 的 `TARGETOS/TARGETARCH`，支持 `amd64` 和 `arm64` |
| 后端镜像不能固定只跑 `api` | 后端镜像只设置默认 `CMD ["/app/api"]`，compose 用 `command` 分别启动四个后端进程 |
| 数据库迁移不会由业务进程自动执行 | compose 使用独立 `migrate` 服务运行 `/app/goose -dir /app/migrations mysql "$KLEIN_DB_DSN" up` |
| 上游某个 migration 缺少 goose 注解 | 构建期应用 `docker/patches/backend-migrations-goose.patch`，并执行 `goose validate` |
| 上游代码不读取文档里的 `KLEIN_NODE_ID` | 构建期应用 `docker/patches/backend-config-env.patch`，让 `KLEIN_NODE_ID` / `KLEIN_SNOWFLAKE_NODE_ID` 生效 |
| 管理前端 nginx fallback 指向 `/admin/index.html`，但 Vite 没有 `/admin/` base | 前端镜像使用本仓库的 `docker/nginx/*.conf`，统一 fallback 到 `/index.html` |
| 后端 runtime 是 distroless，没有 shell/curl/wget | compose 不给后端配置命令型 healthcheck，避免无意义失败 |

## 快速部署

推荐直接使用 [`deploy`](deploy) 目录。

```powershell
pwsh -NoProfile -File .\deploy\init-env.ps1
cd .\deploy
notepad .env
docker compose up -d
```

首次部署至少修改 `.env` 中这些值：

- `KLEIN_MYSQL_ROOT_PASSWORD`
- `KLEIN_MYSQL_PASSWORD`
- `KLEIN_DB_DSN`，密码要和 `KLEIN_MYSQL_PASSWORD` 一致
- `KLEIN_JWT_SECRET`
- `KLEIN_JWT_REFRESH_SECRET`
- `KLEIN_AES_KEY`

默认 `KLEIN_PROVIDER_GPT=mock`、`KLEIN_PROVIDER_GROK=mock`，适合先验证部署链路。生产接真实账号池时改成 `real`，并进入管理后台导入 GPT/Grok 账号和代理配置。

默认入口：

| 入口 | 地址 |
| --- | --- |
| 用户前台 | `http://<host>:17080` |
| 管理后台 | `http://<host>:17088` |
| OpenAI API | `http://<host>:17200/v1` |
| 用户前台同源 OpenAI API | `http://<host>:17080/v1` |
| 用户 API 健康 | `http://<host>:17080/healthz` |
| 管理 API 健康 | `http://<host>:17088/healthz` |
| OpenAI API 健康 | `http://<host>:17200/v1/health` 或 `http://<host>:17080/v1/health` |

完整部署说明见 [deploy/README.md](deploy/README.md)。

## 本地维护命令

同步上游锁文件：

```powershell
pwsh -NoProfile -File .\scripts\sync-upstream.ps1
```

只检查、不写入：

```powershell
pwsh -NoProfile -File .\scripts\sync-upstream.ps1 -DryRun
```

本地构建三套镜像：

```powershell
pwsh -NoProfile -File .\scripts\build-image.ps1
```

默认本地镜像标签：

```text
gpt2api-local:dev
gpt2api-admin-web-local:dev
gpt2api-user-web-local:dev
```

## 目录说明

| 路径 | 说明 |
| --- | --- |
| `upstream.lock.json` | 当前锁定的上游仓库、分支、提交和源码归档 URL |
| `.github/workflows/sync-upstream.yml` | 每天检查上游并自动构建发布 |
| `.github/workflows/docker-publish.yml` | 本仓库构建资产变化时重新发布镜像 |
| `scripts/sync-upstream.ps1` | 本地或 CI 使用的上游锁文件同步脚本 |
| `scripts/resolve-build-metadata.ps1` | 读取锁文件并解析上游布局、Go 版本、镜像名 |
| `scripts/build-image.ps1` | 本地构建三套镜像 |
| `docker/backend.Dockerfile` | 构建后端多进程镜像和 goose 迁移工具 |
| `docker/admin-web.Dockerfile` | 构建管理后台前端镜像 |
| `docker/user-web.Dockerfile` | 构建用户前台镜像 |
| `docker/nginx/*.conf` | 前端镜像内置静态 nginx 配置 |
| `docker/patches/*.patch` | 上游兼容补丁 |
| `deploy/docker-compose.yml` | 生产/单机部署示例 |
| `deploy/nginx/*.conf` | 外层 nginx 入口和 API 反代配置 |

## 注意事项

- `deploy/.env` 是本地部署配置，已被 `.gitignore` 忽略，不应该提交真实密码。
- GHCR 包如果是 private，部署机器需要先 `docker login ghcr.io`。
- 上游继续大改目录结构时，工作流会在元数据解析或 unsupported layout 步骤明确失败，而不是悄悄构建错误镜像。
- 本地环境没有 Docker 时，仍可以运行元数据脚本和 `.env` 初始化脚本；真实镜像构建以 GitHub Actions 为准。
