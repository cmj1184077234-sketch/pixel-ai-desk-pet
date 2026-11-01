#!/bin/bash
# 叮叮 · 一键安装 / 更新（Mac）
# 用法：在「终端」里运行
#   curl -fsSL https://raw.githubusercontent.com/cmj1184077234-sketch/pixel-ai-desk-pet/main/install-mac.sh | bash
set -e
REPO=cmj1184077234-sketch/pixel-ai-desk-pet
URL="https://github.com/$REPO/releases/download/mac-test/DingDing-mac.zip"
TMP=$(mktemp -d)
echo "正在下载叮叮……"
curl -fL --progress-bar "$URL" -o "$TMP/dingding.zip"
ditto -x -k "$TMP/dingding.zip" "$TMP"
DEST=/Applications
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x DingDing 2>/dev/null || true
rm -rf "$DEST/DingDing.app"
ditto "$TMP/DingDing.app" "$DEST/DingDing.app"
xattr -dr com.apple.quarantine "$DEST/DingDing.app" 2>/dev/null || true
rm -rf "$TMP"
open "$DEST/DingDing.app"
echo ""
echo "装好了！装在：$DEST/DingDing.app"
echo "记得在「系统设置 → 隐私与安全性 → 辅助功能」里打开 DingDing，它才能发现 AI 做完了、摇铃叫你。"
