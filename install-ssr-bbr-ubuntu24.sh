#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

REPO_TARBALL_URL="https://github.com/ssrlive/shadowsocksr/archive/046078c9568bee891f0ac74085ee82fc08e99e3e.tar.gz"
UPSTREAM_COMMIT="046078c9568bee891f0ac74085ee82fc08e99e3e"
INSTALL_DIR="/opt/shadowsocksr"
SERVICE_NAME="ssr"
BBR_MODULES_FILE="/etc/modules-load.d/bbr.conf"
BBR_SYSCTL_FILE="/etc/sysctl.d/99-bbr.conf"

PORT="${SSR_PORT:-443}"
PASSWORD="${SSR_PASSWORD:-}"
METHOD="${SSR_METHOD:-aes-128-ctr}"
PROTOCOL="${SSR_PROTOCOL:-auth_aes128_md5}"
PROTO_PARAM="${SSR_PROTOCOL_PARAM:-}"
OBFS="${SSR_OBFS:-tls1.2_ticket_auth_compatible}"
OBFS_PARAM="${SSR_OBFS_PARAM:-}"
REMARKS="${SSR_REMARKS:-SSR-Server}"
PKG_MANAGER=""
PKG_FAMILY=""
BBR_STATUS="未检测"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "缺少命令: $1"
    exit 1
  }
}

base64_nopad() {
  python3 - "$1" <<'PY'
import base64
import sys

value = sys.argv[1].encode("utf-8")
print(base64.urlsafe_b64encode(value).decode("ascii").rstrip("="))
PY
}

json_escape() {
  python3 - "$1" <<'PY'
import json
import sys

print(json.dumps(sys.argv[1]))
PY
}

detect_host() {
  local ip=""
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -n "$ip" ]]; then
    printf '%s' "$ip"
  else
    printf '%s' "YOUR_SERVER_IP"
  fi
}

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt-get"
    PKG_FAMILY="deb"
    return
  fi
  if command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    PKG_FAMILY="rpm"
    return
  fi
  if command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
    PKG_FAMILY="rpm"
    return
  fi

  echo "未识别到支持的包管理器，当前脚本只支持 apt-get / dnf / yum"
  exit 1
}

install_dependencies() {
  case "${PKG_MANAGER}" in
    apt-get)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y --no-install-recommends ca-certificates curl openssl python3 tar xz-utils
      ;;
    dnf)
      dnf install -y ca-certificates curl openssl python3 tar xz
      ;;
    yum)
      yum install -y ca-certificates curl openssl tar xz
      if ! command -v python3 >/dev/null 2>&1; then
        yum install -y epel-release || true
        yum install -y python3
      fi
      ;;
  esac
}

configure_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -q '^Status: active'; then
      ufw allow "${PORT}/tcp" >/dev/null
      ufw allow "${PORT}/udp" >/dev/null
    fi
    return
  fi

  if command -v firewall-cmd >/dev/null 2>&1; then
    if systemctl is-active --quiet firewalld 2>/dev/null; then
      firewall-cmd --permanent --add-port="${PORT}/tcp" >/dev/null
      firewall-cmd --permanent --add-port="${PORT}/udp" >/dev/null
      firewall-cmd --reload >/dev/null
    fi
  fi
}

enable_bbr() {
  if ! command -v modprobe >/dev/null 2>&1; then
    BBR_STATUS="跳过: 系统没有 modprobe"
    return
  fi

  if ! modprobe tcp_bbr >/dev/null 2>&1; then
    BBR_STATUS="跳过: 当前内核未提供 tcp_bbr"
    return
  fi

  if ! sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
    BBR_STATUS="跳过: 当前内核不支持原生 BBR"
    return
  fi

  cat >"${BBR_MODULES_FILE}" <<'EOF'
tcp_bbr
EOF

  cat >"${BBR_SYSCTL_FILE}" <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

  if sysctl --system >/dev/null 2>&1; then
    BBR_STATUS="已启用"
  else
    BBR_STATUS="跳过: sysctl 应用失败"
  fi
}

print_summary() {
  local host="$1"
  local password_b64
  local remarks_b64
  local query=""
  local payload=""
  local ssr_url=""

  password_b64="$(base64_nopad "$PASSWORD")"
  remarks_b64="$(base64_nopad "$REMARKS")"

  query="remarks=${remarks_b64}"
  if [[ -n "$PROTO_PARAM" ]]; then
    query="${query}&protoparam=$(base64_nopad "$PROTO_PARAM")"
  fi
  if [[ -n "$OBFS_PARAM" ]]; then
    query="${query}&obfsparam=$(base64_nopad "$OBFS_PARAM")"
  fi

  payload="${host}:${PORT}:${PROTOCOL}:${METHOD}:${OBFS}:${password_b64}/?${query}"
  ssr_url="ssr://$(base64_nopad "$payload")"

  cat <<EOF

安装完成
upstream commit: ${UPSTREAM_COMMIT}
package manager: ${PKG_MANAGER}

Shadowrocket 手动填写
host: ${host}
port: ${PORT}
password: ${PASSWORD}
method: ${METHOD}
protocol: ${PROTOCOL}
protocol_param: ${PROTO_PARAM}
obfs: ${OBFS}
obfs_param: ${OBFS_PARAM}

Shadowrocket 导入链接
${ssr_url}

BBR 状态
${BBR_STATUS}

当前 TCP 拥塞控制
$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)

常用命令
systemctl status ${SERVICE_NAME}
journalctl -u ${SERVICE_NAME} -f
systemctl restart ${SERVICE_NAME}
sysctl net.ipv4.tcp_congestion_control
EOF
}

[[ "${EUID}" -eq 0 ]] || {
  echo "请使用 root 运行，例如: sudo bash install-ssr-bbr-ubuntu24.sh"
  exit 1
}

[[ "${PORT}" =~ ^[0-9]+$ ]] || {
  echo "SSR_PORT 必须是数字"
  exit 1
}

if (( PORT < 1 || PORT > 65535 )); then
  echo "SSR_PORT 必须在 1-65535 之间"
  exit 1
fi

detect_pkg_manager
install_dependencies

need_cmd curl
need_cmd python3
need_cmd systemctl
need_cmd tar
need_cmd sysctl

if [[ -z "${PASSWORD}" ]]; then
  PASSWORD="$(openssl rand -base64 24 | tr -d '\n' | tr '/+' '_-')"
fi

systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

curl -fsSL "${REPO_TARBALL_URL}" | tar -xzf - --strip-components=1 -C "${INSTALL_DIR}"

cat >"${INSTALL_DIR}/user-config.json" <<EOF
{
  "server": "0.0.0.0",
  "server_ipv6": "::",
  "server_port": ${PORT},
  "password": $(json_escape "${PASSWORD}"),
  "method": $(json_escape "${METHOD}"),
  "protocol": $(json_escape "${PROTOCOL}"),
  "protocol_param": $(json_escape "${PROTO_PARAM}"),
  "obfs": $(json_escape "${OBFS}"),
  "obfs_param": $(json_escape "${OBFS_PARAM}"),
  "timeout": 120,
  "udp_timeout": 60,
  "fast_open": false,
  "workers": 1,
  "dns_ipv6": false,
  "connect_verbose_info": 0
}
EOF

chmod 600 "${INSTALL_DIR}/user-config.json"

cat >/etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=ShadowsocksR Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/python3 ${INSTALL_DIR}/shadowsocks/server.py -c ${INSTALL_DIR}/user-config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=51200

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"

configure_firewall
enable_bbr

HOST_DISPLAY="$(detect_host)"
print_summary "${HOST_DISPLAY}"
