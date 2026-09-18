#!/bin/bash
# Launch the morphing island profile, killing any other quickshell instances first.

systemctl --user stop dunst.service 2>/dev/null
killall -q dunst 2>/dev/null

killall -q quickshell qs 2>/dev/null
sleep 0.3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DRI_PRIME=pci-0000_03_00_0

# Ensure user icon themes (~/.local/share/icons) are always found by Qt
export XDG_DATA_DIRS="$HOME/.local/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Detect active icon theme
CURRENT_ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
export QS_ICON_THEME="${CURRENT_ICON_THEME:-Tela-circle-dracula}"

exec quickshell -p "$SCRIPT_DIR" "$@"
