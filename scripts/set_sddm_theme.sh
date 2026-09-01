#!/bin/bash
THEME=$1
if [ -n "$THEME" ]; then
    sudo /usr/local/bin/set_sddm_theme "$THEME"
fi
