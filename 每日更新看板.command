#!/bin/bash
# 每日一键更新入口（双击运行）
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd -P)"
cd "$ROOT"

export PATH="$HOME/.local/bin:/usr/bin:/bin:$PATH"
chmod +x "$ROOT/env_setup.sh" "$ROOT/update_and_publish.sh" 2>/dev/null || true

LOG="$ROOT/last_run.log"
echo "===== 每日更新看板 $(date '+%F %T') =====" | tee "$LOG"

# shellcheck disable=SC1091
source "$ROOT/env_setup.sh" 2>&1 | tee -a "$LOG"
if [[ -f "$ROOT/config.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/config.env"
fi

set +e
"$ROOT/update_and_publish.sh" 2>&1 | tee -a "$LOG"
status=${PIPESTATUS[0]}
set -e

echo "" | tee -a "$LOG"
if [[ "$status" -ne 0 ]]; then
  echo "执行失败，日志: $LOG" | tee -a "$LOG"
  echo "常见原因:" | tee -a "$LOG"
  echo "  1) 5份源文件未全部下载到「下载」文件夹" | tee -a "$LOG"
  echo "  2) 销售表文件名可能是「学习规划师风灵在线率明细数据」" | tee -a "$LOG"
  echo "  3) 网络导致 push 失败 → 双击「一键推送线上.command」" | tee -a "$LOG"
else
  echo "全部完成！" | tee -a "$LOG"
  echo "${PAGES_URL:-https://wuchunqi.github.io/fengling-kanban/}" | tee -a "$LOG"
fi

read -r -p "按回车关闭..." _
exit "$status"
