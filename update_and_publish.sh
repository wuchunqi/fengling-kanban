#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -f "$SCRIPT_DIR/config.env" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/config.env"
fi

ROOT_DIR="${ROOT_DIR:-$SCRIPT_DIR}"
DOWNLOADS_DIR="${DOWNLOADS_DIR:-$HOME/Downloads}"
OUTPUT_ROOT="$ROOT_DIR/每日输出"
STYLE_AUTH_TEMPLATE="${STYLE_AUTH_TEMPLATE:-$ROOT_DIR/templates/样式表2.xlsx}"
STYLE_SALES_TEMPLATE="${STYLE_SALES_TEMPLATE:-$ROOT_DIR/templates/样式表.xlsx}"
PAGES_URL="${PAGES_URL:-https://wuchunqi.github.io/fengling-kanban/}"
DRY_RUN="${DRY_RUN:-0}"
GEN_OK=0
PUSH_OK=0

if [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
  PYTHON="$ROOT_DIR/.venv/bin/python"
elif [[ -x "$HOME/venvs/fengling-kanban/bin/python" ]]; then
  PYTHON="$HOME/venvs/fengling-kanban/bin/python"
else
  PYTHON="$(command -v python3)"
fi
export PATH="$(dirname "$PYTHON"):$PATH"

latest_file_by_prefix() {
  local directory="$1"
  local prefix="$2"
  "$PYTHON" - "$directory" "$prefix" <<'PY'
import sys
from pathlib import Path
directory = Path(sys.argv[1]).expanduser()
prefix = sys.argv[2]
candidates = sorted(
    [p for p in directory.glob(f"{prefix}*.xlsx") if p.is_file() and not p.name.startswith(".~")],
    key=lambda p: p.stat().st_mtime,
    reverse=True,
)
if not candidates:
    sys.exit(2)
print(str(candidates[0]))
PY
}

latest_file_among_prefixes() {
  local directory="$1"
  shift
  "$PYTHON" - "$directory" "$@" <<'PY'
import sys
from pathlib import Path
directory = Path(sys.argv[1]).expanduser()
prefixes = sys.argv[2:]
candidates = []
for prefix in prefixes:
    candidates.extend(
        p for p in directory.glob(f"{prefix}*.xlsx")
        if p.is_file() and not p.name.startswith(".~")
    )
candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
if not candidates:
    sys.exit(2)
print(str(candidates[0]))
PY
}

run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY_RUN] $*"
  else
    eval "$@"
  fi
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

echo "== Step 0: 检查源文件 =="
missing=0
SALES_FILE="" AUTH_HIGH_FILE="" AUTH_AIXUE_FILE="" WECHAT_FILE=""

if SALES_FILE="$(latest_file_among_prefixes "$DOWNLOADS_DIR" \
  "学习规划师风灵在线率明细数据_" "销售风灵在线率明细数据_" 2>/dev/null)"; then
  echo "✓ 销售/规划师: $(basename "$SALES_FILE")"
else
  echo "✗ 缺少: 销售风灵在线率明细数据_*.xlsx 或 学习规划师风灵在线率明细数据_*.xlsx"
  missing=1
fi

if AUTH_HIGH_FILE="$(latest_file_by_prefix "$DOWNLOADS_DIR" "爱芯个微授权数据_" 2>/dev/null)"; then
  if [[ "$AUTH_HIGH_FILE" == *"爱学"* ]]; then
    AUTH_HIGH_FILE="$("$PYTHON" - "$DOWNLOADS_DIR" <<'PY'
import sys
from pathlib import Path
d = Path(sys.argv[1]).expanduser()
files = [p for p in d.glob("爱芯个微授权数据_*.xlsx") if p.is_file() and "爱学" not in p.name and not p.name.startswith(".~")]
files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
if not files: sys.exit(2)
print(str(files[0]))
PY
)"
  fi
  echo "✓ 授权(高中): $(basename "$AUTH_HIGH_FILE")"
else
  echo "✗ 缺少: 爱芯个微授权数据_*.xlsx（不含爱学）"; missing=1
fi

if AUTH_AIXUE_FILE="$(latest_file_by_prefix "$DOWNLOADS_DIR" "爱芯个微授权数据_爱学_" 2>/dev/null)"; then
  echo "✓ 授权(爱学): $(basename "$AUTH_AIXUE_FILE")"
else
  echo "✗ 缺少: 爱芯个微授权数据_爱学_*.xlsx"; missing=1
fi

if WECHAT_FILE="$(latest_file_by_prefix "$DOWNLOADS_DIR" "风灵个微在线数据_" 2>/dev/null)"; then
  echo "✓ 个微: $(basename "$WECHAT_FILE")"
else
  echo "✗ 缺少: 风灵个微在线数据_*.xlsx"; missing=1
fi

CHANGQI_FILE=""
if CHANGQI_FILE="$(latest_file_by_prefix "$DOWNLOADS_DIR" "长期班辅导风灵在线明细数据_" 2>/dev/null)"; then
  echo "✓ 长期班: $(basename "$CHANGQI_FILE")"
else
  echo "✗ 缺少: 长期班辅导风灵在线明细数据_*.xlsx"; missing=1
fi

[[ "$missing" -eq 0 ]] || fail "请将 5 份源文件下载到「下载」文件夹后重试"

cd "$ROOT_DIR"
echo "== Preflight =="; git status -sb || true

echo "== Step 1: 生成 Excel 日报 =="
if run_cmd "cd \"$ROOT_DIR\" && \"$PYTHON\" generate_daily_reports.py \
  --sales \"$SALES_FILE\" --auth-high \"$AUTH_HIGH_FILE\" \
  --wechat \"$WECHAT_FILE\" --auth-aixue \"$AUTH_AIXUE_FILE\" \
  --output-root \"$OUTPUT_ROOT\" \
  --style-auth-template \"$STYLE_AUTH_TEMPLATE\" \
  --style-sales-template \"$STYLE_SALES_TEMPLATE\""; then
  GEN_OK=1
else
  fail "Excel 日报生成失败，请查看上方报错"
fi

echo "== Step 2: 生成短期班网页看板 =="
run_cmd "cd \"$ROOT_DIR\" && \"$PYTHON\" build_daily_web_dashboard.py" || fail "短期班看板生成失败"

if [[ -n "$CHANGQI_FILE" ]]; then
  echo "== Step 2b: 生成长期班看板 =="
  run_cmd "cd \"$ROOT_DIR\" && \"$PYTHON\" build_changqi_dashboard.py --source \"$CHANGQI_FILE\"" || echo "警告: 长期班看板生成失败，短期班已更新"
fi

echo "== Step 3: 提交并推送到 GitHub =="
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY_RUN] git skipped"
else
  cd "$ROOT_DIR"
  git add \
    "每日三表汇总看板.html" "每日三表汇总看板-初中.html" "每日三表汇总看板-高中.html" \
    "周维度在线率看板.html" "周维度在线率看板-初中.html" "周维度在线率看板-高中.html" \
    "访问统计看板.html" "index.html" \
    "长期班风灵在线看板.html" "长期班周维度在线率看板.html" "长期班风灵在线看板_详情" \
    "dashboard_history.csv" "changqi_history.csv" "changqi_detail_history.csv" \
    "每日三表汇总看板_详情" "每日输出" 2>/dev/null || true

  if ! git diff --cached --quiet; then
    git -c user.name="wuchunqi" -c user.email="wuchunqi@users.noreply.github.com" \
      commit -m "update daily dashboard $(date +%F)" || true
  else
    echo "看板数据无变化，跳过 commit"
  fi

  ahead_count="$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)"
  if [[ "$ahead_count" -gt 0 ]]; then
    for attempt in 1 2 3 4 5; do
      echo "git push ${attempt}/5 ..."
      if git -c http.version=HTTP/1.1 -c http.postBuffer=524288000 push origin main 2>&1; then
        PUSH_OK=1
        break
      fi
      sleep 10
    done
  else
    PUSH_OK=1
    echo "已与 GitHub 同步"
  fi
fi

echo ""
echo "========================================"
if [[ "$GEN_OK" -eq 1 ]]; then
  echo " 看板已生成"
  grep -o 'dashboard-sub">[^<]*' "$ROOT_DIR/每日三表汇总看板.html" 2>/dev/null | head -1 || true
fi
if [[ "$PUSH_OK" -eq 1 ]]; then
  echo " 已推送到 GitHub Pages"
  echo " 线上地址: $PAGES_URL"
  echo " 约 1 分钟后刷新: Cmd+Shift+R"
else
  echo " 警告: 推送 GitHub 失败（本地看板已更新）"
  echo " 请检查网络后双击「一键推送线上.command」"
  exit 1
fi
echo "========================================"
