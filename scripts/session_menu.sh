#!/usr/bin/env bash
set -euo pipefail

quickisland="/home/c1ph3r/.config/quickshell/quickisland"
game_mode_state="${XDG_STATE_HOME:-$HOME/.local/state}/quickisland/game-mode/active"

if [[ -f "$game_mode_state" ]]; then
    exec /usr/bin/quickshell ipc -p "$quickisland" call state toggle 6
fi

exec noctalia-shellctl ipc sessionMenu toggle
