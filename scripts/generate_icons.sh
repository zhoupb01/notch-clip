#!/usr/bin/env bash
# 由矢量脚本生成全套 App 图标：写入 Assets.xcassets/AppIcon.appiconset 并生成 AppIcon.icns。
# 全程只用系统工具（swift / sips / iconutil）。用法：./scripts/generate_icons.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET_DIR="NotchClip/Resources/Assets.xcassets/AppIcon.appiconset"
ICNS_OUT="build/AppIcon.icns"
TMP="build/iconset.tmp"
MASTER="build/icon_master.png"

mkdir -p "$TMP" "$(dirname "$ICNS_OUT")"

echo "▶︎ 绘制 1024 主图..."
swift scripts/make_icon.swift "$MASTER" 1024 >/dev/null

# 由主图降采样出某尺寸
gen() { sips -s format png -z "$1" "$1" "$MASTER" --out "$2" >/dev/null; }

echo "▶︎ 生成 .appiconset（Xcode 用）..."
for sz in 16 32 64 128 256 512 1024; do
  gen "$sz" "$ICONSET_DIR/icon_${sz}.png"
done

cat > "$ICONSET_DIR/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16",   "filename" : "icon_16.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16",   "filename" : "icon_32.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32",   "filename" : "icon_32.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32",   "filename" : "icon_64.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_256.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_512.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_1024.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "▶︎ 生成 AppIcon.icns（DMG 卷图标用）..."
gen 16   "$TMP/icon_16x16.png"
gen 32   "$TMP/icon_16x16@2x.png"
gen 32   "$TMP/icon_32x32.png"
gen 64   "$TMP/icon_32x32@2x.png"
gen 128  "$TMP/icon_128x128.png"
gen 256  "$TMP/icon_128x128@2x.png"
gen 256  "$TMP/icon_256x256.png"
gen 512  "$TMP/icon_256x256@2x.png"
gen 512  "$TMP/icon_512x512.png"
gen 1024 "$TMP/icon_512x512@2x.png"
mv "$TMP" "build/AppIcon.iconset"
iconutil -c icns "build/AppIcon.iconset" -o "$ICNS_OUT"
rm -rf "build/AppIcon.iconset"

echo "✅ 图标已更新：$ICONSET_DIR/  +  $ICNS_OUT"
