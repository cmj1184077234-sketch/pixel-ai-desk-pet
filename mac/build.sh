#!/bin/bash
# 编译 Mac 版叮叮：把 Sources 里的 Swift 代码编译成 DingDing.app
# 用法：bash mac/build.sh        （需要 Xcode 命令行工具：xcode-select --install）
set -e
cd "$(dirname "$0")"
OUT=build
rm -rf "$OUT"; mkdir -p "$OUT"
APP="$OUT/DingDing.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ARCHS="${ARCHS:-arm64 x86_64}"
BINS=""
for a in $ARCHS; do
  swiftc -O -swift-version 5 -target "$a-apple-macos12.0" -o "$OUT/dd-$a" Sources/*.swift \
    -framework AppKit -framework ApplicationServices -framework AVFoundation -framework IOKit
  BINS="$BINS $OUT/dd-$a"
done
lipo -create -output "$APP/Contents/MacOS/DingDing" $BINS
cp Info.plist "$APP/Contents/Info.plist"
cp -R ../assets "$APP/Contents/Resources/assets"
cp -R ../skins "$APP/Contents/Resources/skins"
cp ../config.example.txt "$APP/Contents/Resources/config.example.txt"
mkdir -p "$APP/Contents/Resources/src"
cp Sources/*.swift "$APP/Contents/Resources/src/"     # 自我升级时要用到自己的源代码
codesign --force --deep -s - "$APP"                    # 本机临时签名（Apple 芯片要求必须签名才能运行）
( cd "$OUT" && ditto -c -k --keepParent DingDing.app DingDing-mac.zip )
echo "编译完成：mac/$OUT/DingDing.app"
