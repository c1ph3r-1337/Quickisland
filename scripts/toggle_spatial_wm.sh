#!/usr/bin/env bash
STATE=$1
SPATIAL_CONF="$HOME/.config/quickshell/quickisland/hypr/spatial_wm.conf"
mkdir -p "$(dirname "$SPATIAL_CONF")"

if [[ "$STATE" == "on" ]]; then
    cat << 'INNER_EOF' > "$SPATIAL_CONF"
plugin {
    hyprexpo {
        columns = 3
        gap_size = 5
        bg_col = rgb(111111)
        workspace_method = center current
        enable_gesture = true
        gesture_fingers = 4
        gesture_distance = 300
        gesture_positive = false
    }
}
bind = CTRL SUPER, Left, exec, ~/.config/quickshell/quickisland/scripts/spatial_workspace.sh left
bind = CTRL SUPER, Right, exec, ~/.config/quickshell/quickisland/scripts/spatial_workspace.sh right
bind = CTRL SUPER, Up, exec, ~/.config/quickshell/quickisland/scripts/spatial_workspace.sh up
bind = CTRL SUPER, Down, exec, ~/.config/quickshell/quickisland/scripts/spatial_workspace.sh down
# Fallback keybind
bind = CTRL SUPER, Space, hyprexpo:expo, toggle
INNER_EOF

    # Attempt to load hyprexpo (might fail if not installed, but 2D binds will still work)
    if command -v hyprpm &>/dev/null; then
        hyprpm enable hyprexpo </dev/null 2>/dev/null || true
    fi

    hyprctl keyword source "$SPATIAL_CONF"
    notify-send "QuickIsland" "Spatial WM Mode (2D Grid) Enabled! Use Ctrl+Super+Arrows to navigate." -i "view-grid-symbolic" -t 3000
    
    # Save state
    mkdir -p ~/.cache/quickisland
    echo "1" > ~/.cache/quickisland/spatial_wm_state

else
    # Clear the config so on reboot it does nothing
    echo "" > "$SPATIAL_CONF"

    hyprctl keyword unbind "CTRL SUPER, Left"
    hyprctl keyword unbind "CTRL SUPER, Right"
    hyprctl keyword unbind "CTRL SUPER, Up"
    hyprctl keyword unbind "CTRL SUPER, Down"
    hyprctl keyword unbind "CTRL SUPER, Space"
    
    if command -v hyprpm &>/dev/null; then
        hyprpm disable hyprexpo </dev/null 2>/dev/null || true
    fi
    
    notify-send "QuickIsland" "Spatial WM Mode Disabled. Reverted to classic linear WM." -i "view-list-symbolic" -t 3000

    # Save state
    mkdir -p ~/.cache/quickisland
    echo "0" > ~/.cache/quickisland/spatial_wm_state
fi
