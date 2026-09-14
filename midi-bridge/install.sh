#!/bin/bash
# Build the bridge and the device, then put them where Live's browser finds
# them: User Library › Presets › MIDI Effects › Max MIDI Effect › MacTap.
# The device starts the bridge next to it, so this folder is the whole thing.
set -euo pipefail
cd "$(dirname "$0")/.."

./midi-bridge/build.sh
python3 midi-bridge/m4l/build_device.py

DEST="${1:-$HOME/Music/Ableton/User Library/Presets/MIDI Effects/Max MIDI Effect/MacTap}"
mkdir -p "$DEST"
# cat, not cp: cp is aliased -i on some shells and silently refuses to overwrite.
cat build/mactap-midi > "$DEST/mactap-midi"
chmod +x "$DEST/mactap-midi"
cat midi-bridge/m4l/mactap-launch.js > "$DEST/mactap-launch.js"
cat midi-bridge/m4l/MacTap.amxd > "$DEST/MacTap.amxd"
cat midi-bridge/m4l/MacTap.maxpat > "$DEST/MacTap.maxpat"

echo "installed to: $DEST"
echo "in Live: Browser › User Library › Presets › MIDI Effects › Max MIDI Effect › MacTap › MacTap.amxd"
