#!/usr/bin/env bash
# ~/.config/fastfetch/make-logo.sh
# Center-crops the active wallpaper to match the fastfetch logo box aspect ratio.
# Logo box: 32 cols × 21 rows at ~7×15px per cell = 224×315px (portrait crop).

CELL_W="${KITTY_CELL_W:-7}"
CELL_H="${KITTY_CELL_H:-15}"
LOGO_COLS="${FASTFETCH_LOGO_COLS:-32}"
LOGO_ROWS="${FASTFETCH_LOGO_ROWS:-21}"

TARGET_W=$(( LOGO_COLS * CELL_W ))   # 224
TARGET_H=$(( LOGO_ROWS * CELL_H ))   # 315

CACHE_DIR="$HOME/.cache/fastfetch-logo"
mkdir -p "$CACHE_DIR"

# Get the active wallpaper path
WALL=""
WALL_SYMLINK="$HOME/.cache/wal/current-wallpaper"
if [[ -L "$WALL_SYMLINK" && -f "$WALL_SYMLINK" ]]; then
    WALL=$(readlink -f "$WALL_SYMLINK")
fi
if [[ -z "$WALL" ]] && command -v awww &>/dev/null; then
    WALL=$(awww query 2>/dev/null | grep -oP 'image: \K[^\s]+' | head -1)
fi
if [[ -z "$WALL" || ! -f "$WALL" ]]; then
    exit 0
fi

# Cache key: hash of wallpaper path + dimensions
HASH=$(printf '%s:%s:%s' "$WALL" "$TARGET_W" "$TARGET_H" | md5sum | cut -c1-8)
CACHED="$CACHE_DIR/logo-${HASH}.png"

if [[ ! -f "$CACHED" ]]; then
    # Get source dimensions
    DIMS=$(magick identify -format "%w %h" "$WALL" 2>/dev/null)
    SRC_W=${DIMS%% *}
    SRC_H=${DIMS##* }

    if [[ -z "$SRC_W" || "$SRC_W" == "0" ]]; then
        echo "$WALL"
        exit 0
    fi

    # Scale so image overfills the target box, then center-crop
    # Compare aspect ratios: if source is wider than target, scale by height; else by width
    # target_ratio = TARGET_W / TARGET_H, source_ratio = SRC_W / SRC_H
    # if source_ratio > target_ratio → source is wider → scale by height
    if (( SRC_W * TARGET_H > TARGET_W * SRC_H )); then
        # Scale by height, crop width
        SCALED_W=$(( SRC_W * TARGET_H / SRC_H ))
        SCALED_H=$TARGET_H
    else
        # Scale by width, crop height
        SCALED_W=$TARGET_W
        SCALED_H=$(( SRC_H * TARGET_W / SRC_W ))
    fi

    magick "$WALL" \
        -resize "${SCALED_W}x${SCALED_H}!" \
        -gravity Center \
        -extent "${TARGET_W}x${TARGET_H}" \
        "$CACHED"

    # Clean up stale cache (keep last 10)
    ls -t "$CACHE_DIR"/logo-*.png 2>/dev/null | tail -n +11 | xargs -r rm -f
fi

echo "$CACHED"
