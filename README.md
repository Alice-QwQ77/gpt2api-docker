# gpt2api-docker

这个仓库用于自动跟进上游 [`432539/gpt2api`](https://github.com/432539/gpt2api)，构建并发布可直接部署的 Docker 镜像到 GHCR。

当前上游已经切到 `KleinAI v2` 结构，源码实际由这些部分组成：

- `backend/cmd/api`：用户端 API，监听 `17180`，路径前缀 `/api/v1`
- `backend/cmd/admin`：管理后台 API，监听 `17188`，路径前缀 `/admin/api/v1`
- `backend/cmd/openai`：OpenAI 兼容 API，监听 `17200`，路径前缀 `/v1`
- `backend/cmd/worker`：Redis/asynq worker，目前主要负责 Grok CF cookie 刷新和后续异步任务
- `frontend/apps/user`：用户前台，默认请求 `/api/v1` 和 `/v1`
- `frontend/apps/admin`：管理后台，默认请求 `/admin/api/v1`

## 镜像

工作流固定发布三套镜像，不需要额外填写镜像名变量：

```text
ghcr.io/alice-qwq77/gpt2api:latest
ghcr.io/alice-qwq77/gpt2api-admin-web:latest
ghcr.io/alice-qwq77/gpt2api-user-web:latest
```

每套镜像都会发布 `linux/amd64` 和 `linux/arm64`。后端镜像内包含 `api`、`admin`、`openai`、`worker` 四个二进制，以及 `/app/goose` 和 `/app/migrations`。

## 自动更新

`.github/workflows/sync-upstream.yml` 每天检查一次上游 `main`。如果上游提交变化，工作流会更新 `upstream.lock.json`，先构建并推送新镜像，再把锁文件提交回本仓库。

`.github/workflows/docker-publish.yml` 用于本仓库构建文件、部署文件或锁文件变化后的重新发布。

## 与上游部署说明的差异

上游文档和当前代码有几处不完全匹配，本仓库按源码实际行为处理：

- 上游前端镜像的管理端 nginx fallback 指向 `/admin/index.html`，但 Vite 没有配置 `/admin/` base；本仓库改为根路径部署并 fallback 到 `/index.html`。
- 后端容器需要分别启动 `/app/api`、`/app/admin`、`/app/openai`、`/app/worker`；本仓库后端镜像不再固定 `ENTRYPOINT`，由 compose 明确选择命令。
- 数据库迁移不会由业务进程自动执行；本仓库用独立 `migrate` 服务运行 `/app/goose -dir /app/migrations mysql "$KLEIN_DB_DSN" up`。
- 上游代码没有读取文档里的 `KLEIN_NODE_ID`；本仓库构建时加入兼容补丁，让 `KLEIN_NODE_ID` / `KLEIN_SNOWFLAKE_NODE_ID` 可用于区分多进程 Snowflake 节点。
- 后端是 distroless nonroot 镜像，没有 shell/curl/wget；compose 不使用假的命令型 healthcheck。

## 部署

推荐直接使用 [`deploy`](deploy) 目录：

```powershell
pwsh -NoProfile -File .\deploy\init-env.ps1
cd .\deploy
notepad .env
docker compose up -d
```

至少需要修改 `.env` 里的数据库密码、`KLEIN_DB_DSN`、`KLEIN_JWT_SECRET`、`KLEIN_JWT_REFRESH_SECRET`、`KLEIN_AES_KEY`。生产接真实上游时，把 `KLEIN_PROVIDER_GPT` / `KLEIN_PROVIDER_GROK` 从 `mock` 改成 `real`，并在管理后台导入账号池。

启动后默认入口：

```text
用户前台:        http://<host>:17080
管理后台:        http://<host>:17088
OpenAI API:      http://<host>:17200/v1
用户 API 健康:   http://<host>:17080/healthz
管理 API 健康:   http://<host>:17088/healthz
OpenAI 健康:     http://<host>:17200/v1/health
```

更多部署细节见 [`deploy/README.md`](deploy/README.md)。

## 本地脚本

同步上游锁文件：

```powershell
pwsh -NoProfile -File .\scripts\sync-upstream.ps1
```

本地构建三套镜像：

```powershell
pwsh -NoProfile -File .\scripts\build-image.ps1
```

默认本地标签：

```text
gpt2api-local:dev
gpt2api-admin-web-local:dev
gpt2api-user-web-local:dev
```

## 目录说明

- `docker/backend.Dockerfile`：构建后端多进程镜像和 goose 迁移工具
- `docker/admin-web.Dockerfile`：构建管理后台静态镜像
- `docker/user-web.Dockerfile`：构建用户前台静态镜像
- `docker/nginx/*.conf`：前端镜像内置静态 nginx 配置
- `docker/patches/backend-config-env.patch`：构建期兼容补丁，目前用于 Snowflake 节点环境变量
- `deploy/docker-compose.yml`：一键部署 MySQL、Redis、迁移、后端、前端和外层 nginx
- `deploy/nginx/*.conf`：外层 nginx 统一入口和 API 反代配置
