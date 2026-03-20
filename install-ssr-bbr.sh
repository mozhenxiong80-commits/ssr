#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/mozhenxiong80-commits/ssr/main/install-ssr-bbr-ubuntu24.sh"

bash <(curl -fsSL "${SCRIPT_URL}")
