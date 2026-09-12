#!/usr/bin/env bash
MODE="$1"

if [ "$MODE" = "liquid" ]; then
    sed -i 's/^background_opacity .*/background_opacity 0.07/' ~/.config/kitty/kitty.conf
    sed -i 's/^window_padding_width .*/window_padding_width 20/' ~/.config/kitty/kitty.conf
    
    # Fix the invalid Hyprland window rule syntax
    if grep -q "kitty" ~/.config/hypr/userprefs.conf; then
        sed -i 's/.*hyprglass_.*kitty.*/windowrulev2 = tag +hyprglass_enabled, class:^(kitty)$/' ~/.config/hypr/userprefs.conf
    else
        echo "windowrulev2 = tag +hyprglass_enabled, class:^(kitty)$" >> ~/.config/hypr/userprefs.conf
    fi
    
    for addr in $(hyprctl clients -j | jq -r '.[] | select(.class == "kitty") | .address'); do
        hyprctl -- dispatch tagwindow "-hyprglass_disabled" address:$addr >/dev/null 2>&1
        hyprctl -- dispatch tagwindow "+hyprglass_enabled" address:$addr >/dev/null 2>&1
    done
else
    sed -i 's/^background_opacity .*/background_opacity 0.97/' ~/.config/kitty/kitty.conf
    sed -i 's/^window_padding_width .*/window_padding_width 25/' ~/.config/kitty/kitty.conf
    
    # Fix the invalid Hyprland window rule syntax
    if grep -q "kitty" ~/.config/hypr/userprefs.conf; then
        sed -i 's/.*hyprglass_.*kitty.*/windowrulev2 = tag +hyprglass_disabled, class:^(kitty)$/' ~/.config/hypr/userprefs.conf
    else
        echo "windowrulev2 = tag +hyprglass_disabled, class:^(kitty)$" >> ~/.config/hypr/userprefs.conf
    fi
    
    for addr in $(hyprctl clients -j | jq -r '.[] | select(.class == "kitty") | .address'); do
        hyprctl -- dispatch tagwindow "-hyprglass_enabled" address:$addr >/dev/null 2>&1
        hyprctl -- dispatch tagwindow "+hyprglass_disabled" address:$addr >/dev/null 2>&1
    done
fi

hyprctl reload >/dev/null 2>&1 || true
touch ~/.config/kitty/kitty.conf
killall -SIGUSR1 kitty >/dev/null 2>&1 || true
