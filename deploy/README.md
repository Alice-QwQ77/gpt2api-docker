# 部署说明

这个目录使用一个镜像部署完整 gpt2api/KleinAI 服务：

```text
ghcr.io/alice-qwq77/gpt2api:latest
```

虽然只有一个镜像，Compose 仍然会启动多个容器，让每个容器只负责一个角色。

## 服务拓扑

| 服务 | 镜像 | command | 说明 |
| --- | --- | --- | --- |
| `mysql` | `mysql:8.0` | 原生 | 数据库 |
| `redis` | `redis:7-alpine` | 原生 | Redis |
| `migrate` | `KLEIN_IMAGE` | `goose ... up` | 数据库迁移 |
| `api` | `KLEIN_IMAGE` | `api` | 用户 API |
| `admin` | `KLEIN_IMAGE` | `admin` | 管理 API |
| `openai` | `KLEIN_IMAGE` | `openai` | OpenAI 兼容 API |
| `worker` | `KLEIN_IMAGE` | `worker` | 后台 worker |
| `user-web` | `KLEIN_IMAGE` | `user-web` | 用户前台 |
| `admin-web` | `KLEIN_IMAGE` | `admin-web` | 管理后台 |
| `nginx` | `KLEIN_IMAGE` | `nginx -g "daemon off;"` | 外层入口，配置来自 `deploy/nginx` 挂载 |

外部入口：

```text
17080 -> 用户前台，/api/ 到 api，/v1/ 到 openai
17088 -> 管理后台，/admin/api/ 到 admin
17200 -> OpenAI 兼容 API，/v1/ 到 openai
```

## 快速开始

```powershell
cd .\deploy
pwsh -NoProfile -File .\init-env.ps1
notepad .env
docker compose up -d
```

Linux/macOS：

```sh
cd ./deploy
sh ./init-env.sh
vi .env
docker compose up -d
```

如果 `.env` 已存在：

```powershell
pwsh -NoProfile -File .\init-env.ps1 -Force
```

```sh
FORCE=1 sh ./init-env.sh
```

## 必填变量

| 变量 | 说明 |
| --- | --- |
| `KLEIN_IMAGE` | all-in-one 镜像，默认 `ghcr.io/alice-qwq77/gpt2api:latest` |
| `KLEIN_MYSQL_ROOT_PASSWORD` | MySQL root 密码 |
| `KLEIN_MYSQL_PASSWORD` | 业务数据库密码 |
| `KLEIN_DB_DSN` | 后端连接 MySQL 的 DSN |
| `KLEIN_JWT_SECRET` | JWT 密钥，至少 32 字节 |
| `KLEIN_JWT_REFRESH_SECRET` | JWT refresh 密钥，至少 32 字节 |
| `KLEIN_AES_KEY` | 账号池凭证加密密钥，32 字节或 64 位 hex |

DSN 示例：

```text
klein:change_this_mysql_password@tcp(mysql:3306)/klein_ai?charset=utf8mb4&parseTime=True&loc=Local
```

`KLEIN_DB_DSN` 里的密码必须和 `KLEIN_MYSQL_PASSWORD` 一致。

## Provider 配置

默认是 mock 模式：

```text
KLEIN_PROVIDER_GPT=mock
KLEIN_PROVIDER_GROK=mock
```

生产接真实账号池时改成：

```text
KLEIN_PROVIDER_GPT=real
KLEIN_PROVIDER_GROK=real
KLEIN_GPT_BASE_URL=https://api.openai.com
KLEIN_GROK_BASE_URL=https://grok.com
```

还需要进入管理后台导入 GPT/Grok 账号池和代理配置。只改 provider mode 不会自动产生可用账号。

如果使用 ChatGPT Web、Codex 或特定账号池，需要按账号或上游 provider 逻辑单独配置对应 base URL。

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
| OpenAI 健康 | `http://<host>:17200/v1/health` 或 `http://<host>:17080/v1/health` |

## 更新

```powershell
docker compose pull
docker compose up -d
```

每次启动都会先跑 `migrate`，新增迁移会自动应用。

固定某个上游版本时，把 `.env` 里的 `KLEIN_IMAGE` 改成：

```text
KLEIN_IMAGE=ghcr.io/alice-qwq77/gpt2api:upstream-<短 SHA>
```

## 手动指定镜像

PowerShell：

```powershell
pwsh -NoProfile -File .\init-env.ps1 `
  -Image ghcr.io/alice-qwq77/gpt2api:latest `
  -Force
```

sh：

```sh
IMAGE=ghcr.io/alice-qwq77/gpt2api:latest FORCE=1 sh ./init-env.sh
```

## 数据卷

| 卷 | 内容 |
| --- | --- |
| `klein-mysql-data` | MySQL 数据 |
| `klein-redis-data` | Redis AOF 数据 |
| `klein-logs` | 后端日志 |
| `klein-storage` | 生成结果缓存、Grok CF 状态文件 |

不要在升级时删除这些卷。

## 排错

查看状态：

```powershell
docker compose ps
```

查看迁移：

```powershell
docker compose logs migrate
```

查看后端：

```powershell
docker compose logs -f api admin openai worker
```

查看入口：

```powershell
docker compose logs -f nginx
```

常见情况：

| 现象 | 优先检查 |
| --- | --- |
| `migrate` 失败 | MySQL 密码、`KLEIN_DB_DSN`、MySQL 是否 healthy |
| `/readyz` 失败 | MySQL/Redis 连接、Redis 密码、迁移日志 |
| 前端能打开但接口失败 | 外层 nginx 反代、对应后端容器日志 |
| `/v1` 不通 | `openai` 服务日志、`17080 /v1/` 或 `17200 /v1/` |
| 真实生成失败 | provider mode、账号池、代理、账号凭证 |
| GHCR 拉取失败 | 镜像权限、`docker login ghcr.io` |

## 清理

停止但保留数据：

```powershell
docker compose down
```

停止并删除数据：

```powershell
docker compose down -v
```

`down -v` 会删除数据库和 Redis 数据，生产环境不要随手执行。
