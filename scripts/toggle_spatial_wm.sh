#!/usr/bin/env bash
STATE=$1
SPATIAL_CONF="$HOME/.config/quickshell/quickisland/hypr/spatial_wm.conf"
mkdir -p "$(dirname "$SPATIAL_CONF")"
COORD_FILE=~/.cache/quickisland/infinite_canvas_coords

if [[ "$STATE" == "on" ]]; then
    cat << 'INNER_EOF' > "$SPATIAL_CONF"
bind = CTRL SUPER, Left, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh left
bind = CTRL SUPER, Right, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh right
bind = CTRL SUPER, Up, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh up
bind = CTRL SUPER, Down, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh down
# Fallback keybind
bind = CTRL SUPER, Space, exec, quickshell ipc -p ~/.config/quickshell/quickisland call overview toggle
bind = , swipe:4:d, exec, quickshell ipc -p ~/.config/quickshell/quickisland call overview toggle
INNER_EOF

    hyprctl keyword source "$SPATIAL_CONF"
    notify-send "QuickIsland" "Infinite Canvas Enabled! Use Ctrl+Super+Arrows to pan, Ctrl+Super+Space for overview." -i "view-grid-symbolic" -t 3000
    
    # Save state
    mkdir -p ~/.cache/quickisland
    echo "1" > ~/.cache/quickisland/spatial_wm_state
    
    # Reset coordinates
    echo "0 0" > "$COORD_FILE"
    quickshell ipc -p ~/.config/quickshell/quickisland call virtual_workspace set_text 1 &
else
    # Clear the config so on reboot it does nothing
    echo "" > "$SPATIAL_CONF"

    hyprctl keyword unbind "CTRL SUPER, Left"
    hyprctl keyword unbind "CTRL SUPER, Right"
    hyprctl keyword unbind "CTRL SUPER, Up"
    hyprctl keyword unbind "CTRL SUPER, Down"
    hyprctl keyword unbind "CTRL SUPER, Space"
    hyprctl keyword unbind ", swipe:4:d"
    
    notify-send "QuickIsland" "Infinite Canvas Disabled. Reverted to classic WM." -i "view-list-symbolic" -t 3000

    # Save state
    mkdir -p ~/.cache/quickisland
    echo "0" > ~/.cache/quickisland/spatial_wm_state
    
    # Re-sync standard workspace ID
    WS_ID=$(hyprctl activeworkspace -j | jq '.id')
    quickshell ipc -p ~/.config/quickshell/quickisland call virtual_workspace set_text "$WS_ID" &
fi
