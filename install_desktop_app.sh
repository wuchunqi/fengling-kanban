#!/bin/bash
# 安装/修复桌面「每日更新看板」入口
set -euo pipefail

REAL_ROOT="$(cd "$(dirname "$0")" && pwd -P)"
LINK_ROOT="/Users/edy/Desktop/风灵看板复用包"
DESKTOP_CMD="/Users/edy/Desktop/每日更新看板.command"
APP_PATH="/Users/edy/Desktop/每日更新看板.app"
APPLESCRIPT="$REAL_ROOT/_每日更新看板.applescript"

ln -sfn "$REAL_ROOT" "$LINK_ROOT"

chmod +x \
  "$REAL_ROOT/env_setup.sh" \
  "$REAL_ROOT/update_and_publish.sh" \
  "$REAL_ROOT/每日更新看板.command" \
  "$REAL_ROOT/一键更新并发布.command" \
  "$REAL_ROOT/一键推送线上.command" \
  "$REAL_ROOT/install_desktop_app.sh"

cat > "$DESKTOP_CMD" <<EOF
#!/bin/bash
exec bash "$REAL_ROOT/每日更新看板.command"
EOF
chmod +x "$DESKTOP_CMD"

cat > "$APPLESCRIPT" <<APPLESCRIPT
on run
	set projectRoot to "$REAL_ROOT"
	set cmdFile to projectRoot & "/每日更新看板.command"
	tell application "Terminal"
		activate
		do script "bash " & quoted form of cmdFile
	end tell
end run
APPLESCRIPT

rm -rf "$APP_PATH"
osacompile -o "$APP_PATH" "$APPLESCRIPT"

echo "安装完成："
echo "  桌面快捷方式: $DESKTOP_CMD"
echo "  桌面应用: $APP_PATH"
echo "  项目目录: $REAL_ROOT"
