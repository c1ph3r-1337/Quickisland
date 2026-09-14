#!/usr/bin/env bash
# overview_zoom.sh - Physically scale down all windows to show virtual workspace overview
# Usage: overview_zoom.sh enter | exit | jump VX VY

set -euo pipefail

STATE_DIR=~/.cache/quickisland
SAVE_FILE="$STATE_DIR/overview_saved_windows"
COORD_FILE="$STATE_DIR/infinite_canvas_coords"
mkdir -p "$STATE_DIR"

# Read current virtual coordinates
if [[ -f "$COORD_FILE" ]]; then
    read -r CUR_VX CUR_VY < "$COORD_FILE"
else
    CUR_VX=0; CUR_VY=0
fi

# Get monitor info
MON_JSON=$(hyprctl monitors -j | jq '.[] | select(.focused == true)')
MON_X=$(echo "$MON_JSON" | jq '.x')
MON_Y=$(echo "$MON_JSON" | jq '.y')
MON_W_RAW=$(echo "$MON_JSON" | jq '.width')
MON_H_RAW=$(echo "$MON_JSON" | jq '.height')
SCALE=$(echo "$MON_JSON" | jq '.scale')
MON_W=$(awk "BEGIN {print int($MON_W_RAW / $SCALE)}")
MON_H=$(awk "BEGIN {print int($MON_H_RAW / $SCALE)}")

CUR_WS=$(hyprctl activeworkspace -j | jq '.id')

ACTION="${1:-}"

enter_overview() {
    # Save all current window states (address, position, size, floating, fullscreen)
    # and compute which virtual workspace each window belongs to
    # Do not overwrite if we are already in the overview (prevents shrinking loop)
    if [[ ! -f "$SAVE_FILE" ]]; then
        hyprctl clients -j | jq -c --argjson ws "$CUR_WS" --argjson mon_x "$MON_X" --argjson mon_y "$MON_Y" \
            --argjson mon_w "$MON_W" --argjson mon_h "$MON_H" --argjson vx "$CUR_VX" --argjson vy "$CUR_VY" '
            [.[] | select(.workspace.id == $ws and .mapped == true) | {
                addr: .address,
                x: .at[0],
                y: .at[1],
                w: .size[0],
                h: .size[1],
                floating: .floating,
                fullscreen: .fullscreen
            }]
        ' > "$SAVE_FILE"
    fi

    # Now figure out the bounding box of all occupied virtual workspaces
    # Each window's virtual workspace is determined by its position relative to the monitor
    # A window at physical pos (px, py) is on virtual workspace:
    #   wx = CUR_VX + floor((px - MON_X) / MON_W)  (but rounded toward the workspace it mostly overlaps)
    #   wy = CUR_VY - floor((py - MON_Y) / MON_H)
    
    LAYOUT=$(cat "$SAVE_FILE" | jq --argjson mon_x "$MON_X" --argjson mon_y "$MON_Y" \
        --argjson mon_w "$MON_W" --argjson mon_h "$MON_H" --argjson vx "$CUR_VX" --argjson vy "$CUR_VY" '
        # Compute virtual workspace for each window (center-based)
        [.[] | . + {
            vwx: ($vx + ((((.x + .w/2) - $mon_x) / $mon_w) | floor)),
            vwy: ($vy - ((((.y + .h/2) - $mon_y) / $mon_h) | floor))
        }] |
        
        # Get unique virtual workspaces 
        (map({vwx, vwy}) | unique) as $vws |
        
        # Get bounding box of virtual workspace coordinates
        ($vws | map(.vwx) | min // $vx) as $min_vx |
        ($vws | map(.vwx) | max // $vx) as $max_vx |
        ($vws | map(.vwy) | min // $vy) as $min_vy |
        ($vws | map(.vwy) | max // $vy) as $max_vy |
        
        # Always include current position in the grid
        (if $min_vx > $vx then $vx else $min_vx end) as $min_vx |
        (if $max_vx < $vx then $vx else $max_vx end) as $max_vx |
        (if $min_vy > $vy then $vy else $min_vy end) as $min_vy |
        (if $max_vy < $vy then $vy else $max_vy end) as $max_vy |
        
        # Add 1 cell padding on each side
        (($min_vx - 1)) as $min_vx |
        (($max_vx + 1)) as $max_vx |
        (($min_vy - 1)) as $min_vy |
        (($max_vy + 1)) as $max_vy |
        
        # Grid dimensions
        (($max_vx - $min_vx + 1)) as $cols |
        (($max_vy - $min_vy + 1)) as $rows |
        
        # Scale factor: fit the grid into 85% of the screen with gaps
        # Each cell is mon_w x mon_h, we have cols x rows cells
        # Add gap between cells
        (20) as $gap |
        ((($mon_w * 0.85) - ($gap * ($cols - 1))) / ($cols * $mon_w)) as $sx |
        ((($mon_h * 0.85) - ($gap * ($rows - 1))) / ($rows * $mon_h)) as $sy |
        (if $sx < $sy then $sx else $sy end) as $scale |
        
        # Scaled cell size
        (($mon_w * $scale) | floor) as $cell_w |
        (($mon_h * $scale) | floor) as $cell_h |
        
        # Total grid size
        (($cell_w * $cols) + ($gap * ($cols - 1))) as $grid_w |
        (($cell_h * $rows) + ($gap * ($rows - 1))) as $grid_h |
        
        # Grid origin (centered on monitor)
        (($mon_x + ($mon_w - $grid_w) / 2) | floor) as $ox |
        (($mon_y + ($mon_h - $grid_h) / 2) | floor) as $oy |
        
        {
            scale: $scale,
            cell_w: $cell_w,
            cell_h: $cell_h,
            gap: $gap,
            ox: $ox,
            oy: $oy,
            min_vx: $min_vx,
            max_vx: $max_vx,
            min_vy: $min_vy,
            max_vy: $max_vy,
            cols: $cols,
            rows: $rows,
            vx: $vx,
            vy: $vy,
            windows: [.[] | {
                addr: .addr,
                # Cell position in grid (col, row)
                col: (.vwx - $min_vx),
                row: ($max_vy - .vwy),
                # Position within the cell (relative to that virtual workspace origin)
                rel_x: ((.x - $mon_x) - ((.vwx - $vx) * $mon_w)),
                rel_y: ((.y - $mon_y) - (($vy - .vwy) * $mon_h)),
                w: .w,
                h: .h,
                floating: .floating
            } | {
                addr: .addr,
                # Final position: grid origin + cell offset + scaled relative position
                new_x: (($ox + .col * ($cell_w + $gap) + .rel_x * $scale) | floor),
                new_y: (($oy + .row * ($cell_h + $gap) + .rel_y * $scale) | floor),
                new_w: ((.w * $scale) | floor | if . < 10 then 10 else . end),
                new_h: ((.h * $scale) | floor | if . < 10 then 10 else . end),
                floating: .floating
            }]
        }
    ')
    
    # Save layout info for QML overlay
    echo "$LAYOUT" > "$STATE_DIR/overview_layout.json"
    
    # Build batch command to move and resize all windows
    BATCH_CMD=$(echo "$LAYOUT" | jq -r '
        .windows[] |
        (if .floating == false then
            "dispatch togglefloating address:\(.addr);"
        else "" end) +
        "dispatch resizewindowpixel exact \(.new_w) \(.new_h),address:\(.addr);" +
        "dispatch movewindowpixel exact \(.new_x) \(.new_y),address:\(.addr);"
    ' | tr -d '\n')
    
    if [[ -n "$BATCH_CMD" ]]; then
        hyprctl --batch "$BATCH_CMD" >/dev/null
    fi
}

exit_overview() {
    [[ ! -f "$SAVE_FILE" ]] && return
    
    # Restore all windows to their saved positions
    BATCH_CMD=$(cat "$SAVE_FILE" | jq -r --argjson ws "$CUR_WS" '
        .[] |
        (if .fullscreen > 0 then
            "dispatch togglefloating address:\(.addr);" +
            "dispatch fullscreen 1,address:\(.addr);"
        else
            (if .floating == false then
                "dispatch togglefloating address:\(.addr);"
            else
                "dispatch resizewindowpixel exact \(.w) \(.h),address:\(.addr);" +
                "dispatch movewindowpixel exact \(.x) \(.y),address:\(.addr);"
            end)
        end)
    echo "$BATCH_CMD" >> /tmp/overview_exit.log
    ' | tr -d '\n')
    
    if [[ -n "$BATCH_CMD" ]]; then
        hyprctl --batch "$BATCH_CMD" >/dev/null
    fi
    
    rm -f "$SAVE_FILE" "$STATE_DIR/overview_layout.json"
}

jump_to() {
    TARGET_VX=$1
    TARGET_VY=$2
    
    # First restore windows
    exit_overview
    
    # Then jump to target if different from current
    if [[ "$TARGET_VX" != "$CUR_VX" ]] || [[ "$TARGET_VY" != "$CUR_VY" ]]; then
        ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump "$TARGET_VX" "$TARGET_VY"
    fi
}

case "$ACTION" in
    enter)
        enter_overview
        ;;
    exit)
        exit_overview
        ;;
    jump)
        jump_to "${2:-$CUR_VX}" "${3:-$CUR_VY}"
        ;;
    *)
        echo "Usage: $0 enter|exit|jump [VX VY]"
        exit 1
        ;;
esac
