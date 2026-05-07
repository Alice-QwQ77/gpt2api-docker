# 部署说明

这个目录是一套可以直接消费 GHCR 镜像的 Docker Compose 部署模板。它按上游源码的实际运行方式拆分服务，而不是照搬上游当前存在偏差的文档。

## 服务拓扑

```text
                      ┌──────────────┐
http://host:17080 ───▶│ nginx:17080  │── /api/ ─▶ api:17180
                      │              │── /v1/  ─▶ openai:17200
                      │              │── /     ─▶ user-web:80
                      └──────────────┘

                      ┌──────────────┐
http://host:17088 ───▶│ nginx:17088  │── /admin/api/ ─▶ admin:17188
                      │              │── /           ─▶ admin-web:80
                      └──────────────┘

                      ┌──────────────┐
http://host:17200 ───▶│ nginx:17200  │── /v1/ ─▶ openai:17200
                      └──────────────┘
```

Compose 服务：

| 服务 | 镜像 | 说明 |
| --- | --- | --- |
| `mysql` | `mysql:8.0` | 业务数据库 |
| `redis` | `redis:7-alpine` | 限流、worker、后台任务依赖 |
| `migrate` | `KLEIN_BACKEND_IMAGE` | 一次性运行 goose migration |
| `api` | `KLEIN_BACKEND_IMAGE` | 用户端 API，容器内 `17180` |
| `admin` | `KLEIN_BACKEND_IMAGE` | 管理后台 API，容器内 `17188` |
| `openai` | `KLEIN_BACKEND_IMAGE` | OpenAI 兼容 API，容器内 `17200` |
| `worker` | `KLEIN_BACKEND_IMAGE` | 后台 worker，无 HTTP 端口 |
| `user-web` | `KLEIN_USER_WEB_IMAGE` | 用户前台静态页面 |
| `admin-web` | `KLEIN_ADMIN_WEB_IMAGE` | 管理后台静态页面 |
| `nginx` | `nginx:1.27-alpine` | 对外入口和反向代理 |

## 快速开始

进入部署目录：

```powershell
cd .\deploy
```

生成 `.env`：

```powershell
pwsh -NoProfile -File .\init-env.ps1
```

Linux/macOS：

```sh
sh ./init-env.sh
```

如果 `.env` 已经存在并且需要覆盖：

```powershell
pwsh -NoProfile -File .\init-env.ps1 -Force
```

```sh
FORCE=1 sh ./init-env.sh
```

编辑 `.env`，至少修改数据库密码、DSN、JWT 和 AES 密钥，然后启动：

```powershell
docker compose up -d
```

查看服务：

```powershell
docker compose ps
```

## 环境变量

### 镜像

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `KLEIN_BACKEND_IMAGE` | `ghcr.io/alice-qwq77/gpt2api:latest` | 后端、worker、migrate 共用镜像 |
| `KLEIN_ADMIN_WEB_IMAGE` | `ghcr.io/alice-qwq77/gpt2api-admin-web:latest` | 管理后台前端镜像 |
| `KLEIN_USER_WEB_IMAGE` | `ghcr.io/alice-qwq77/gpt2api-user-web:latest` | 用户前台镜像 |

### 对外端口

| 变量 | 默认值 | 说明 |
| --- | ---: | --- |
| `KLEIN_USER_WEB_PORT` | `17080` | 用户前台入口，同时代理 `/api/` 和 `/v1/` |
| `KLEIN_ADMIN_WEB_PORT` | `17088` | 管理后台入口 |
| `KLEIN_OPENAI_PORT` | `17200` | 单独暴露的 OpenAI 兼容入口 |
| `KLEIN_MYSQL_PORT` | `13306` | 仅绑定 `127.0.0.1` 的 MySQL 调试端口 |
| `KLEIN_REDIS_PORT` | `16379` | 仅绑定 `127.0.0.1` 的 Redis 调试端口 |

### 数据库

| 变量 | 说明 |
| --- | --- |
| `KLEIN_MYSQL_ROOT_PASSWORD` | MySQL root 密码，必须修改 |
| `KLEIN_MYSQL_DB` | 默认数据库名，默认 `klein_ai` |
| `KLEIN_MYSQL_USER` | 业务数据库用户，默认 `klein` |
| `KLEIN_MYSQL_PASSWORD` | 业务数据库密码，必须修改 |
| `KLEIN_DB_DSN` | 后端连接 MySQL 的 DSN，密码要和 `KLEIN_MYSQL_PASSWORD` 一致 |

DSN 示例：

```text
klein:change_this_mysql_password@tcp(mysql:3306)/klein_ai?charset=utf8mb4&parseTime=True&loc=Local
```

### Redis

| 变量 | 说明 |
| --- | --- |
| `KLEIN_REDIS_ADDR` | 后端访问 Redis 的地址，compose 内默认 `redis:6379` |
| `KLEIN_REDIS_PASSWORD` | Redis 密码；留空则 Redis 不启用 requirepass |

如果设置了 `KLEIN_REDIS_PASSWORD`，compose 会同时给 Redis 服务启用 `--requirepass`，并让后端和 Redis healthcheck 使用同一个密码。

### 安全密钥

| 变量 | 要求 |
| --- | --- |
| `KLEIN_JWT_SECRET` | 至少 32 字节 |
| `KLEIN_JWT_REFRESH_SECRET` | 至少 32 字节 |
| `KLEIN_AES_KEY` | 32 字节原文或 64 位 hex |

`KLEIN_AES_KEY` 用于加密账号池凭证。示例值只适合测试，生产必须换掉。

### Provider

默认配置：

```text
KLEIN_PROVIDER_GPT=mock
KLEIN_PROVIDER_GROK=mock
KLEIN_GPT_BASE_URL=https://chatgpt.com
KLEIN_GROK_BASE_URL=https://grok.com
```

`mock` 模式适合先验证部署。生产接真实账号池时改成：

```text
KLEIN_PROVIDER_GPT=real
KLEIN_PROVIDER_GROK=real
```

当前上游真实 provider 工厂读取的是 `KLEIN_GPT_BASE_URL` 和 `KLEIN_GROK_BASE_URL`。上游样例里的 `KLEIN_OPENAI_BASE` / `KLEIN_GROK_BASE` 会进入通用配置结构，但目前不是生成 provider 的主要开关。

真实调用还需要在管理后台导入 GPT/Grok 账号池；只改 provider mode 不会自动拥有可用账号。

### CORS

`KLEIN_CORS_ORIGINS` 是逗号分隔列表。默认：

```text
http://localhost:17080,http://localhost:17088
```

如果你放到正式域名，需要改成实际访问域名，例如：

```text
https://gpt.example.com,https://admin.example.com
```

## 访问地址

| 用途 | 地址 |
| --- | --- |
| 用户前台 | `http://<host>:17080` |
| 管理后台 | `http://<host>:17088` |
| OpenAI API | `http://<host>:17200/v1` |
| 用户前台同源 OpenAI API | `http://<host>:17080/v1` |
| 用户 API 健康 | `http://<host>:17080/healthz` |
| 用户 API 就绪 | `http://<host>:17080/readyz` |
| 管理 API 健康 | `http://<host>:17088/healthz` |
| OpenAI API 健康 | `http://<host>:17200/v1/health` 或 `http://<host>:17080/v1/health` |

`/readyz` 会检查 MySQL 和 Redis。如果 `/healthz` 正常但 `/readyz` 失败，优先检查数据库、Redis、迁移日志和 `.env`。

## 数据库迁移

迁移由 `migrate` 服务执行：

```text
/app/goose -dir /app/migrations mysql "$KLEIN_DB_DSN" up
```

业务服务依赖 `migrate` 成功退出：

```text
migrate -> api/admin/openai/worker
```

这意味着每次 `docker compose up -d` 都会先尝试应用新增迁移。已经执行过的迁移会由 goose 记录，不会重复执行。

查看迁移日志：

```powershell
docker compose logs migrate
```

手动重新执行迁移：

```powershell
docker compose run --rm migrate
```

## 更新

拉取最新镜像并重启：

```powershell
docker compose pull
docker compose up -d
```

只看当前镜像：

```powershell
docker compose images
```

如果想固定某个上游提交对应的镜像，可以把 `.env` 里的 `:latest` 改成 `:upstream-<短 SHA>`。

## 手动指定镜像

PowerShell：

```powershell
pwsh -NoProfile -File .\init-env.ps1 `
  -BackendImage ghcr.io/alice-qwq77/gpt2api:latest `
  -AdminWebImage ghcr.io/alice-qwq77/gpt2api-admin-web:latest `
  -UserWebImage ghcr.io/alice-qwq77/gpt2api-user-web:latest `
  -Force
```

sh：

```sh
BACKEND_IMAGE=ghcr.io/alice-qwq77/gpt2api:latest \
ADMIN_WEB_IMAGE=ghcr.io/alice-qwq77/gpt2api-admin-web:latest \
USER_WEB_IMAGE=ghcr.io/alice-qwq77/gpt2api-user-web:latest \
FORCE=1 \
sh ./init-env.sh
```

## 数据卷

| 卷 | 内容 |
| --- | --- |
| `klein-mysql-data` | MySQL 数据 |
| `klein-redis-data` | Redis AOF 数据 |
| `klein-logs` | 后端日志 |
| `klein-storage` | 生成结果缓存、Grok CF 状态文件 |

不要在升级时删除这些卷。删除卷等同于清空数据库或运行缓存。

## 常用排错

查看所有服务状态：

```powershell
docker compose ps
```

查看后端日志：

```powershell
docker compose logs -f api admin openai worker
```

查看入口 nginx 日志：

```powershell
docker compose logs -f nginx
```

查看 MySQL / Redis：

```powershell
docker compose logs -f mysql redis
```

常见问题：

| 现象 | 优先检查 |
| --- | --- |
| `migrate` 失败 | `KLEIN_DB_DSN`、MySQL 密码、MySQL 是否 healthy |
| `/readyz` 返回失败 | MySQL/Redis 连接、Redis 密码、迁移是否完成 |
| 管理后台能打开但登录失败 | `admin` 服务日志、`/admin/api/v1` 反代、数据库迁移 |
| 用户前台文档里的 `/v1` 不通 | `openai` 服务日志、`17080 /v1/` 或 `17200 /v1/` 入口 |
| 真实生成不可用 | `KLEIN_PROVIDER_GPT/GROK`、账号池、代理池、账号凭证、系统配置 |
| GHCR 拉取失败 | 镜像是否 private、是否执行 `docker login ghcr.io` |

## 清理

停止服务但保留数据：

```powershell
docker compose down
```

停止并删除数据卷：

```powershell
docker compose down -v
```

`down -v` 会删除 MySQL、Redis、日志和存储卷，生产环境不要随手执行。
