# gpt2api-docker

这个仓库专门负责给上游 [`432539/gpt2api`](https://github.com/432539/gpt2api) 做自动化 Docker 构建，并且通过 GitHub Actions 定时跟进上游 `main` 分支。

仓库地址：<https://github.com/Alice-QwQ77/gpt2api-docker>

它不直接把上游源码提交进来，而是用 [`upstream.lock.json`](upstream.lock.json) 固定一个上游提交。现在仓库默认适配上游 `v2 / KleinAI` 新结构，也就是：

- `backend`
- `frontend/apps/admin`
- `frontend/apps/user`

## 仓库包含什么

- `upstream.lock.json`
  记录当前锁定的上游提交和源码归档地址。
- `.github/workflows/sync-upstream.yml`
  每天检查一次上游 `main`，有新提交就先构建并发布镜像，再更新锁文件推回本仓库。
- `.github/workflows/docker-publish.yml`
  只要锁文件或构建资产变化，就自动构建并发布镜像到 GHCR。
- `docker/backend.Dockerfile`
  自动构建 KleinAI 后端镜像，内含 `api` / `admin` / `openai` / `worker` 四个二进制。
- `docker/admin-web.Dockerfile`
  自动构建管理后台前端镜像。
- `docker/user-web.Dockerfile`
  自动构建用户前台镜像。
- `deploy/docker-compose.yml`
  一个直接消费已发布镜像的部署示例。

发布出的镜像默认包含多架构清单：

- `linux/amd64`
- `linux/arm64`

为了兼容 ARM，这里的构建链没有沿用上游 `deploy/build-local.*` 里写死 `linux/amd64` 的预编译方式，而是改成了 CI 内按目标架构编译。

## 自动更新流程

1. `sync-upstream` 定时读取 `432539/gpt2api` 的 `main` 最新提交。
2. 如果提交变化，脚本会更新工作区里的 [`upstream.lock.json`](upstream.lock.json)。
3. 同一个工作流直接用这个新提交构建并推送镜像到 GHCR。
4. 镜像发布成功后，工作流再把锁文件提交回本仓库。

`docker-publish` 仍然保留，用来处理你手动修改 `Dockerfile`、`deploy` 目录或工作流本身后的重新发布。

当前仓库固定发布三套镜像：

- `ghcr.io/alice-qwq77/gpt2api:latest`
- `ghcr.io/alice-qwq77/gpt2api-admin-web:latest`
- `ghcr.io/alice-qwq77/gpt2api-user-web:latest`

每套镜像都会保留：

- `:latest`
- `:upstream-<上游短 SHA>`
- `:git-<当前仓库短 SHA>`

## 首次使用

1. 确认仓库已启用 GitHub Actions。
2. 确认包发布权限允许 `GITHUB_TOKEN` 推送到 GHCR。
3. 第一次手动运行 `Sync Upstream` 或直接向 `main` 推送一次。

推送成功后，镜像会出现在：

```text
ghcr.io/alice-qwq77/gpt2api:latest
ghcr.io/alice-qwq77/gpt2api-admin-web:latest
ghcr.io/alice-qwq77/gpt2api-user-web:latest
```

工作流会直接把三套镜像发布到这些固定 GHCR 路径，不需要额外再配镜像名变量。

## 本地手动同步上游

```powershell
pwsh -NoProfile -File .\scripts\sync-upstream.ps1
```

只检查不落盘：

```powershell
pwsh -NoProfile -File .\scripts\sync-upstream.ps1 -DryRun
```

## 本地手动构建镜像

```powershell
pwsh -NoProfile -File .\scripts\build-image.ps1
```

它会读取 [`upstream.lock.json`](upstream.lock.json)，然后本地构建三套镜像：

- `gpt2api-local:dev`
- `gpt2api-admin-web-local:dev`
- `gpt2api-user-web-local:dev`

## 部署

1. 进入 [`deploy`](deploy) 目录。
2. 运行初始化脚本自动生成 `.env`，它会从 `git remote origin` 推导三套 GHCR 镜像地址。
3. 填好 `JWT_SECRET`、`CRYPTO_AES_KEY` 和数据库密码。
4. 执行 `docker compose up -d`。

```powershell
pwsh -NoProfile -File .\deploy\init-env.ps1
cd .\deploy
docker compose up -d
```

如果你的部署目录没有配置 GitHub 远端，也可以手动指定镜像：

```powershell
pwsh -NoProfile -File .\deploy\init-env.ps1
```

## 说明

- 当前工作流默认发布 `linux/amd64` 和 `linux/arm64`，同一个 GHCR 标签会按宿主机架构自动拉取。
- Go 构建版本会从上游提交对应的 `backend/go.mod` 或根 `go.mod` 自动解析。
- 当前主线包装面向上游 v2 新结构；如果上游回退到老结构，workflow 会明确报 unsupported layout。
- 数据库迁移由同一个后端镜像内置的 `/app/goose` 和 `/app/migrations` 完成，compose 会先跑 `migrate` 再启动业务服务。
- 如果你后面想改成 Docker Hub，只需要调整 [`docker-publish.yml`](.github/workflows/docker-publish.yml) 的登录和镜像名逻辑。
