#!/bin/sh
# NexusEwik — Copyright (C) 2026 ratewik. GPL-3.0, see LICENSE.
# Builds dist/NexusEwik.app (npm run dist). The app code keeps its dev layout inside
# Contents/Resources/app (mac/, shared/, mac-helper/.build/release/) so every `../` path still works;
# no asar, because mac-helper and scripts/*.sh are run straight from there.
set -e
unset ELECTRON_RUN_AS_NODE
cd "$(dirname "$0")"
ROOT=..
STAGE=dist/stage
ARCH=$(uname -m)
[ "$ARCH" = x86_64 ] && ARCH=x64
EV=$(node -p "require('./node_modules/electron/package.json').version")

../mac-helper/build.sh

# NexusEwik for Android with notification access, which the Mac installs on a phone over wireless
# debugging (phone-bridge.js): the newest full build from android/dist, if one was built.
FULL_APK=$(ls "$ROOT"/android/dist/*-full.apk 2>/dev/null | sort | tail -1)
if [ -n "$FULL_APK" ]; then cp "$FULL_APK" vendor/nexusewik-android-full.apk; else echo "note: no android/dist/*-full.apk — the app won't offer the full Android build"; fi

rm -rf "$STAGE" && mkdir -p "$STAGE/mac" "$STAGE/shared" "$STAGE/mac-helper/.build/release" "$STAGE/node_modules"
rsync -a --exclude node_modules --exclude dist --exclude dev --exclude dmg --exclude build-app.sh --exclude build-dmg.sh --exclude scripts/signing-identity.sh ./ "$STAGE/mac/"
cp "$ROOT"/shared/*.js "$STAGE/shared/"
cp "$ROOT"/mac-helper/.build/release/nexusewik-helper "$ROOT"/mac-helper/.build/release/nexusewik-dockstub "$STAGE/mac-helper/.build/release/"
cp -R node_modules/ws "$STAGE/node_modules/"
mkdir -p "$STAGE/mac/node_modules" && cp -R node_modules/ws "$STAGE/mac/node_modules/"
cp "$ROOT/LICENSE" "$STAGE/"
cp "$ROOT/THIRD_PARTY_NOTICES" "$STAGE/"
node -e "
const p = require('./package.json');
require('fs').writeFileSync('$STAGE/package.json', JSON.stringify({
  name: p.name, productName: p.productName, version: p.version, description: p.description,
  license: p.license, main: 'mac/main.js', dependencies: p.dependencies,
}, null, 2));"

# App icon: the NexusEwik dark icon (shared/icon, drawn by make-icon.py).
cp "$ROOT/shared/icon/nexusewik-dark.icns" dist/NexusEwik.icns

cat > dist/extra.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>NSLocalNetworkUsageDescription</key><string>NexusEwik finds and connects to your PC on the local network.</string>
  <key>NSMicrophoneUsageDescription</key><string>NexusEwik sends sound between your Mac and your PC.</string>
  <key>NSAudioCaptureUsageDescription</key><string>NexusEwik sends your Mac's sound to your PC.</string>
  <key>NSCameraUsageDescription</key><string>NexusEwik does not use the camera.</string>
  <key>CFBundleURLTypes</key><array><dict><key>CFBundleURLName</key><string>NexusEwik</string><key>CFBundleURLSchemes</key><array><string>nexusewik</string></array></dict></array>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>Copyright (C) 2026 ratewik. GPL-3.0.</string>
</dict></plist>
EOF

./node_modules/.bin/electron-packager "$STAGE" NexusEwik \
  --platform=darwin --arch="$ARCH" --electron-version="$EV" \
  --app-bundle-id=org.nexusewik.mac --app-version="$(node -p "require('./package.json').version")" \
  --icon=dist/NexusEwik.icns --extend-info=dist/extra.plist \
  --no-prune --asar=false --out=dist --overwrite --quiet

APP="dist/NexusEwik-darwin-$ARCH/NexusEwik.app"
rm -rf dist/NexusEwik.app && mv "$APP" dist/ && rm -rf "dist/NexusEwik-darwin-$ARCH" "$STAGE" dist/extra.plist
# The Share menu extension (mac-helper/Sources/nexusewik-share), sandboxed as macOS requires.
APPEX=dist/NexusEwik.app/Contents/PlugIns/NexusEwikShare.appex
VER="$(node -p "require('./package.json').version")"
mkdir -p "$APPEX/Contents/MacOS"
cp "$ROOT/mac-helper/.build/release/nexusewik-share" "$APPEX/Contents/MacOS/NexusEwikShare"
cat > "$APPEX/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>org.nexusewik.mac.share</string>
  <key>CFBundleName</key><string>NexusEwik</string>
  <key>CFBundleDisplayName</key><string>NexusEwik</string>
  <key>CFBundleExecutable</key><string>NexusEwikShare</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>$VER</string>
  <key>CFBundleVersion</key><string>$VER</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSExtension</key><dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.share-services</string>
    <key>NSExtensionPrincipalClass</key><string>ShareViewController</string>
    <key>NSExtensionAttributes</key><dict>
      <key>NSExtensionActivationRule</key><dict>
        <key>NSExtensionActivationSupportsFileWithMaxCount</key><integer>1000</integer>
      </dict>
    </dict>
  </dict>
</dict></plist>
PLIST
cat > dist/share.entitlements <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.files.user-selected.read-only</key><true/>
</dict></plist>
PLIST

# One signature over the whole bundle (helpers first), so the edited Info.plist is sealed. With
# NexusEwik's own certificate (scripts/signing-identity.sh) macOS keeps its permissions across
# updates; ad-hoc (no certificate made) works, but each update asks for them again.
if KC=$(scripts/signing-identity.sh); then SIGN="--keychain $KC --sign"; ID="NexusEwik Self-Signed"
else echo "note: signing ad-hoc: permissions won't carry over to the next update"; SIGN="--sign"; ID="-"; fi
for b in dist/NexusEwik.app/Contents/Resources/app/mac-helper/.build/release/*; do codesign --force $SIGN "$ID" "$b"; done
codesign --force --deep $SIGN "$ID" dist/NexusEwik.app
codesign --force $SIGN "$ID" --entitlements dist/share.entitlements "$APPEX" # --deep dropped its sandbox
codesign --force $SIGN "$ID" dist/NexusEwik.app && rm -f dist/share.entitlements
codesign -dr - dist/NexusEwik.app 2>&1 | grep designated
echo "built mac/dist/NexusEwik.app"
