#!/bin/bash
# Launch the morphing island profile, killing any other quickshell instances first.

systemctl --user stop dunst.service 2>/dev/null
killall -q dunst 2>/dev/null

killall -q quickshell qs 2>/dev/null
sleep 0.3

# Make sure the wallpaper daemon is ready before QuickIsland restores its cache.
if command -v awww >/dev/null 2>&1 && ! awww query >/dev/null 2>&1; then
    if command -v awww-daemon >/dev/null 2>&1 && ! pgrep -x awww-daemon >/dev/null 2>&1; then
        awww-daemon --no-cache >/dev/null 2>&1 &
    fi
    for attempt in {1..40}; do
        awww query >/dev/null 2>&1 && break
        sleep 0.25
    done
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# GPU Selection:
# Always render QuickIsland on the integrated Cezanne GPU (APU).
# This avoids holding the discrete Radeon RX 6800M awake at idle,
# eliminates PCIe cross-GPU transfer overhead, and reduces heat generation.
unset DRI_PRIME

# Ensure user icon themes (~/.local/share/icons) are always found by Qt
export XDG_DATA_DIRS="$HOME/.local/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Detect active icon theme
CURRENT_ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
export QS_ICON_THEME="${CURRENT_ICON_THEME:-Tela-circle-dracula}"

# Default Spatial Workspace to toggled OFF on boot / startup
mkdir -p "$HOME/.cache/quickisland"
echo "0" > "$HOME/.cache/quickisland/spatial_wm_state" 2>/dev/null

exec quickshell -p "$SCRIPT_DIR" "$@"
