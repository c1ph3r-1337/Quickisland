#!/usr/bin/env bash
MODE="$1"

USERPREFS="$HOME/.config/hypr/userprefs.conf"
KITTYCONF="$HOME/.config/kitty/kitty.conf"

if [ "$MODE" = "liquid" ]; then
    # Ensure hyprglass plugin is loaded
    if ! hyprctl plugin list 2>/dev/null | grep -q "hyprglass"; then
        hyprctl plugin load "$HOME/hyprglass/hyprglass.so" >/dev/null 2>&1
    fi

    # Enable hyprglass in Hyprland
    hyprctl keyword plugin:hyprglass:enabled 1 >/dev/null 2>&1
    hyprctl keyword plugin:hyprglass:layers:enabled 1 >/dev/null 2>&1
    hyprctl keyword decoration:blur:enabled true >/dev/null 2>&1

    # Configure kitty for liquid glass
    if [ -f "$KITTYCONF" ]; then
        sed -i 's/^background_opacity .*/background_opacity 0.07/' "$KITTYCONF"
        sed -i 's/^window_padding_width .*/window_padding_width 20/' "$KITTYCONF"
    fi
    
    # Update userprefs.conf
    if [ -f "$USERPREFS" ]; then
        sed -i '/windowrulev2 = noblur, class:\^(kitty)\$/d' "$USERPREFS"
        sed -i '/windowrulev2 = opaque, class:\^(kitty)\$/d' "$USERPREFS"
        sed -i '/decoration:blur:enabled = false/d' "$USERPREFS"
        sed -i 's/plugin:hyprglass:enabled = 0/plugin:hyprglass:enabled = 1/g' "$USERPREFS"
        sed -i 's/plugin:hyprglass:layers:enabled = 0/plugin:hyprglass:layers:enabled = 1/g' "$USERPREFS"
        if grep -q "hyprglass_.*kitty" "$USERPREFS"; then
            sed -i 's/.*hyprglass_.*kitty.*/windowrulev2 = tag +hyprglass_enabled, class:^(kitty)$/' "$USERPREFS"
        else
            echo "windowrulev2 = tag +hyprglass_enabled, class:^(kitty)$" >> "$USERPREFS"
        fi
    fi
    
    # Tag all running kitty windows for hyprglass
    for addr in $(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class == "kitty") | .address'); do
        hyprctl dispatch -- tagwindow "-hyprglass_disabled address:$addr" >/dev/null 2>&1
        hyprctl dispatch -- tagwindow "+hyprglass_enabled address:$addr" >/dev/null 2>&1
        hyprctl dispatch setprop "address:$addr" opaque 0 >/dev/null 2>&1
    done

    # Refresh kitty and clear hyprglass cache
    [ -f "$KITTYCONF" ] && touch "$KITTYCONF"
    killall -SIGUSR1 kitty >/dev/null 2>&1 || true
    hyprctl dispatch hyprglass:clear_cache "" >/dev/null 2>&1
else
    # Disable hyprglass in Hyprland
    hyprctl keyword plugin:hyprglass:enabled 0 >/dev/null 2>&1
    hyprctl keyword plugin:hyprglass:layers:enabled 0 >/dev/null 2>&1

    # Restore default opacity and padding in kitty
    if [ -f "$KITTYCONF" ]; then
        sed -i 's/^background_opacity .*/background_opacity 0.97/' "$KITTYCONF"
        sed -i 's/^window_padding_width .*/window_padding_width 25/' "$KITTYCONF"
    fi
    
    # Clean up rules and set hyprglass_disabled in userprefs
    if [ -f "$USERPREFS" ]; then
        sed -i '/windowrulev2 = noblur, class:\^(kitty)\$/d' "$USERPREFS"
        sed -i '/windowrulev2 = opaque, class:\^(kitty)\$/d' "$USERPREFS"
        sed -i 's/plugin:hyprglass:enabled = 1/plugin:hyprglass:enabled = 0/g' "$USERPREFS"
        sed -i 's/plugin:hyprglass:layers:enabled = 1/plugin:hyprglass:layers:enabled = 0/g' "$USERPREFS"
        if grep -q "hyprglass_.*kitty" "$USERPREFS"; then
            sed -i 's/.*hyprglass_.*kitty.*/windowrulev2 = tag +hyprglass_disabled, class:^(kitty)$/' "$USERPREFS"
        else
            echo "windowrulev2 = tag +hyprglass_disabled, class:^(kitty)$" >> "$USERPREFS"
        fi
    fi
    
    # Remove hyprglass tag from running kitty windows
    for addr in $(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class == "kitty") | .address'); do
        hyprctl dispatch -- tagwindow "-hyprglass_enabled address:$addr" >/dev/null 2>&1
        hyprctl dispatch -- tagwindow "+hyprglass_disabled address:$addr" >/dev/null 2>&1
    done

    # Refresh kitty and clear hyprglass cache
    [ -f "$KITTYCONF" ] && touch "$KITTYCONF"
    killall -SIGUSR1 kitty >/dev/null 2>&1 || true
    hyprctl dispatch hyprglass:clear_cache "" >/dev/null 2>&1
fi
