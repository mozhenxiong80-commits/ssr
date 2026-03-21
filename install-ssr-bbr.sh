#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/mozhenxiong80-commits/ssr/main/install-ssr-bbr-ubuntu24.sh"
MODE="${1:-menu}"

run_remote() {
  local action="$1"
  shift || true
  bash <(curl -fsSL "${SCRIPT_URL}") "${action}" "$@"
}

show_menu() {
  cat <<'EOF'

SSR 管理菜单
1. 安装 SSR + BBR
2. 卸载 SSR
3. 查看状态
4. 退出
EOF
  printf "请选择 [1-4]: "
  read -r choice

  case "${choice}" in
    1) run_remote install ;;
    2) run_remote uninstall ;;
    3) run_remote status ;;
    4) exit 0 ;;
    *)
      echo "输入无效"
      exit 1
      ;;
  esac
}

case "${MODE}" in
  menu)
    show_menu
    ;;
  install|uninstall|status)
    run_remote "${MODE}"
    ;;
  *)
    echo "用法: bash install-ssr-bbr.sh [menu|install|uninstall|status]"
    exit 1
    ;;
esac
