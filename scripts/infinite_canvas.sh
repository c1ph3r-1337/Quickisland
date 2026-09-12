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

# Camera moves RIGHT -> windows move LEFT (DX = -WIDTH)
# Camera moves LEFT -> windows move RIGHT (DX = WIDTH)
# Camera moves DOWN -> windows move UP (DY = -HEIGHT)
# Camera moves UP -> windows move DOWN (DY = HEIGHT)
case $DIR in
    left)  DX=$WIDTH;  ((VX--)) ;;
    right) DX=-$WIDTH; ((VX++)) ;;
    up)    DY=$HEIGHT; ((VY--)) ;;
    down)  DY=-$HEIGHT;((VY++)) ;;
    *) exit 1 ;;
esac

# Clamp virtual coords to 3x3 grid matching traditional workspace IDs
if [[ $VX -lt 0 ]]; then VX=0; fi
if [[ $VX -gt 2 ]]; then VX=2; fi
if [[ $VY -lt 0 ]]; then VY=0; fi
if [[ $VY -gt 2 ]]; then VY=2; fi

OLD_VX=$(awk '{print $1}' $COORD_FILE 2>/dev/null || echo "0")
OLD_VY=$(awk '{print $2}' $COORD_FILE 2>/dev/null || echo "0")

if [[ "$VX" == "$OLD_VX" ]] && [[ "$VY" == "$OLD_VY" ]]; then
    # We hit the boundary, don't move windows
    exit 0 
fi

echo "$VX $VY" > $COORD_FILE

# Calculate Virtual Workspace ID (1-9)
VID=$(( VY * 3 + VX + 1 ))

# Tell QuickIsland to update its indicator
quickshell ipc -p ~/.config/quickshell/quickisland call virtual_workspace set "$VID" &

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
