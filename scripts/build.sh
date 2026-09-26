#!/bin/bash
set -eo pipefail

BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/moonleaf.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RSC_DIR="$CONTENTS_DIR/Resources"
BIN_DIR="$RSC_DIR/bin"
SAVER_BUILD_DIR="${BUILD_DIR}/saver"
SAVER_DIR="${SAVER_BUILD_DIR}/moonleafSaver.saver"

MP_VER_STRING="v4.0.0"
MP_VER_SHORT_STRING="v4.0"

BUILD_ALL=false
for arg in "$@"; do
    if [[ "$arg" == "--all" ]]; then
        BUILD_ALL=true
    fi
done

if [[ "$BUILD_ALL" == true ]]; then
    echo ""
    read -p "do you really want to build moonleaf for arm64 and x86_64? it will take longer. (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "cancelled..."
        exit 1
    fi
fi

# get host arch
HOST_ARCH=$(uname -m)
if [[ "$HOST_ARCH" == "arm64" ]]; then
    HOST_TARGET="arm64-apple-macos12.0"
elif [[ "$HOST_ARCH" == "x86_64" ]]; then
    HOST_TARGET="x86_64-apple-macos12.0"
else
    # useless else block
    exit 1
fi

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT" || exit 1
rm -rf ./build

mkdir -p "$MACOS_DIR"
mkdir -p "$RSC_DIR"
mkdir -p "$BIN_DIR"

echo ""
echo -e "
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m.[0m[38;5;0m [0m[38;5;0m [0m[38;5;59m-[0m[38;5;145m*[0m[38;5;102m+[0m[38;5;59m-[0m[38;5;17m.[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m.[0m[38;5;17m.[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m.[0m[38;5;109m*[0m[38;5;103m+[0m[38;5;0m.[0m[38;5;146m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;66m=[0m[38;5;0m.[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m.[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;59m:[0m[38;5;59m:[0m[38;5;59m:[0m[38;5;0m.[0m[38;5;0m.[0m[38;5;146m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;146m#[0m[38;5;59m:[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;60m=[0m[38;5;0m.[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;17m.[0m[38;5;17m.[0m[38;5;0m [0m[38;5;60m-[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;59m-[0m[38;5;103m+[0m[38;5;59m:[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;103m+[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;189m%[0m[38;5;188m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m#[0m[38;5;0m.[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;60m-[0m[38;5;146m#[0m[38;5;146m*[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;189m%[0m[38;5;182m#[0m[38;5;146m*[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m#[0m[38;5;188m%[0m[38;5;103m*[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;110m*[0m[38;5;146m*[0m[38;5;146m*[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;189m%[0m[38;5;182m#[0m[38;5;146m*[0m[38;5;189m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;182m#[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;104m*[0m[38;5;146m*[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;189m%[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;189m%[0m[38;5;188m%[0m[38;5;182m#[0m[38;5;59m-[0m[38;5;59m-[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;59m-[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;188m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;189m%[0m[38;5;146m*[0m[38;5;182m#[0m[38;5;189m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;0m.[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;59m-[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;66m=[0m[38;5;147m#[0m[38;5;147m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;147m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;189m%[0m[38;5;188m%[0m[38;5;146m*[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;66m=[0m[38;5;60m=[0m[38;5;110m*[0m[38;5;146m#[0m[38;5;59m-[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;59m-[0m[38;5;0m [0m[38;5;59m-[0m[38;5;146m*[0m[38;5;147m#[0m[38;5;147m#[0m[38;5;147m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;189m%[0m[38;5;146m#[0m[38;5;146m#[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;188m%[0m[38;5;147m#[0m[38;5;147m#[0m[38;5;110m*[0m[38;5;59m:[0m[38;5;59m-[0m[38;5;59m-[0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m.[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;59m-[0m[38;5;103m*[0m[38;5;146m#[0m[38;5;153m#[0m[38;5;153m#[0m[38;5;153m#[0m[38;5;153m#[0m[38;5;153m#[0m[38;5;188m%[0m[38;5;189m%[0m[38;5;182m#[0m[38;5;146m*[0m[38;5;189m%[0m[38;5;188m%[0m[38;5;146m#[0m[38;5;103m+[0m[38;5;59m:[0m[38;5;59m:[0m[38;5;17m.[0m[38;5;60m=[0m[38;5;59m-[0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m.[0m[38;5;59m:[0m[38;5;60m=[0m[38;5;103m+[0m[38;5;103m+[0m[38;5;109m*[0m[38;5;110m*[0m[38;5;145m*[0m[38;5;103m*[0m[38;5;139m*[0m[38;5;102m+[0m[38;5;59m:[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;60m=[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m
        [38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;60m-[0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m[38;5;0m [0m"
echo "####################################################"
echo "        building moonleaf ${MP_VER_STRING} to ${BUILD_DIR}"
echo "####################################################"
echo "macOS $(sw_vers -productVersion), arch: $HOST_ARCH"

echo ""
echo "-- moonleaf --"
if [[ "$BUILD_ALL" == true ]]; then
    swiftc \
        -suppress-warnings \
        -target x86_64-apple-macos12.0 \
        -framework SwiftUI -framework AppKit -framework AVKit \
        -framework AVFoundation -framework UniformTypeIdentifiers \
        -framework Combine -O \
        moonleaf/main/*.swift \
        moonleaf/utils/*.swift \
        -o "$MACOS_DIR/macpaper_amd64"

    echo "compiled moonleaf (amd64) (1/3)"

    swiftc \
        -suppress-warnings \
        -target arm64-apple-macos12.0 \
        -framework SwiftUI -framework AppKit -framework AVKit \
        -framework AVFoundation -framework UniformTypeIdentifiers \
        -framework Combine -O \
        moonleaf/main/*.swift \
        moonleaf/utils/*.swift \
        -o "$MACOS_DIR/macpaper_arm64"

    echo "compiled moonleaf (arm64) (2/3)"

    lipo -create \
        "$MACOS_DIR/macpaper_amd64" \
        "$MACOS_DIR/macpaper_arm64" \
        -o "$MACOS_DIR/moonleaf"

    echo "compiled moonleaf (universal) (3/3)"
    rm "$MACOS_DIR/macpaper_amd64" "$MACOS_DIR/macpaper_arm64"
else
    swiftc \
        -suppress-warnings \
        -target "$HOST_TARGET" \
        -framework SwiftUI -framework AppKit -framework AVKit \
        -framework AVFoundation -framework UniformTypeIdentifiers \
        -framework Combine -O \
        moonleaf/main/*.swift \
        moonleaf/utils/*.swift \
        -o "$MACOS_DIR/moonleaf"

    echo "compiled moonleaf ($HOST_ARCH)"
fi
echo ""

echo ""
echo "-- moonleaf Animated Wallpaper Engine (glasswp) --"

if [[ "$BUILD_ALL" == true ]]; then
    swiftc \
        -suppress-warnings \
        -target x86_64-apple-macos12.0 \
        -framework AppKit -framework AVFoundation \
        -framework MediaToolbox -framework Accelerate \
        -O \
        glasswp/glasswp.swift \
        -o "$MACOS_DIR/glasswp_amd64"

    echo "compiled glasswp (amd64) (1/3)"

    swiftc \
        -suppress-warnings \
        -target arm64-apple-macos12.0 \
        -framework AppKit -framework AVFoundation \
        -framework MediaToolbox -framework Accelerate \
        -O \
        glasswp/glasswp.swift \
        -o "$MACOS_DIR/glasswp_arm64"

    echo "compiled glasswp (arm64) (2/3)"

    lipo -create "$MACOS_DIR/glasswp_amd64" "$MACOS_DIR/glasswp_arm64" \
        -o "$BIN_DIR/glasswp"

    echo "compiled glasswp (universal) (3/3)"
    rm "$MACOS_DIR/glasswp_amd64" "$MACOS_DIR/glasswp_arm64"
else
    swiftc \
        -suppress-warnings \
        -target "$HOST_TARGET" \
        -framework AppKit -framework AVFoundation \
        -framework MediaToolbox -framework Accelerate \
        -O \
        glasswp/glasswp.swift \
        -o "$BIN_DIR/glasswp"

    echo "compiled glasswp ($HOST_ARCH)"
fi
echo ""

echo "-- moonleaf-bin --"

if [[ "$BUILD_ALL" == true ]]; then
    gcc -target x86_64-apple-macos12.0 \
        moonleaf/obj/moonleaf.c -o "$MACOS_DIR/moonleaf-bin_amd64"

    gcc -target arm64-apple-macos12.0 \
        moonleaf/obj/moonleaf.c -o "$MACOS_DIR/moonleaf-bin_arm64"

    lipo -create "$MACOS_DIR/moonleaf-bin_amd64" "$MACOS_DIR/moonleaf-bin_arm64" \
        -o "$MACOS_DIR/moonleaf-bin"

    echo "compiled moonleaf-bin (universal)"
    rm "$MACOS_DIR/moonleaf-bin_amd64" "$MACOS_DIR/moonleaf-bin_arm64"
else
    gcc -target "$HOST_TARGET" \
        moonleaf/obj/moonleaf.c -o "$MACOS_DIR/moonleaf-bin"

    echo "compiled moonleaf-bin ($HOST_ARCH)"
fi
echo ""

echo "adding moonleaf Info.plist"
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>moonleaf</string>
    <key>CFBundleIdentifier</key>
    <string>com.naomisphere.macpaper</string>
    <key>CFBundleName</key>
    <string>moonleaf</string>
    <key>CFBundleDisplayName</key>
    <string>moonleaf</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${MP_VER_SHORT_STRING}</string>
    <key>CFBundleVersion</key>
    <string>${MP_VER_STRING}</string>
    <key>CFBundleIconFile</key>
    <string>moonleaf.icns</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>ATSApplicationFontsPath</key>
    <string>.</string>
</dict>
</plist>
EOF

echo ""
echo "-- bundling app resources --"
cp artwork/icns/moonleaf/moonleaf.icns "$RSC_DIR" 2>/dev/null || true
cp artwork/png/moonleaf.png "${RSC_DIR}/.moonleaf_logo.png" 2>/dev/null || true
cp artwork/png/moonleaf.png "${RSC_DIR}/StatusBarIcon.png" 2>/dev/null || true
cp img/png/kofi_symbol.png "$RSC_DIR/.kofi.png" 2>/dev/null || true

gzip -dc moonleaf/resources/bin/wallpaper.gz > "moonleaf/resources/bin/wallpaper" 2>/dev/null
chmod +x "moonleaf/resources/bin/wallpaper"
cp -R moonleaf/resources/* "$RSC_DIR/" 2>/dev/null || true
rm -f "$RSC_DIR/bin/wallpaper.gz" 2>/dev/null

echo "adding localization strings"
cp -r lang/*.lproj "$RSC_DIR"

echo ""
echo "done! moonleaf ${MP_VER_STRING} is at ${BUILD_DIR}/moonleaf.app"
echo "glasswp installed to: $BIN_DIR/glasswp"
echo ""
