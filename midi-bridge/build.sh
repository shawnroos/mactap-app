#!/bin/bash
# Builds the headless MIDI bridge straight from the app's sensor sources.
# No SwiftPM manifest: the xcodeproj owns the app, this owns one binary.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O \
    -o build/mactap-midi \
    MacTap/Sources/SensorManager.swift \
    MacTap/Sources/TapDetector.swift \
    midi-bridge/Shim.swift \
    midi-bridge/MIDIOut.swift \
    midi-bridge/OSCOut.swift \
    midi-bridge/main.swift \
    -framework CoreMIDI -framework IOKit -framework AppKit -framework QuartzCore
echo "built build/mactap-midi"
