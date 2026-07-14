#!/bin/bash
# pick_folder.sh
# Opens a rofi directory picker and prints the chosen path to stdout.
# Usage: pick_folder.sh [start_dir]

START_DIR="${1:-$HOME/Pictures}"

# Build list of candidate directories (home + Pictures subtree + common locations)
{
    echo "$HOME"
    echo "$HOME/Pictures"
    echo "$HOME/Downloads"
    echo "$HOME/Videos"
    find "$HOME/Pictures" -maxdepth 4 -type d 2>/dev/null | sort
    find "$HOME/Downloads" -maxdepth 2 -type d 2>/dev/null | sort
    find "$HOME/Videos" -maxdepth 3 -type d 2>/dev/null | sort
} | sort -u | \
  rofi -dmenu \
       -p "Wallpaper Folder" \
       -i \
       -no-custom \
       -theme-str 'window { width: 700px; } listview { lines: 12; }' \
       2>/dev/null
