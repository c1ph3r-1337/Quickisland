#!/usr/bin/env bash
DIR=$1

COORD_FILE=~/.cache/quickisland/infinite_canvas_coords
if [[ -f $COORD_FILE ]]; then
    read VX VY < $COORD_FILE
else
    VX=0
    VY=0
fi

MON_JSON=$(hyprctl monitors -j | jq '.[] | select(.focused == true)')
MON_X=$(echo "$MON_JSON" | jq '.x')
MON_Y=$(echo "$MON_JSON" | jq '.y')
WIDTH=$(echo "$MON_JSON" | jq '.width')
HEIGHT=$(echo "$MON_JSON" | jq '.height')
SCALE=$(echo "$MON_JSON" | jq '.scale')
WIDTH=$(awk "BEGIN {print int($WIDTH / $SCALE)}")
HEIGHT=$(awk "BEGIN {print int($HEIGHT / $SCALE)}")

DX=0
DY=0

if [[ "$DIR" == "jump" ]]; then
    TARGET_VX=$2
    TARGET_VY=$3
    DIFF_X=$(( TARGET_VX - VX ))
    DIFF_Y=$(( TARGET_VY - VY ))
    DX=$(( -DIFF_X * WIDTH ))
    DY=$(( DIFF_Y * HEIGHT ))
    VX=$TARGET_VX
    VY=$TARGET_VY
else
    case $DIR in
        left)  DX=$WIDTH;  ((VX--)) ;;
        right) DX=-$WIDTH; ((VX++)) ;;
        up)    DY=$HEIGHT; ((VY++)) ;;
        down)  DY=-$HEIGHT;((VY--)) ;;
        *) exit 1 ;;
    esac
fi

# If we didn't move, exit
if [[ "$DX" == "0" ]] && [[ "$DY" == "0" ]]; then
    exit 0
fi

echo "$VX $VY" > $COORD_FILE

# Tell QuickIsland to update its dual-axis indicator
quickshell ipc -p ~/.config/quickshell/quickisland call virtual_workspace set_coords "$VX" "$VY" &

CUR_WS=$(hyprctl activeworkspace -j | jq '.id')

BATCH_CMD=$(hyprctl clients -j | jq -r --arg dx "$DX" --arg dy "$DY" --argjson ws "$CUR_WS" --argjson cx "$((MON_X + WIDTH/2))" --argjson cy "$((MON_Y + HEIGHT/2))" --argjson mon_w "$WIDTH" --argjson mon_h "$HEIGHT" '
  ( .[] | select(.workspace.id == $ws and .floating == true) |
    "dispatch movewindowpixel \($dx) \($dy),address:\(.address);"
  ),
  (
    [ .[] | select(.workspace.id == $ws and .mapped == true) |
      {
        address: .address,
        new_x: (if .floating == true then .at[0] + ($dx|tonumber) else .at[0] end),
        new_y: (if .floating == true then .at[1] + ($dy|tonumber) else .at[1] end),
        w: .size[0],
        h: .size[1]
      } |
      {
        address: .address,
        dist: ( ((.new_x + .w/2 - $cx) * (.new_x + .w/2 - $cx)) + ((.new_y + .h/2 - $cy) * (.new_y + .h/2 - $cy)) ),
        on_screen: ( .new_x < ($cx + $mon_w/2) and (.new_x + .w) > ($cx - $mon_w/2) and .new_y < ($cy + $mon_h/2) and (.new_y + .h) > ($cy - $mon_h/2) )
      }
    ] | map(select(.on_screen == true)) | sort_by(.dist) | .[0] |
    if . != null then "dispatch focuswindow address:\(.address);" else "" end
  )
')

BATCH_CMD=$(echo "$BATCH_CMD" | tr -d '\n')
if [[ -n "$BATCH_CMD" ]]; then
    hyprctl --batch "$BATCH_CMD" >/dev/null
fi
