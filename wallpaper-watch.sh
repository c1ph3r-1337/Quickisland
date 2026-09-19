#!/usr/bin/env bash
# ~/.config/fastfetch/wallpaper-watch.sh
# Watches awww for wallpaper changes and keeps the fastfetch logo in sync.
# Runs as a persistent background daemon (started via systemd user service).

SYMLINK="$HOME/.cache/wal/current-wallpaper"
MAKE_LOGO="$HOME/.config/fastfetch/make-logo.sh"
POLL_INTERVAL=2   # seconds between awww query polls

mkdir -p "$HOME/.cache/wal" "$HOME/.cache/fastfetch-logo"

last_wall=""

while true; do
    # Get current wallpaper from awww
    current=$(awww query 2>/dev/null | grep -oP 'image: \K[^\s]+' | head -1)

    if [[ -n "$current" && "$current" != "$last_wall" && -f "$current" ]]; then
        last_wall="$current"

        # Update symlink
        ln -sf "$current" "$SYMLINK"

        # Pre-generate cropped logo (cached by hash — instant on next kitty open)
        "$MAKE_LOGO" > /dev/null 2>&1
    fi

    sleep "$POLL_INTERVAL"
done
