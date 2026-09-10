#!/bin/bash
# 风灵看板 — 一键部署到 GitHub Pages（公开可访问）
set -euo pipefail
cd "$(dirname "$0")"
PKG="$(pwd)"

echo "========================================"
echo " 风灵看板 — 部署到 GitHub Pages"
echo " 目录: $PKG"
echo "========================================"
echo

# ---------- 1) 检查 git ----------
if [[ ! -d "$PKG/.git" ]]; then
  echo "[1/5] 初始化 git 仓库..."
  git init -b main
else
  echo "[1/5] git 仓库已存在"
fi

# ---------- 2) 检查 gh CLI ----------
GH=""
for candidate in \
  "$(command -v gh 2>/dev/null || true)" \
  "$HOME/.local/bin/gh" \
  "/tmp/gh-install/gh_2.100.0_macOS_amd64/bin/gh"; do
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    GH="$candidate"
    break
  fi
done

if [[ -z "$GH" ]]; then
  echo "[2/5] 安装 GitHub CLI (gh)..."
  ARCH="$(uname -m)"
  if [[ "$ARCH" == "arm64" ]]; then
    GH_ZIP="gh_2.100.0_macOS_arm64.zip"
  else
    GH_ZIP="gh_2.100.0_macOS_amd64.zip"
  fi
  mkdir -p "$HOME/.local/bin"
  TMPDIR="$(mktemp -d)"
  curl -fsSL -o "$TMPDIR/gh.zip" "https://github.com/cli/cli/releases/download/v2.100.0/$GH_ZIP"
  unzip -qo "$TMPDIR/gh.zip" -d "$TMPDIR"
  cp "$TMPDIR"/gh_*/bin/gh "$HOME/.local/bin/gh"
  chmod +x "$HOME/.local/bin/gh"
  GH="$HOME/.local/bin/gh"
  rm -rf "$TMPDIR"
  echo "  已安装到 $GH"
else
  echo "[2/5] GitHub CLI 已就绪: $GH"
fi

# ---------- 3) GitHub 登录 ----------
echo
echo "[3/5] 检查 GitHub 登录状态..."
if ! "$GH" auth status >/dev/null 2>&1; then
  echo "  需要登录 GitHub（会打开浏览器）..."
  "$GH" auth login --web --git-protocol https
fi
GH_USER="$("$GH" api user -q .login)"
echo "  已登录: $GH_USER"

# ---------- 4) 创建公开仓库并推送 ----------
REPO_NAME="fengling-kanban"
PAGES_URL="https://${GH_USER}.github.io/${REPO_NAME}/"

echo
echo "[4/5] 创建/更新 GitHub 仓库: $GH_USER/$REPO_NAME"

if ! git remote get-url origin >/dev/null 2>&1; then
  if "$GH" repo view "$GH_USER/$REPO_NAME" >/dev/null 2>&1; then
    echo "  仓库已存在，添加 remote..."
    git remote add origin "https://github.com/$GH_USER/$REPO_NAME.git"
  else
    echo "  创建公开仓库..."
    "$GH" repo create "$REPO_NAME" --public --source=. --remote=origin --description "郑州风灵看板（短期班+长期班）"
  fi
fi

# 确保有提交
if ! git rev-parse HEAD >/dev/null 2>&1; then
  git add -A
  git -c user.name="$GH_USER" -c user.email="${GH_USER}@users.noreply.github.com" \
    commit -m "init fengling dashboard"
fi

echo "  推送到 GitHub..."
git push -u origin main

# ---------- 5) 开启 GitHub Pages ----------
echo
echo "[5/5] 配置 GitHub Pages..."
"$GH" api "repos/$GH_USER/$REPO_NAME/pages" \
  -X POST \
  -f "build_type=workflow" \
  -f "source[branch]=main" \
  -f "source[path]=/" 2>/dev/null || \
"$GH" api "repos/$GH_USER/$REPO_NAME/pages" \
  -X PUT \
  -f "build_type=workflow" 2>/dev/null || true

# 更新本地 config.env
if [[ -f "$PKG/config.env" ]]; then
  if grep -q 'PAGES_URL=' "$PKG/config.env"; then
    sed -i '' "s|PAGES_URL=.*|PAGES_URL=\"$PAGES_URL\"|" "$PKG/config.env"
  else
    echo "PAGES_URL=\"$PAGES_URL\"" >> "$PKG/config.env"
  fi
else
  cp "$PKG/config.env.example" "$PKG/config.env"
  sed -i '' "s|PAGES_URL=.*|PAGES_URL=\"$PAGES_URL\"|" "$PKG/config.env"
fi

echo
echo "========================================"
echo " 部署完成！"
echo
echo " 公开访问地址（约 1-2 分钟后生效）："
echo "   $PAGES_URL"
echo
echo " 之后每日更新：双击「一键更新并发布.command」"
echo "========================================"
read -r -p "按回车关闭窗口..." _
