#!/usr/bin/env bash
DIR=$1

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
    left)  DX=$WIDTH ;;
    right) DX=-$WIDTH ;;
    up)    DY=$HEIGHT ;;
    down)  DY=-$HEIGHT ;;
    *) exit 1 ;;
esac

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
