#!/usr/bin/env bash
set -Eeuo pipefail

MODULES_FILE="/etc/modules-load.d/bbr.conf"
SYSCTL_FILE="/etc/sysctl.d/99-bbr.conf"

[[ "${EUID}" -eq 0 ]] || {
  echo "请使用 root 运行，例如: sudo bash install-bbr-ubuntu24.sh"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "缺少命令: $1"
    exit 1
  }
}

need_cmd modprobe
need_cmd sysctl

modprobe tcp_bbr

if ! sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
  echo "当前内核未提供 tcp_bbr，无法启用原生 BBR"
  exit 1
fi

cat >"${MODULES_FILE}" <<'EOF'
tcp_bbr
EOF

cat >"${SYSCTL_FILE}" <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

sysctl --system >/dev/null

echo
echo "BBR 已启用"
echo "current qdisc: $(sysctl -n net.core.default_qdisc)"
echo "current congestion control: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "available congestion control: $(sysctl -n net.ipv4.tcp_available_congestion_control)"
