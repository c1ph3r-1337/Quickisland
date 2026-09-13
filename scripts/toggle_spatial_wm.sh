#!/usr/bin/env bash
STATE=$1
SPATIAL_CONF="$HOME/.config/quickshell/quickisland/hypr/spatial_wm.conf"
mkdir -p "$(dirname "$SPATIAL_CONF")"
COORD_FILE=~/.cache/quickisland/infinite_canvas_coords

if [[ "$STATE" == "on" ]]; then
    cat << 'INNER_EOF' > "$SPATIAL_CONF"
# Infinite Canvas Panning
bind = SUPER, Left, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh left
bind = SUPER, Right, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh right
bind = SUPER, Up, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh up
bind = SUPER, Down, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh down

# Horizontal Axis Workspace Jumping (1 to 9)
bind = SUPER, 1, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump 0 0
bind = SUPER, 2, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump 1 0
bind = SUPER, 3, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump 2 0
bind = SUPER, 4, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump 3 0
bind = SUPER, 5, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump 4 0
bind = SUPER, 6, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump 5 0
bind = SUPER, 7, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump 6 0
bind = SUPER, 8, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump 7 0
bind = SUPER, 9, exec, ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump 8 0

# Overview Toggles
bind = CTRL SUPER, Space, exec, quickshell ipc -p ~/.config/quickshell/quickisland call overview toggle
bind = , swipe:4:d, exec, quickshell ipc -p ~/.config/quickshell/quickisland call overview toggle
INNER_EOF

    hyprctl keyword source "$SPATIAL_CONF"
    notify-send "QuickIsland" "Infinite Canvas Enabled! Use Super+Arrows to pan, Super+1..9 for X axis." -i "view-grid-symbolic" -t 3000
    
    # Save state
    mkdir -p ~/.cache/quickisland
    echo "1" > ~/.cache/quickisland/spatial_wm_state
    
    # Reset coordinates
    echo "0 0" > "$COORD_FILE"
    quickshell ipc -p ~/.config/quickshell/quickisland call virtual_workspace set_coords 0 0 &
else
    # Clear the config and reload Hyprland to cleanly restore the user's default bindings
    echo "" > "$SPATIAL_CONF"
    hyprctl reload
    
    notify-send "QuickIsland" "Infinite Canvas Disabled. Reverted to classic WM." -i "view-list-symbolic" -t 3000

    # Save state
    mkdir -p ~/.cache/quickisland
    echo "0" > ~/.cache/quickisland/spatial_wm_state
fi
