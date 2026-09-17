#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
[[ -f config.env ]] && source config.env
PAGES_URL="${PAGES_URL:-https://wuchunqi.github.io/fengling-kanban/}"

echo "推送看板到 GitHub..."
ahead="$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)"
[[ "$ahead" -gt 0 ]] || { echo "无需推送"; read -r -p "按回车关闭..." _; exit 0; }

for i in 1 2 3 4 5; do
  echo "尝试 $i/5 ..."
  if git -c http.version=HTTP/1.1 push origin main; then
    echo "成功: $PAGES_URL"
    read -r -p "按回车关闭..." _
    exit 0
  fi
  sleep 10
done
echo "推送失败，请检查网络/VPN"
read -r -p "按回车关闭..." _
exit 1
