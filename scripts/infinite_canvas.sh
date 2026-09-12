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
    DY=$(( -DIFF_Y * HEIGHT ))
    VX=$TARGET_VX
    VY=$TARGET_VY
else
    case $DIR in
        left)  DX=$WIDTH;  ((VX--)) ;;
        right) DX=-$WIDTH; ((VX++)) ;;
        up)    DY=$HEIGHT; ((VY--)) ;;
        down)  DY=-$HEIGHT;((VY++)) ;;
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

BATCH_CMD=$(hyprctl clients -j | jq -r --arg dx "$DX" --arg dy "$DY" --argjson ws "$CUR_WS" '
  .[] | select(.workspace.id == $ws) |
  (if .floating == false then "dispatch togglefloating address:\(.address);" else "" end) +
  "dispatch movewindowpixel \($dx) \($dy),address:\(.address);"
')

BATCH_CMD=$(echo "$BATCH_CMD" | tr -d '\n')
if [[ -n "$BATCH_CMD" ]]; then
    hyprctl --batch "$BATCH_CMD" >/dev/null
fi
