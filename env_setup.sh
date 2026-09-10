#!/bin/bash
# Activate project Python environment
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.local/bin:/Library/Developer/CommandLineTools/usr/bin:/usr/bin:/bin:$PATH"

if [[ -x "$ROOT/.venv/bin/python" ]]; then
  VENV="$ROOT/.venv"
elif [[ -x "$HOME/venvs/fengling-kanban/bin/python" ]]; then
  VENV="$HOME/venvs/fengling-kanban"
  ln -sfn "$VENV" "$ROOT/.venv" 2>/dev/null || true
else
  echo "ERROR: no venv found. Bootstrap:"
  echo "  /usr/bin/python3 -m venv \"$HOME/venvs/fengling-kanban\""
  echo "  \"$HOME/venvs/fengling-kanban/bin/pip\" install -r \"$ROOT/requirements.txt\""
  echo "  ln -sfn \"$HOME/venvs/fengling-kanban\" \"$ROOT/.venv\""
  exit 1
fi

# shellcheck disable=SC1091
source "$VENV/bin/activate"
export VIRTUAL_ENV="$VENV"
export PATH="$VENV/bin:$PATH"
echo "Using Python: $(command -v python) ($(python --version 2>&1))"
