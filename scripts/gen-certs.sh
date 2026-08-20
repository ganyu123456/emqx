#!/usr/bin/env bash
# ============================================================
# 云边协同平台 EMQX 单向 TLS 证书生成脚本
# 生成：1 个平台 CA + 每个 EMQX 实例一个服务端证书（SAN=该实例 IP）
#
# 用法：  ./gen-certs.sh
# 输出：  ../certs/ 目录
#   ca.crt            平台 CA 根证书 → 分发给 5 个应用（客户端信任用）
#   <name>.crt/.key   每个 EMQX 的服务端证书 → 创建为 K8s TLS Secret
#
# 注意：
#   - 需本机安装 OpenSSL（macOS 自带 LibreSSL 不兼容，请 brew install openssl）
#   - CA 有效期 10 年，服务端证书 2 年，到期重签服务端证书即可（CA 不变，客户端无感）
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../certs"

CA_DAYS=3650        # CA 有效期（天）
SERVER_DAYS=730     # 服务端证书有效期（天）

# 数据通道服务器清单（6 电厂 × 主备），格式 name:IP
SERVERS=(
  "dongying-primary:10.66.87.82"
  "dongying-backup:10.66.87.83"
  "yuncheng-primary:10.96.43.8"
  "yuncheng-backup:10.96.43.9"
  "huangdao-primary:10.141.28.26"
  "huangdao-backup:10.141.28.27"
  "lubei-primary:10.96.39.41"
  "lubei-backup:10.96.39.42"
  "linqing-primary:10.96.33.55"
  "linqing-backup:10.96.33.56"
  "binzhou-primary:10.96.28.58"
  "binzhou-backup:10.96.28.59"
)

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

echo "==> 生成平台 CA（有效期 ${CA_DAYS} 天）"
openssl genrsa -out ca.key 2048
openssl req -x509 -new -key ca.key -sha256 -days "$CA_DAYS" \
  -subj "/CN=CloudEdge Platform CA" \
  -out ca.crt
echo "    ca.crt 已生成"

echo ""
echo "==> 生成每个 EMQX 的服务端证书（有效期 ${SERVER_DAYS} 天）"
for entry in "${SERVERS[@]}"; do
  name="${entry%%:*}"
  ip="${entry##*:}"
  echo "  - ${name}  (IP: ${ip})"

  openssl genrsa -out "${name}.key" 2048
  openssl req -new -key "${name}.key" \
    -subj "/CN=emqx-${name}" \
    -out "${name}.csr"

  openssl x509 -req -in "${name}.csr" \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -days "$SERVER_DAYS" -sha256 \
    -extfile <(printf "subjectAltName=IP:%s" "$ip") \
    -out "${name}.crt"

  rm -f "${name}.csr"
done

rm -f ca.srl

echo ""
echo "============================================================"
echo "完成。生成的文件："
ls -1 "$OUT_DIR"
echo ""
echo "使用说明："
echo "  1. 把 ca.crt 分发/挂载到 5 个应用（客户端信任 EMQX 用）"
echo "  2. 每个 EMQX 用对应 <name>.crt/.key 创建 TLS Secret："
echo "     kubectl create secret tls emqx-tls-certs \\"
echo "       --cert=<name>.crt --key=<name>.key -n <namespace>"
echo "  3. helm 部署时确保 values.yaml 的 ssl.existingName 与该 Secret 同名"
echo "============================================================"
