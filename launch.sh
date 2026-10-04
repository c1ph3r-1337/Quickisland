#!/bin/bash
# Launch the morphing island profile, killing any other quickshell instances first.

systemctl --user stop dunst.service 2>/dev/null
killall -q dunst 2>/dev/null

killall -q quickshell qs 2>/dev/null
sleep 0.3

# GPU Selection:
# If on battery, do NOT force rendering through the dGPU over a throttled PCIe bus.
# Running on integrated GPU ensures 120+ FPS smoothness and saves significant battery life.
if [ -f /sys/class/power_supply/ADP0/online ] && [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null)" = "0" ]; then
    unset DRI_PRIME
else
    export DRI_PRIME=pci-0000_03_00_0
fi

# Ensure user icon themes (~/.local/share/icons) are always found by Qt
export XDG_DATA_DIRS="$HOME/.local/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Detect active icon theme
CURRENT_ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
export QS_ICON_THEME="${CURRENT_ICON_THEME:-Tela-circle-dracula}"

# Default Spatial Workspace to toggled OFF on boot / startup
mkdir -p "$HOME/.cache/quickisland"
echo "0" > "$HOME/.cache/quickisland/spatial_wm_state" 2>/dev/null

exec quickshell -p "$SCRIPT_DIR" "$@"
