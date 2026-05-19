# EMQX 私有化镜像与 Helm Chart 构建

基于 [EMQX 5.8.8](https://github.com/emqx/emqx/releases/tag/v5.8.8) 稳定版，通过 Drone CI 自动构建异构镜像并打包 Helm Chart，推送至私有 Harbor 仓库，供 Kubernetes 集群使用。

## 目录结构

```
emqx/
├── Dockerfile    # 基于官方镜像封装
└── .drone.yml    # Drone CI 流水线
```

## CI 流水线说明

| Pipeline | 说明 |
|----------|------|
| `emqx-amd64` | 构建并推送 amd64 架构镜像 |
| `emqx-arm64` | 构建并推送 arm64 架构镜像 |
| `emqx-manifest` | 合并生成多架构 Manifest 镜像 |
| `emqx-helm` | 拉取官方 Chart 并推送至 Harbor |

触发条件：`main` 分支 `push` 或 `tag` 事件。

## Harbor 存储路径

| 类型 | 地址 |
|------|------|
| 容器镜像 | `harbor.zkjgy.online/library/emqx:5.8.8` |
| Helm Chart | `harbor.zkjgy.online/charts/emqx` |

## Drone Secret 配置

在 Drone 项目设置中添加以下 Secret：

| Secret 名称 | 说明 |
|-------------|------|
| `harbor_username` | Harbor 登录用户名 |
| `harbor_password` | Harbor 登录密码 |

## Kubernetes 部署

```bash
# 登录 Harbor
helm registry login harbor.zkjgy.online \
  --username <user> --password <pass>

# 安装 EMQX
helm install emqx \
  oci://harbor.zkjgy.online/charts/emqx \
  --version 5.8.8 \
  --namespace emqx \
  --create-namespace \
  --set image.repository=harbor.zkjgy.online/library/emqx \
  --set image.tag=5.8.8
```

> 需提前在 K8s 中创建 Harbor 的 `imagePullSecrets`，并在 Harbor 中创建 `charts` 项目。
