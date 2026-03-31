#!/bin/bash
# ClaudeSwitch 一键打包脚本
# 用法: ./build_app.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/ClaudeSwitch.app"

echo "📦 开始打包 ClaudeSwitch..."

# 1. 确保 App Bundle 目录结构完整
echo "  创建目录结构..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 2. 编译 Swift 源码
echo "  编译源码..."
cd "$SCRIPT_DIR/macmenu"
swiftc -o ClaudeSwitchMenu Sources/main.swift \
    -framework AppKit -framework Foundation

# 3. 复制二进制
echo "  复制二进制..."
cp ClaudeSwitchMenu "$APP_DIR/Contents/MacOS/ClaudeSwitch"
chmod +x "$APP_DIR/Contents/MacOS/ClaudeSwitch"

# 4. 生成 App 图标（如 gen_icon.swift 存在）
if [ -f "$SCRIPT_DIR/gen_icon.swift" ]; then
    echo "  生成 App 图标..."
    cd "$SCRIPT_DIR"
    swift gen_icon.swift > /dev/null 2>&1
fi

# 5. 确保 Info.plist 存在
if [ ! -f "$APP_DIR/Contents/Info.plist" ]; then
    echo "  创建 Info.plist..."
    cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeSwitch</string>
    <key>CFBundleIdentifier</key>
    <string>com.claudeswitch.menu</string>
    <key>CFBundleName</key>
    <string>ClaudeSwitch</string>
    <key>CFBundleDisplayName</key>
    <string>Claude Switch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>ClaudeSwitch.icns</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST
fi

# 6. 强制刷新 Finder 图标缓存
echo "  刷新 Finder 图标缓存..."
touch "$APP_DIR"
killall Finder 2>/dev/null || true

echo ""
echo "✅ 打包完成！"
echo "   App 位置: $APP_DIR"
ls -la "$APP_DIR/Contents/"
echo ""
echo "   启动方式: open \"$APP_DIR\""
