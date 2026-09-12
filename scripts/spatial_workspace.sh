#!/usr/bin/env bash
DIR=$1
CUR=$(hyprctl activeworkspace -j | jq '.id')

if [[ $CUR -lt 1 ]] || [[ $CUR -gt 9 ]]; then CUR=1; fi

# 0-indexed row and col
ROW=$(( (CUR - 1) / 3 ))
COL=$(( (CUR - 1) % 3 ))

case $DIR in
    left)  ((COL--)) ;;
    right) ((COL++)) ;;
    up)    ((ROW--)) ;;
    down)  ((ROW++)) ;;
esac

if [[ $COL -lt 0 ]]; then COL=0; fi
if [[ $COL -gt 2 ]]; then COL=2; fi
if [[ $ROW -lt 0 ]]; then ROW=0; fi
if [[ $ROW -gt 2 ]]; then ROW=2; fi

NEW_WS=$(( ROW * 3 + COL + 1 ))

hyprctl dispatch workspace $NEW_WS
