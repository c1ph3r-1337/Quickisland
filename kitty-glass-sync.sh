#!/usr/bin/env bash
set -u

MODE="${1:-off}"
PLUGIN="$HOME/.config/hypr/plugins/hyprglass-0.57.so"
KITTYCONF="$HOME/.config/kitty/kitty.conf"

if [[ "$MODE" == "liquid" ]]; then
    if ! hyprctl plugin list 2>/dev/null | grep -q "hyprglass"; then
        hyprctl plugin load "$PLUGIN" >/dev/null 2>&1 || exit 1
    fi
    hyprctl keyword plugin:hyprglass:enabled 1 >/dev/null
    hyprctl keyword plugin:hyprglass:layers:enabled 1 >/dev/null
    hyprctl keyword decoration:blur:enabled true >/dev/null

    if [[ -f "$KITTYCONF" ]]; then
        sed -i 's/^background_opacity .*/background_opacity 0.07/' "$KITTYCONF"
        sed -i 's/^window_padding_width .*/window_padding_width 20/' "$KITTYCONF"
    fi

    while IFS=$'\t' read -r address class; do
        [[ -n "$address" ]] || continue
        hyprctl dispatch -- tagwindow "-hyprglass_disabled address:$address" >/dev/null 2>&1 || true
        if [[ "$class" == "kitty" ]]; then
            hyprctl dispatch -- tagwindow "+hyprglass_enabled address:$address" >/dev/null 2>&1 || true
        elif [[ "$class" == "qemu-system-x86_64" ]]; then
            hyprctl dispatch -- tagwindow "+hyprglass_disabled address:$address" >/dev/null 2>&1 || true
        fi
    done < <(hyprctl clients -j 2>/dev/null | jq -r '.[] | [.address, .class] | @tsv')
else
    hyprctl keyword plugin:hyprglass:enabled 0 >/dev/null 2>&1 || true
    hyprctl keyword plugin:hyprglass:layers:enabled 0 >/dev/null 2>&1 || true
    hyprctl keyword decoration:blur:enabled false >/dev/null 2>&1 || true

    if [[ -f "$KITTYCONF" ]]; then
        sed -i 's/^background_opacity .*/background_opacity 1.0/' "$KITTYCONF"
        sed -i 's/^window_padding_width .*/window_padding_width 25/' "$KITTYCONF"
    fi

    while IFS=$'\t' read -r address _class; do
        [[ -n "$address" ]] || continue
        hyprctl dispatch -- tagwindow "-hyprglass_enabled address:$address" >/dev/null 2>&1 || true
        hyprctl dispatch -- tagwindow "+hyprglass_disabled address:$address" >/dev/null 2>&1 || true
    done < <(hyprctl clients -j 2>/dev/null | jq -r '.[] | [.address, .class] | @tsv')
fi

if [[ -f "$KITTYCONF" ]]; then
    touch "$KITTYCONF"
    killall -SIGUSR1 kitty >/dev/null 2>&1 || true
fi
