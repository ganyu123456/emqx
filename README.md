# EMQX 私有化镜像与 Helm Chart 构建

基于 [EMQX 5.8.8](https://github.com/emqx/emqx/releases/tag/v5.8.8) 稳定版，通过 Drone CI 自动构建异构镜像并打包本地魔改 Helm Chart，推送至私有 Harbor 仓库，供 Kubernetes 集群使用。

## 目录结构

```
emqx/
├── Dockerfile              # 基于官方镜像封装
├── .drone.yml              # Drone CI 流水线
└── helm/emqx/
    ├── Chart.yaml          # Chart 元信息
    └── values.yaml         # 单节点 hostNetwork 模式配置
    └── templates/
        └── StatefulSet.yaml  # 已支持 hostNetwork / dnsPolicy
```

## CI 流水线说明

| Pipeline | 说明 |
|----------|------|
| `emqx-amd64` | 构建并推送 amd64 架构镜像 |
| `emqx-arm64` | 构建并推送 arm64 架构镜像 |
| `emqx-manifest` | 合并生成多架构 Manifest 镜像 |
| `emqx-helm` | 打包本地 Chart 并推送至 Harbor |

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

### 前置准备

```bash
# 登录 Harbor
helm registry login harbor.zkjgy.online \
  --username <user> --password <pass>
```

> 需提前在 K8s 中创建 Harbor 的 `imagePullSecrets`，并在 Harbor 中创建 `charts` 项目。

---

### 模式一：集群模式（默认，3 节点）

适用于生产环境，3 个 EMQX 节点自动组成集群，具备高可用能力。

```bash
helm install emqx \
  oci://harbor.zkjgy.online/charts/emqx \
  --version 5.8.8 \
  --namespace emqx \
  --create-namespace \
  --set image.repository=harbor.zkjgy.online/library/emqx \
  --set image.tag=5.8.8
```

| 配置项 | 值 |
|--------|---|
| 节点数 | 3 |
| 网络模式 | 集群内部网络 |
| MQTT 端口 | `1883` |
| Dashboard 端口 | `18083` |
| 高可用 | 支持 |

---

### 模式二：单节点 hostNetwork 模式

适用于边缘节点或资源受限环境，Pod 直接使用宿主机网络，设备通过宿主机 IP 直接访问。

```bash
helm install emqx \
  oci://harbor.zkjgy.online/charts/emqx \
  --version 5.8.8 \
  --namespace emqx \
  --create-namespace
```

| 配置项 | 值 |
|--------|---|
| 节点数 | 1 |
| 网络模式 | hostNetwork（宿主机网络） |
| MQTT 端口 | `11883`（避开 1883）|
| Dashboard 端口 | `18083` |
| 高可用 | 不支持 |

> **注意**：hostNetwork 模式下，Pod 直接占用宿主机端口，请确保宿主机上 `11883`、`8883`、`8083`、`18083` 端口未被占用。

---

### 升级与卸载

```bash
# 升级
helm upgrade emqx oci://harbor.zkjgy.online/charts/emqx \
  --version 5.8.8 -n emqx

# 卸载
helm uninstall emqx -n emqx
```
