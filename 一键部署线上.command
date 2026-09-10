#!/bin/bash
# 风灵看板 — 一键部署到 GitHub Pages（公开可访问）
set -uo pipefail
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
  "/tmp/gh-install/gh_2.100.0_macOS_amd64/bin/gh" \
  "/tmp/gh-install/gh_2.100.0_macOS_arm64/bin/gh"; do
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
  if ! curl -fsSL --retry 3 -o "$TMPDIR/gh.zip" "https://github.com/cli/cli/releases/download/v2.100.0/$GH_ZIP"; then
    echo "ERROR: 无法下载 gh，请检查网络或开启代理后重试。"
    read -r -p "按回车关闭窗口..." _
    exit 1
  fi
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
gh_login_with_token() {
  echo
  echo "----------------------------------------"
  echo " 使用 Token 登录（推荐，网络更稳定）"
  echo "----------------------------------------"
  echo " 1. 用浏览器打开："
  echo "    https://github.com/settings/tokens/new"
  echo " 2. Note 填: fengling-kanban"
  echo " 3. 勾选权限: repo（全部子项）"
  echo " 4. 点击 Generate token，复制 token（ghp_ 开头）"
  echo
  read -r -p " 请粘贴 Token 后按回车（输入不可见）: " -s TOKEN
  echo
  if [[ -z "$TOKEN" ]]; then
    echo "ERROR: Token 为空"
    return 1
  fi
  echo "$TOKEN" | "$GH" auth login --with-token
}

gh_login() {
  if "$GH" auth status >/dev/null 2>&1; then
    return 0
  fi

  echo
  echo "[3/5] 登录 GitHub..."
  echo "  选择登录方式："
  echo "    1) Token 登录（推荐，避免浏览器 EOF 错误）"
  echo "    2) 浏览器登录"
  read -r -p "  请输入 1 或 2 [默认 1]: " LOGIN_CHOICE
  LOGIN_CHOICE="${LOGIN_CHOICE:-1}"

  if [[ "$LOGIN_CHOICE" == "2" ]]; then
    echo "  正在打开浏览器..."
    if "$GH" auth login --web --git-protocol https; then
      return 0
    fi
    echo "  浏览器登录失败，切换到 Token 登录..."
  fi

  gh_login_with_token
}

echo
if ! gh_login; then
  echo
  echo "ERROR: GitHub 登录失败。"
  echo "  若网络访问 GitHub 不稳定，请开启 VPN/代理后重试，"
  echo "  或在手机热点下重新运行本脚本。"
  read -r -p "按回车关闭窗口..." _
  exit 1
fi

GH_USER="$("$GH" api user -q .login 2>/dev/null || true)"
if [[ -z "$GH_USER" ]]; then
  read -r -p "  无法自动获取 GitHub 用户名，请手动输入: " GH_USER
fi
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
    if ! "$GH" repo create "$REPO_NAME" --public --source=. --remote=origin --description "石家庄风灵看板（短期班+长期班）"; then
      echo
      echo "  自动创建失败，请手动在 GitHub 网页创建公开仓库："
      echo "    名称: $REPO_NAME"
      echo "    https://github.com/new"
      read -r -p "  创建完成后按回车继续..."
      git remote add origin "https://github.com/$GH_USER/$REPO_NAME.git" 2>/dev/null || \
        git remote set-url origin "https://github.com/$GH_USER/$REPO_NAME.git"
    fi
  fi
fi

# 确保有提交
if ! git rev-parse HEAD >/dev/null 2>&1; then
  git add -A
  git -c user.name="$GH_USER" -c user.email="${GH_USER}@users.noreply.github.com" \
    commit -m "init fengling dashboard"
fi

echo "  推送到 GitHub..."
if ! git -c http.version=HTTP/1.1 push -u origin main; then
  echo
  echo "ERROR: push 失败。常见原因：网络问题或 Token 权限不足。"
  echo "  可稍后重试: cd \"$PKG\" && git -c http.version=HTTP/1.1 push -u origin main"
  read -r -p "按回车关闭窗口..." _
  exit 1
fi

# ---------- 5) 开启 GitHub Pages ----------
echo
echo "[5/5] 配置 GitHub Pages..."
if ! "$GH" api "repos/$GH_USER/$REPO_NAME/pages" \
  -X POST \
  -f "build_type=workflow" \
  -f "source[branch]=main" \
  -f "source[path]=/" 2>/dev/null; then
  "$GH" api "repos/$GH_USER/$REPO_NAME/pages" \
    -X PUT \
    -f "build_type=workflow" 2>/dev/null || true
fi

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
echo " 若页面暂未显示，请到 GitHub 仓库确认 Pages 已开启："
echo "   Settings → Pages → Source 选 GitHub Actions"
echo
echo " 之后每日更新：双击「一键更新并发布.command」"
echo "========================================"
read -r -p "按回车关闭窗口..." _
