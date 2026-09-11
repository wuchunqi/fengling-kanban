#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "$ROOT_DIR/env_setup.sh"

if [[ -f "$ROOT_DIR/config.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/config.env"
fi
PAGES_URL="${PAGES_URL:-https://你的用户名.github.io/你的仓库名/}"

echo "========================================"
echo " 风灵看板一键更新发布"
echo " 项目目录: $ROOT_DIR"
echo "========================================"
echo

chmod +x "./update_and_publish.sh"

LOG_FILE="$ROOT_DIR/last_run.log"
echo "===== 风灵看板更新 $(date '+%F %T') =====" | tee "$LOG_FILE"

set +e
./update_and_publish.sh 2>&1 | tee -a "$LOG_FILE"
status=${PIPESTATUS[0]}
set -e

if [[ "$status" -ne 0 ]]; then
  echo
  echo "执行失败。详细日志已写入："
  echo "  $ROOT_DIR/last_run.log"
  echo
  echo "常见原因："
  echo "1) 未安装依赖: pip3 install -r requirements.txt"
  echo "2) Git 未配置用户名邮箱"
  echo "3) 网络问题导致 push 失败 → 双击「一键推送线上.command」"
  echo "4) 长期班源文件缺失: 需下载「长期班辅导风灵在线明细数据_*.xlsx」"
  echo "5) 看板日期=源文件业务日期，不是下载日期"
  echo
  read -r -p "按回车键关闭窗口..."
  exit 1
fi

echo
echo "执行完成，线上链接："
echo "$PAGES_URL"
echo
read -r -p "按回车键关闭窗口..."
