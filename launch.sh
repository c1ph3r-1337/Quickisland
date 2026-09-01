#!/bin/bash
# Launch the morphing island profile, killing any other quickshell instances first.

systemctl --user stop dunst.service 2>/dev/null
killall -q dunst 2>/dev/null

killall -q quickshell qs 2>/dev/null
sleep 0.3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DRI_PRIME=pci-0000_03_00_0
exec quickshell -p "$SCRIPT_DIR" "$@"
