#!/bin/bash
# 激活或自动创建项目 Python 环境
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd -P)"
export PATH="$HOME/.local/bin:/Library/Developer/CommandLineTools/usr/bin:/usr/bin:/bin:$PATH"

PY_BOOT="/usr/bin/python3"
if ! "$PY_BOOT" -c "import sys" >/dev/null 2>&1; then
  PY_BOOT="$(command -v python3)"
fi

if [[ -x "$ROOT/.venv/bin/python" ]]; then
  VENV="$ROOT/.venv"
elif [[ -x "$HOME/venvs/fengling-kanban/bin/python" ]]; then
  VENV="$HOME/venvs/fengling-kanban"
  ln -sfn "$VENV" "$ROOT/.venv" 2>/dev/null || true
else
  echo "[环境] 首次运行，正在创建 Python 虚拟环境..."
  "$PY_BOOT" -m venv "$HOME/venvs/fengling-kanban" 2>/dev/null || "$PY_BOOT" -m venv "$ROOT/.venv"
  if [[ -x "$HOME/venvs/fengling-kanban/bin/python" ]]; then
    VENV="$HOME/venvs/fengling-kanban"
  else
    VENV="$ROOT/.venv"
  fi
  ln -sfn "$VENV" "$ROOT/.venv" 2>/dev/null || true
  # shellcheck disable=SC1091
  source "$VENV/bin/activate"
  python -m pip install -U pip
  python -m pip install -r "$ROOT/requirements.txt"
fi

# shellcheck disable=SC1091
source "$VENV/bin/activate"
export VIRTUAL_ENV="$VENV"
export PATH="$VENV/bin:$PATH"
