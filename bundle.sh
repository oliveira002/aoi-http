#!/bin/zsh
# Builds Aoi.app and installs it in /Applications.
set -euo pipefail
cd "${0:A:h}"

swift build -c release
binary=.build/release/Aoi
app=.build/Aoi.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Aoi"

iconset=.build/Aoi.iconset
rm -rf "$iconset" && mkdir -p "$iconset"
"$binary" --export-icon .build/icon.png
for size in 16 32 128 256 512; do
    sips -z $size $size .build/icon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) .build/icon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/Aoi.icns"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Aoi</string>
    <key>CFBundleDisplayName</key><string>Aoi</string>
    <key>CFBundleIdentifier</key><string>local.aoi</string>
    <key>CFBundleExecutable</key><string>Aoi</string>
    <key>CFBundleIconFile</key><string>Aoi</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
pkill -x Aoi || true
rm -rf /Applications/Aoi.app
cp -R "$app" /Applications/Aoi.app
echo "Installed /Applications/Aoi.app"
