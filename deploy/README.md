# deploy

这个目录用于直接消费本仓库发布出的镜像。

快速开始：

```powershell
pwsh -NoProfile -File .\init-env.ps1
```

脚本会优先从仓库的 `git remote origin` 自动生成：

```text
ghcr.io/alice-qwq77/gpt2api:latest
```

然后你只需要补齐密码类配置，再执行：

```powershell
docker compose up -d
```

服务启动后：

- `http://<host>:8080` 是 Web 控制台和 API 入口
- `mysql` 数据会保存在 `mysql_data` 卷
- `redis` 数据会保存在 `redis_data` 卷
- 备份文件会保存在 `backups` 卷
- GHCR 镜像同时提供 `amd64` 和 `arm64`，同一个标签会自动匹配宿主机架构

如果要更新到最新镜像：

```powershell
docker compose pull
docker compose up -d
```

如果当前目录没有 GitHub 远端，可以手动传入镜像地址：

```powershell
pwsh -NoProfile -File .\init-env.ps1 -Image ghcr.io/alice-qwq77/gpt2api:latest
```
