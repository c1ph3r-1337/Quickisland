#!/usr/bin/env bash
STATE=$1
SPATIAL_CONF="$HOME/.config/quickshell/quickisland/hypr/spatial_wm.conf"
mkdir -p "$(dirname "$SPATIAL_CONF")"
COORD_FILE=~/.cache/quickisland/spatial_workspace_coords

# Ensure spatial_wm.conf is empty so it does NOT inject duplicate keybindings into Hyprland
echo "# Keybindings are permanently managed in ~/.config/hypr/userprefs.conf" > "$SPATIAL_CONF"

if [[ "$STATE" == "on" ]]; then
    # Save state
    mkdir -p ~/.cache/quickisland
    echo "1" > ~/.cache/quickisland/spatial_wm_state
    
    # Reset coordinates
    echo "0 0" > "$COORD_FILE"
    echo "0 0" > ~/.cache/quickisland/infinite_canvas_coords
    quickshell ipc -p ~/.config/quickshell/quickisland call virtual_workspace set_coords 0 0 &
    notify-send "QuickIsland" "Spatial Workspace Enabled! Use Super+Arrows to pan." -i "view-grid-symbolic" -t 3000
else
    # Save state
    mkdir -p ~/.cache/quickisland
    echo "0" > ~/.cache/quickisland/spatial_wm_state
    
    notify-send "QuickIsland" "Spatial Workspace Disabled. Reverted to classic WM." -i "view-list-symbolic" -t 3000
fi
