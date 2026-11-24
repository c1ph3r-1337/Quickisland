#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickisland/game-mode"
snapshot="$state_dir/hyprland-before.json"
active_file="$state_dir/active"
lock_file="$state_dir/lock"
mkdir -p "$state_dir"
chmod 700 "$state_dir"
exec 9>"$lock_file"
flock 9

mode="${1:-toggle}"

capture_options() {
    python3 - "$snapshot" <<'PY'
import json
import os
import subprocess
import sys
import tempfile

path = sys.argv[1]
options = [
    "general:gaps_in",
    "general:gaps_out",
    "general:border_size",
    "decoration:rounding",
    "decoration:active_opacity",
    "decoration:inactive_opacity",
    "decoration:fullscreen_opacity",
    "decoration:blur:enabled",
    "decoration:shadow:enabled",
    "animations:enabled",
]
saved = {}
for name in options:
    result = subprocess.run(
        ["hyprctl", "-j", "getoption", name],
        check=True,
        capture_output=True,
        text=True,
    )
    data = json.loads(result.stdout)
    value = next((data[key] for key in ("css", "int", "float", "str", "bool") if key in data), None)
    if value is None:
        raise RuntimeError(f"Could not read Hyprland option {name}")
    if name in ("general:gaps_in", "general:gaps_out") and isinstance(value, str):
        parts = value.split()
        if len(parts) == 4:
            numbers = [float(part) if "." in part else int(part) for part in parts]
            value = {"top": numbers[0], "right": numbers[1], "bottom": numbers[2], "left": numbers[3]}
    saved[name] = value

directory = os.path.dirname(path)
fd, temporary = tempfile.mkstemp(prefix="hyprland-before-", dir=directory)
try:
    with os.fdopen(fd, "w") as output:
        json.dump(saved, output, indent=2)
        output.write("\n")
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PY
}

restore_options() {
    python3 - "$snapshot" <<'PY'
import json
import subprocess
import sys

with open(sys.argv[1]) as source:
    saved = json.load(source)

def lua_literal(value):
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, dict):
        entries = [f"[{json.dumps(key)}] = {lua_literal(item)}" for key, item in value.items()]
        return "{ " + ", ".join(entries) + " }"
    if isinstance(value, (int, float)):
        return repr(value)
    return json.dumps(value)

assignments = []
for name, value in saved.items():
    lua_name = name.replace(":", ".")
    if name in ("general:gaps_in", "general:gaps_out") and isinstance(value, str):
        parts = value.split()
        if len(parts) == 4:
            numbers = [float(part) if "." in part else int(part) for part in parts]
            value = {"top": numbers[0], "right": numbers[1], "bottom": numbers[2], "left": numbers[3]}
    assignments.append(f"[{json.dumps(lua_name)}] = {lua_literal(value)}")
code = "hl.config({ " + ", ".join(assignments) + " })"
result = subprocess.run(["hyprctl", "eval", code], check=True, capture_output=True, text=True)
if result.stdout.strip() != "ok":
    raise RuntimeError(result.stdout.strip() or result.stderr.strip() or "Hyprland rejected the restore settings")
PY
}

verify_game_mode() {
    python3 - <<'PY'
import json
import subprocess

expected = {
    "general:gaps_in": 0,
    "general:gaps_out": 0,
    "general:border_size": 0,
    "decoration:rounding": 0,
    "decoration:active_opacity": 1,
    "decoration:inactive_opacity": 1,
    "decoration:fullscreen_opacity": 1,
    "decoration:blur:enabled": False,
    "decoration:shadow:enabled": False,
    "animations:enabled": False,
}
for name, wanted in expected.items():
    result = subprocess.run(["hyprctl", "-j", "getoption", name], check=True, capture_output=True, text=True)
    data = json.loads(result.stdout)
    if name in ("general:gaps_in", "general:gaps_out"):
        actual = [float(part) for part in data["css"].split()]
        valid = len(actual) == 4 and all(value == wanted for value in actual)
    else:
        key = next(key for key in ("bool", "int", "float") if key in data)
        actual = data[key]
        valid = actual == wanted
    if not valid:
        raise RuntimeError(f"Game Mode option {name} did not apply (got {actual!r}, wanted {wanted!r})")
PY
}

enable_mode() {
    if [[ -f "$active_file" && ! -f "$snapshot" ]]; then
        printf 'Game Mode state is active but its restore snapshot is missing.\n' >&2
        return 1
    fi
    if [[ ! -f "$active_file" ]]; then
        capture_options
    fi

    if ! {
        hyprctl eval 'hl.config({
            ["general.gaps_in"] = 0,
            ["general.gaps_out"] = 0,
            ["general.border_size"] = 0,
            ["decoration.rounding"] = 0,
            ["decoration.active_opacity"] = 1,
            ["decoration.inactive_opacity"] = 1,
            ["decoration.fullscreen_opacity"] = 1,
            ["decoration.blur.enabled"] = false,
            ["decoration.shadow.enabled"] = false,
            ["animations.enabled"] = false
        })' >/dev/null
        verify_game_mode
    }; then
        if restore_options; then
            rm -f "$active_file" "$active_file.tmp" "$snapshot"
        fi
        return 1
    fi

    printf 'on\n' > "$active_file.tmp"
    mv "$active_file.tmp" "$active_file"
}

disable_mode() {
    if [[ -f "$snapshot" ]]; then
        restore_options
    fi
    rm -f "$active_file" "$active_file.tmp" "$snapshot"
}

case "$mode" in
    enable|on|1)
        enable_mode
        printf 'on\n'
        ;;
    disable|off|0)
        disable_mode
        printf 'off\n'
        ;;
    toggle)
        if [[ -f "$active_file" ]]; then
            disable_mode
            printf 'off\n'
        else
            enable_mode
            printf 'on\n'
        fi
        ;;
    status)
        if [[ -f "$active_file" ]]; then
            printf 'on\n'
            exit 0
        fi
        printf 'off\n'
        exit 1
        ;;
    *)
        printf 'Usage: %s [enable|disable|toggle|status]\n' "$0" >&2
        exit 2
        ;;
esac
