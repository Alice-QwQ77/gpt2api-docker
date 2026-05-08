# gpt2api-docker

这个仓库用于自动跟进上游 [`432539/gpt2api`](https://github.com/432539/gpt2api)，并把它打成一个可部署的 GHCR 镜像。

仓库只发布一个镜像：

```text
ghcr.io/alice-qwq77/gpt2api:latest
```

这个镜像是 all-in-one 形式，里面同时包含：

- 后端二进制：`api`、`admin`、`openai`、`worker`
- 数据库迁移工具：`goose`
- 数据库迁移文件：`/app/migrations`
- 用户前台静态文件
- 管理后台静态文件
- 前端 nginx 配置
- 外层入口 nginx 运行时

部署时仍然建议用多个容器拆分角色，但这些容器全部拉同一个镜像，通过不同 `command` 启动不同角色。

## 上游结构

当前上游是 `KleinAI v2` 结构，实际运行组件如下：

| 角色 | 上游路径 | 端口 | 路径 |
| --- | --- | ---: | --- |
| 用户 API | `backend/cmd/api` | `17180` | `/api/v1` |
| 管理 API | `backend/cmd/admin` | `17188` | `/admin/api/v1` |
| OpenAI API | `backend/cmd/openai` | `17200` | `/v1` |
| Worker | `backend/cmd/worker` | 无 | 无 |
| 用户前台 | `frontend/apps/user` | `80` | `/` |
| 管理后台 | `frontend/apps/admin` | `80` | `/` |

## 镜像命令

同一个镜像支持这些命令：

| 命令 | 作用 |
| --- | --- |
| `api` | 启动用户 API |
| `admin` | 启动管理 API |
| `openai` | 启动 OpenAI 兼容 API |
| `worker` | 启动后台 worker |
| `goose ...` | 执行数据库迁移命令 |
| `user-web` | 启动用户前台 nginx |
| `admin-web` | 启动管理后台 nginx |
| `nginx -g "daemon off;"` | 启动镜像内 nginx；compose 会挂载入口反代配置 |

示例：

```powershell
docker run --rm ghcr.io/alice-qwq77/gpt2api:latest api
docker run --rm ghcr.io/alice-qwq77/gpt2api:latest admin-web
```

## 自动更新

`Sync Upstream` 每天检查一次上游 `main`。如果发现上游提交变化，会：

1. 更新 `upstream.lock.json`。
2. 下载上游源码归档。
3. 构建单个 all-in-one 镜像。
4. 推送 `latest` 和 `upstream-<短 SHA>`。
5. 构建成功后提交锁文件。

`Docker Publish` 会在构建文件、脚本或锁文件变化时重新发布镜像，并额外推送 `git-<本仓库短 SHA>` 标签。

镜像支持：

- `linux/amd64`
- `linux/arm64`

## 包装层修正

本仓库按上游源码实际行为做了一些包装层修正：

| 上游问题 | 本仓库处理 |
| --- | --- |
| 上游 Dockerfile 曾写死 amd64 | 使用 buildx `TARGETOS/TARGETARCH`，支持 amd64 和 arm64 |
| 后端实际是四个进程 | 单镜像内置四个二进制，用 `command` 选择角色 |
| 数据库迁移不会自动执行 | compose 使用 `migrate` 服务运行 `/app/goose` |
| 上游某个 migration 缺 goose 注解 | 构建期补丁修正，并执行 `goose validate` |
| `KLEIN_NODE_ID` 文档变量原本不生效 | 构建期补丁让 `KLEIN_NODE_ID` / `KLEIN_SNOWFLAKE_NODE_ID` 生效 |
| 管理前端 nginx fallback 与 Vite base 不匹配 | 使用本仓库前端 nginx 配置，统一 fallback 到 `/index.html` |

## 快速部署

```powershell
pwsh -NoProfile -File .\deploy\init-env.ps1
cd .\deploy
notepad .env
docker compose up -d
```

首次部署至少修改：

- `KLEIN_MYSQL_ROOT_PASSWORD`
- `KLEIN_MYSQL_PASSWORD`
- `KLEIN_DB_DSN`
- `KLEIN_JWT_SECRET`
- `KLEIN_JWT_REFRESH_SECRET`
- `KLEIN_AES_KEY`

默认入口：

| 用途 | 地址 |
| --- | --- |
| 用户前台 | `http://<host>:17080` |
| 管理后台 | `http://<host>:17088` |
| OpenAI API | `http://<host>:17200/v1` |
| 用户前台同源 OpenAI API | `http://<host>:17080/v1` |

完整部署说明见 [deploy/README.md](deploy/README.md)。

## 本地维护

同步上游：

```powershell
pwsh -NoProfile -File .\scripts\sync-upstream.ps1
```

只检查不写入：

```powershell
pwsh -NoProfile -File .\scripts\sync-upstream.ps1 -DryRun
```

本地构建：

```powershell
pwsh -NoProfile -File .\scripts\build-image.ps1
```

默认本地标签：

```text
gpt2api-local:dev
```

## 目录

| 路径 | 说明 |
| --- | --- |
| `upstream.lock.json` | 锁定的上游提交 |
| `docker/backend.Dockerfile` | all-in-one 镜像构建文件 |
| `docker/entrypoint.sh` | 单镜像多角色入口 |
| `docker/nginx/*.conf` | 镜像内前端 nginx 配置 |
| `docker/patches/*.patch` | 上游兼容补丁 |
| `deploy/docker-compose.yml` | 单镜像多容器部署模板 |
| `deploy/nginx/*.conf` | 外层 nginx 入口配置 |
| `scripts/*.ps1` | 上游同步、元数据解析、本地构建脚本 |
