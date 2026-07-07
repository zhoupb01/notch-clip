#!/usr/bin/env bash
# 打包 NotchClip 为可分发 DMG（含 Applications 拖拽软链接 + 卷图标）。全程系统工具。
# 用法：bun run dmg   或   ./scripts/make_dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="NotchClip"
VOL="$APP_NAME"
BUILD_DIR="build"
PRODUCT="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
STAGE="$BUILD_DIR/dmg_stage"
MOUNT_DIR="$BUILD_DIR/dmg_mount"
ICNS="$BUILD_DIR/AppIcon.icns"

VERSION=$(grep -m1 'MARKETING_VERSION' project.yml | sed -E 's/.*"([^"]+)".*/\1/' || true)
VERSION=${VERSION:-1.0}
DMG_OUT="$BUILD_DIR/${APP_NAME}-${VERSION}.dmg"

echo "▶︎ 1/5 生成图标..."
./scripts/generate_icons.sh

echo "▶︎ 2/5 Release 构建..."
xcodegen generate --spec project.yml >/dev/null
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$BUILD_DIR" clean build \
  | grep -E 'error:|\*\* BUILD' || true
[[ -d "$PRODUCT" ]] || { echo "✗ 构建产物缺失：$PRODUCT" >&2; exit 1; }

echo "▶︎ 3/5 准备 DMG 内容..."
rm -rf "$STAGE" "$DMG_OUT" "$MOUNT_DIR"
mkdir -p "$STAGE" "$MOUNT_DIR"
cp -R "$PRODUCT" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ICNS" "$STAGE/.VolumeIcon.icns"

echo "▶︎ 4/5 打包并压缩..."
TMP_DMG="$BUILD_DIR/tmp.dmg"
rm -f "$TMP_DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$TMP_DMG" >/dev/null
hdiutil attach "$TMP_DMG" -readwrite -noverify -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null
SetFile -a C "$MOUNT_DIR" 2>/dev/null || true   # 启用自定义卷图标位
# Finder 图标布局（无 GUI/Finder 时自动跳过，不影响 DMG 可用性）
osascript <<EOF 2>/dev/null || true
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {220, 140, 780, 520}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 120
    set position of item "$APP_NAME.app" of container window to {150, 190}
    set position of item "Applications" of container window to {410, 190}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
sync
hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUT" >/dev/null
rm -f "$TMP_DMG"; rm -rf "$STAGE" "$MOUNT_DIR"

echo "✅ DMG 已生成：$DMG_OUT"
echo "   发给别人：对方双击 → 把 NotchClip 拖进 Applications 即可。"
echo "   注意：ad-hoc 签名，对方首次打开需右键→打开（或 系统设置→隐私与安全性 里点\"仍要打开\"）。"
open -R "$DMG_OUT" 2>/dev/null || true
