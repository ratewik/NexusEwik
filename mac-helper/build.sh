#!/bin/sh
# NexusEwik — Copyright (C) 2026 ratewik. GPL-3.0, see LICENSE.
# Builds mac-helper with swiftc directly (SwiftPM's manifest API is broken in the installed
# Command Line Tools). Output: .build/release/nexusewik-helper and nexusewik-dockstub
set -e
cd "$(dirname "$0")"
mkdir -p .build/release
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos13.0" \
  -I Sources/VirtualDisplayBridge/include \
  -framework CoreGraphics -framework AppKit -framework ApplicationServices -framework IOKit -framework ScreenCaptureKit -framework CoreMedia -framework NetFS -lsqlite3 \
  Sources/nexusewik-helper/*.swift -o .build/release/nexusewik-helper
echo "built .build/release/nexusewik-helper"
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos13.0" -framework AppKit \
  Sources/nexusewik-dockstub/main.swift -o .build/release/nexusewik-dockstub
echo "built .build/release/nexusewik-dockstub"
# Share menu extension (packed into NexusEwik.app/Contents/PlugIns by mac/build-app.sh).
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos13.0" -application-extension -parse-as-library \
  -module-name NexusEwikShare -framework AppKit -Xlinker -e -Xlinker _NSExtensionMain \
  Sources/nexusewik-share/ShareViewController.swift -o .build/release/nexusewik-share
echo "built .build/release/nexusewik-share"
