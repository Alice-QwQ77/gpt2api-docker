# deploy

这个目录用于直接消费本仓库发布出的 KleinAI v2 三镜像：

- `ghcr.io/alice-qwq77/gpt2api:latest`
- `ghcr.io/alice-qwq77/gpt2api-admin-web:latest`
- `ghcr.io/alice-qwq77/gpt2api-user-web:latest`

快速开始：

```powershell
pwsh -NoProfile -File .\init-env.ps1
```

脚本会优先从仓库的 `git remote origin` 自动生成：

```text
ghcr.io/alice-qwq77/gpt2api:latest
ghcr.io/alice-qwq77/gpt2api-admin-web:latest
ghcr.io/alice-qwq77/gpt2api-user-web:latest
```

然后你只需要补齐数据库和密钥配置，再执行：

```powershell
docker compose up -d
```

服务启动后：

- `http://<host>:17080` 是用户前台
- `http://<host>:17088` 是管理后台
- `http://<host>:17200/v1` 是 OpenAI 兼容 API
- `mysql` 数据会保存在 `klein-mysql-data` 卷
- `redis` 数据会保存在 `klein-redis-data` 卷
- GHCR 镜像同时提供 `amd64` 和 `arm64`，同一个标签会自动匹配宿主机架构

如果要更新到最新镜像：

```powershell
docker compose pull
docker compose up -d
```

如果当前目录没有 GitHub 远端，可以手动传入镜像地址：

```powershell
pwsh -NoProfile -File .\init-env.ps1
```
