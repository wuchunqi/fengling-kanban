#!/bin/bash
# 风灵看板 — 本机环境一键准备（请双击运行；在系统终端中执行，不受 Cursor 沙箱限制）
set -euo pipefail
cd "$(dirname "$0")"
PKG="$(pwd)"

echo "========================================"
echo " 风灵看板环境准备"
echo " 目录: $PKG"
echo "========================================"

need_user_action=0

# ---------- 1) Command Line Tools / 基础工具 ----------
if ! xcode-select -p >/dev/null 2>&1; then
  echo ""
  echo "[1/4] 未检测到 Apple 命令行工具，正在弹出安装窗口..."
  echo "      请在弹出框中点击「安装」，完成后回到本窗口按回车继续。"
  xcode-select --install 2>/dev/null || true
  need_user_action=1
  read -r -p "命令行工具安装完成后，按回车继续..." _
fi

# 再检查 python3 / git
if ! /usr/bin/python3 -c 'import sys; print(sys.version)' >/dev/null 2>&1; then
  echo ""
  echo "系统 python3 仍不可用。尝试安装独立 Python（Miniconda）..."
  ARCH="$(uname -m)"
  if [[ "$ARCH" == "arm64" ]]; then
    MINI_URL="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-MacOSX-arm64.sh"
  else
    MINI_URL="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"
  fi
  INSTALLER="/tmp/miniconda-fengling.sh"
  curl -L --retry 3 -o "$INSTALLER" "$MINI_URL"
  bash "$INSTALLER" -b -p "$HOME/miniconda3"
  # shellcheck disable=SC1091
  source "$HOME/miniconda3/etc/profile.d/conda.sh"
  conda install -y python=3.12 pip
  PY="$HOME/miniconda3/bin/python"
  PIP="$HOME/miniconda3/bin/pip"
else
  PY="/usr/bin/python3"
  PIP="/usr/bin/pip3"
  echo "[1/4] 系统 Python 可用: $($PY --version)"
fi

# 若上面走了 miniconda，PY 已设；否则确保 PY 存在
if [[ -z "${PY:-}" ]] || ! "$PY" -c 'import sys' >/dev/null 2>&1; then
  echo "错误：找不到可用的 Python。请先安装："
  echo "  1) 打开「终端」运行: xcode-select --install"
  echo "  或 2) 从 https://www.python.org/downloads/macos/ 安装 Python 3.12"
  read -r -p "按回车退出..." _
  exit 1
fi

# ---------- 2) 虚拟环境 + 依赖 ----------
echo ""
echo "[2/4] 创建虚拟环境并安装 pandas / openpyxl ..."
"$PY" -m pip install --user -U pip virtualenv 2>/dev/null || "$PY" -m pip install -U pip virtualenv
if [[ ! -d "$PKG/.venv" ]]; then
  "$PY" -m virtualenv "$PKG/.venv" 2>/dev/null || "$PY" -m venv "$PKG/.venv"
fi
# shellcheck disable=SC1091
source "$PKG/.venv/bin/activate"
python -m pip install -U pip
python -m pip install -r "$PKG/requirements.txt"
python -c "import pandas, openpyxl; print('依赖 OK:', pandas.__version__, openpyxl.__version__)"

# ---------- 3) 配置与目录 ----------
echo ""
echo "[3/4] 检查配置与目录..."
if [[ ! -f "$PKG/config.env" ]]; then
  cp "$PKG/config.env.example" "$PKG/config.env"
  echo "已创建 config.env（可按需改 PAGES_URL）"
fi
mkdir -p "$PKG/每日输出/初短一部" "$PKG/每日输出/初短二部" "$PKG/每日输出/初短三部" \
  "$PKG/每日输出/郑州特战队" "$PKG/每日输出/小短" "$PKG/每日输出/高短"
chmod +x "$PKG/update_and_publish.sh" "$PKG/一键更新并发布.command" "$PKG/一键准备环境.command" 2>/dev/null || true

# 让一键发布脚本优先用 venv 的 python
if ! grep -q 'FENGLING_VENV' "$PKG/update_and_publish.sh" 2>/dev/null; then
  # 不强制改原脚本；写一个 wrapper 提示即可
  :
fi

# ---------- 4) 可选 git init ----------
echo ""
echo "[4/4] Git 状态..."
if command -v git >/dev/null 2>&1 && git --version >/dev/null 2>&1; then
  if [[ ! -d "$PKG/.git" ]]; then
    git -C "$PKG" init
    echo "已 git init（推送 GitHub Pages 需你自行加 remote）"
  else
    echo "已有 git 仓库"
  fi
else
  echo "git 暂不可用（多半还没装完命令行工具）。本地生成看板不受影响。"
fi

echo ""
echo "========================================"
echo " 环境准备完成！"
echo " 之后每日：双击「一键更新并发布.command」"
echo " 或: source .venv/bin/activate && ./update_and_publish.sh"
echo "========================================"
read -r -p "按回车关闭窗口..." _
