#!/usr/bin/env bash
set -euo pipefail

STATE_DIR=~/.cache/quickisland
SAVE_FILE="$STATE_DIR/overview_saved_windows"
COORD_FILE="$STATE_DIR/infinite_canvas_coords"
mkdir -p "$STATE_DIR"

if [[ -f "$COORD_FILE" ]]; then
    read -r CUR_VX CUR_VY < "$COORD_FILE"
else
    CUR_VX=0; CUR_VY=0
fi

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
    if [[ ! -f "$SAVE_FILE" ]]; then
        hyprctl clients -j | jq -c --argjson ws "$CUR_WS" '
            [.[] | select(.workspace.id == $ws and .mapped == true)]
        ' > "$SAVE_FILE"
    fi

    LAYOUT=$(cat "$SAVE_FILE" | jq --argjson mon_x "$MON_X" --argjson mon_y "$MON_Y" \
        --argjson mon_w "$MON_W" --argjson mon_h "$MON_H" --argjson vx "$CUR_VX" --argjson vy "$CUR_VY" '
        [.[] | . + {
            vwx: ($vx + ((((.x + .w/2) - $mon_x) / $mon_w) | floor)),
            vwy: ($vy - ((((.y + .h/2) - $mon_y) / $mon_h) | floor))
        }] |
        (map({vwx, vwy}) | unique) as $vws |
        ($vws | map(.vwx) | min // $vx) as $min_vx |
        ($vws | map(.vwx) | max // $vx) as $max_vx |
        ($vws | map(.vwy) | min // $vy) as $min_vy |
        ($vws | map(.vwy) | max // $vy) as $max_vy |
        
        (($max_vx - $min_vx) + 1) as $cols |
        (($max_vy - $min_vy) + 1) as $rows |
        
        {
            cols: (if $cols < 3 then 3 else $cols end),
            rows: (if $rows < 3 then 3 else $rows end),
            min_vx: $min_vx,
            max_vx: $max_vx,
            min_vy: $min_vy,
            max_vy: $max_vy,
            vx: $vx,
            vy: $vy,
            ox: $mon_x,
            oy: $mon_y,
            cell_w: ($mon_w * 0.3),
            cell_h: ($mon_h * 0.3),
            gap: 20
        }
    ')
    echo "$LAYOUT" > "$STATE_DIR/overview_layout.json"
}

exit_overview() {
    rm -f "$SAVE_FILE" "$STATE_DIR/overview_layout.json"
}

jump_to() {
    TARGET_VX=$1
    TARGET_VY=$2
    exit_overview
    if [[ "$TARGET_VX" != "$CUR_VX" ]] || [[ "$TARGET_VY" != "$CUR_VY" ]]; then
        ~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump "$TARGET_VX" "$TARGET_VY"
    fi
}

case "$ACTION" in
    enter) enter_overview ;;
    exit)  exit_overview ;;
    jump)  jump_to "${2:-$CUR_VX}" "${3:-$CUR_VY}" ;;
    *) exit 1 ;;
esac
