# deploy

这个目录提供一套按上游源码实际运行方式整理过的 Docker Compose 部署方案。

## 架构

Compose 会启动这些服务：

- `mysql`：MySQL 8，保存业务数据
- `redis`：Redis 7，供限流、worker 和后续异步任务使用
- `migrate`：一次性运行 goose 迁移，成功后退出
- `api`：用户端 API，容器内 `17180`
- `admin`：管理后台 API，容器内 `17188`
- `openai`：OpenAI 兼容 API，容器内 `17200`
- `worker`：后台 worker，不监听 HTTP
- `user-web`：用户前台静态文件
- `admin-web`：管理后台静态文件
- `nginx`：外层入口，负责端口暴露和 API 反代

默认对外端口：

```text
17080 -> 用户前台，并代理 /api/ 到 api、/v1/ 到 openai
17088 -> 管理后台，并代理 /admin/api/ 到 admin
17200 -> OpenAI 兼容 API，代理 /v1/ 到 openai
```

## 快速开始

生成 `.env`：

```powershell
pwsh -NoProfile -File .\init-env.ps1
```

Linux/macOS：

```sh
sh ./init-env.sh
```

如果 `.env` 已存在，需要覆盖：

```powershell
pwsh -NoProfile -File .\init-env.ps1 -Force
```

```sh
FORCE=1 sh ./init-env.sh
```

修改 `.env` 后启动：

```powershell
docker compose up -d
```

## 必填配置

首次部署至少修改这些值：

- `KLEIN_MYSQL_ROOT_PASSWORD`
- `KLEIN_MYSQL_PASSWORD`
- `KLEIN_DB_DSN`，其中密码必须和 `KLEIN_MYSQL_PASSWORD` 一致
- `KLEIN_JWT_SECRET`，长度至少 32 字节
- `KLEIN_JWT_REFRESH_SECRET`，长度至少 32 字节
- `KLEIN_AES_KEY`，32 字节原文或 64 位 hex；示例值只适合测试

默认 `KLEIN_PROVIDER_GPT=mock`、`KLEIN_PROVIDER_GROK=mock`，接口会走 mock provider。生产接真实账号池时改成：

```text
KLEIN_PROVIDER_GPT=real
KLEIN_PROVIDER_GROK=real
KLEIN_GPT_BASE_URL=https://chatgpt.com
KLEIN_GROK_BASE_URL=https://grok.com
```

当前真实 provider 工厂读取的是 `KLEIN_GPT_BASE_URL` 和 `KLEIN_GROK_BASE_URL`。上游样例里的 `KLEIN_OPENAI_BASE` / `KLEIN_GROK_BASE` 会进入通用配置结构，但目前不是生成 provider 的主要开关。

真实调用还需要进入管理后台导入 GPT/Grok 账号池和代理配置。

## 检查服务

```powershell
docker compose ps
docker compose logs -f migrate
docker compose logs -f api admin openai worker
```

健康检查地址：

```text
http://<host>:17080/healthz
http://<host>:17080/readyz
http://<host>:17088/healthz
http://<host>:17200/v1/health
http://<host>:17080/v1/health
```

`/readyz` 会检查 MySQL 和 Redis；如果它失败，优先看 `.env` 里的 DSN、Redis 密码和迁移日志。

## 更新镜像

```powershell
docker compose pull
docker compose up -d
```

每次启动都会先跑 `migrate`，所以跟随上游更新后新增 migration 会自动应用到已有数据库。

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

- `klein-mysql-data`：MySQL 数据
- `klein-redis-data`：Redis AOF 数据
- `klein-logs`：后端日志
- `klein-storage`：生成结果缓存、Grok CF 状态文件

不要在升级时删除这些卷，除非你明确要清空数据。
