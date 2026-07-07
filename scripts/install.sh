#!/usr/bin/env bash
# 本地打包并安装 NotchClip.app 到 /Applications（无需 Apple 开发者账号，ad-hoc 签名）。
# 用法：bun run install:app   或直接   ./scripts/install.sh
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="NotchClip"
BUILD_DIR="build"
PRODUCT="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"

echo "▶︎ 1/4 生成工程..."
xcodegen generate --spec project.yml

echo "▶︎ 2/4 Release 构建（ad-hoc 签名）..."
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  clean build \
  | grep -E '^\s*(===|\*\*|error:|warning:|note:|Compiling|Signing|CodeSign|BUILD)' || true

if [[ ! -d "$PRODUCT" ]]; then
  echo "✗ 构建产物未找到：$PRODUCT" >&2
  exit 1
fi

echo "▶︎ 3/4 安装到 $DEST（替换旧版本）..."
# 若旧版本正在运行，先退出，否则覆盖会失败
osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
rm -rf "$DEST"
cp -R "$PRODUCT" "$DEST"
# 本地构建通常没有隔离属性，保险起见清一遍，避免 Gatekeeper 拦截
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "▶︎ 4/4 启动..."
open "$DEST"

echo "✅ 已安装并启动：$DEST"
echo "   （首次运行需在 系统设置 → 隐私与安全性 → 辅助功能 中授权 NotchClip）"
