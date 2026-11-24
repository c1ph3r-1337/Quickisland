#!/usr/bin/env python3
"""Write QuickIsland's Hyprland settings and keybindings from settings.json."""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import tempfile
from pathlib import Path


KEY_NAMES = {
    " ": "SPACE",
    "SPACE": "SPACE",
    "`": "grave", "GRAVE": "grave",
    ".": "period", "PERIOD": "period",
    "/": "slash", "SLASH": "slash",
    ",": "comma", "COMMA": "comma",
    "-": "minus", "MINUS": "minus",
    "=": "equal", "EQUAL": "equal",
    "[": "bracketleft", "]": "bracketright",
    "\\": "backslash",
    "ESC": "Escape", "DEL": "Delete", "INS": "Insert",
    "PGUP": "Page_Up", "PGDN": "Page_Down",
    "RETURN": "Return", "ENTER": "KP_Enter",
    "LEFT": "Left", "RIGHT": "Right", "UP": "Up", "DOWN": "Down",
    "TAB": "Tab", "BACKSPACE": "Backspace", "HOME": "Home", "END": "End",
}

ACTIONS = (
    ("settingsKeybind", "Settings", "quickisland_settings toggle"),
    ("launcherKeybind", "App launcher", "state toggleLauncher"),
    ("gameModeKeybind", "Game Mode", "game_mode toggle"),
    ("sessionMenuKeybind", "Session menu", "__session_menu__"),
    ("keybinds.airdrop", "AirDrop", "airdrop toggle"),
    ("keybinds.controlCenter", "Control Center", "state toggle 5"),
    ("keybinds.clipboard", "Clipboard history", "clipboard toggle"),
    ("keybinds.emoji", "Emoji picker", "emoji toggle"),
    ("keybinds.keyboardShortcuts", "Keyboard shortcuts", "state toggle 16"),
    ("keybinds.lockScreen", "Lock screen", "lockscreen lock"),
    ("keybinds.fullscreen", "Fullscreen mode", "fullscreen toggle"),
    ("keybinds.screenTools", "Screen tools", "plugin:screen-toolkit annotate"),
    ("keybinds.monitorSettings", "Monitor settings", "state toggle 17"),
    ("keybinds.wallpaper", "Wallpaper chooser", "state toggle 10"),
    ("keybinds.themePicker", "Theme picker", "state toggle 20"),
    ("keybinds.virtualOverview", "Virtual workspace overview", "overview toggle"),
    ("keybinds.overviewAlternate", "Alternate virtual overview", "overview toggle"),
    ("keybinds.workspaceOverview", "Workspace overview", "wsoverview toggle"),
    ("keybinds.windowFocusLeft", "Focus window left", "__focus_left__"),
    ("keybinds.windowFocusRight", "Focus window right", "__focus_right__"),
    ("keybinds.moveWindowLeft", "Move window left", "__move_left__"),
    ("keybinds.moveWindowRight", "Move window right", "__move_right__"),
)

LUA_KEY_NAMES = {
    "SPACE": "space", "GRAVE": "grave", "PERIOD": "period", "SLASH": "slash",
    "COMMA": "comma", "MINUS": "minus", "EQUAL": "equal",
    "BRACKETLEFT": "bracketleft", "BRACKETRIGHT": "bracketright", "BACKSLASH": "backslash",
    "ESCAPE": "Escape", "DELETE": "Delete", "INSERT": "Insert", "PAGEUP": "Page_Up",
    "PAGEDOWN": "Page_Down", "RETURN": "Return", "KP_ENTER": "KP_Enter",
    "LEFT": "Left", "RIGHT": "Right", "UP": "Up", "DOWN": "Down",
    "TAB": "Tab", "BACKSPACE": "BackSpace", "HOME": "Home", "END": "End",
}


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as output:
            output.write(content)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def number(source: dict, key: str, *, minimum: float, maximum: float) -> float:
    value = float(source[key])
    if not minimum <= value <= maximum:
        raise ValueError(f"{key} must be between {minimum:g} and {maximum:g}")
    return value


def hypr_chord(value: str) -> tuple[str, str]:
    parts = [part.strip() for part in str(value).split("+") if part.strip()]
    if len(parts) < 2:
        raise ValueError(f"Shortcut needs a modifier: {value!r}")

    modifiers = []
    for item in parts[:-1]:
        modifier = item.lower()
        mapped = {
            "super": "$mainMod", "meta": "$mainMod",
            "ctrl": "CTRL", "control": "CTRL", "alt": "ALT", "shift": "SHIFT",
        }.get(modifier)
        if mapped is None:
            raise ValueError(f"Unsupported shortcut modifier {item!r}")
        if mapped not in modifiers:
            modifiers.append(mapped)
    if not modifiers:
        raise ValueError(f"Shortcut needs a modifier: {value!r}")

    key = parts[-1]
    mapped_key = KEY_NAMES.get(key.upper(), key.upper())
    if not re.fullmatch(r"[A-Za-z0-9_]+", mapped_key):
        raise ValueError(f"Unsupported shortcut key {key!r}")
    if re.fullmatch(r"F(?:1[0-2]|[1-9])", mapped_key):
        pass
    elif len(mapped_key) != 1 and mapped_key.upper() not in {item.upper() for item in KEY_NAMES.values()}:
        raise ValueError(f"Unsupported shortcut key {key!r}")
    return " ".join(modifiers), mapped_key


def lua_chord(value: str) -> str:
    modifiers, key = hypr_chord(value)
    lua_key = LUA_KEY_NAMES.get(key, key)
    return " + ".join(["SUPER" if item == "$mainMod" else item for item in modifiers.split()] + [lua_key])


def update_game_mode_snapshot(window_settings: dict) -> None:
    state_dir = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "quickisland/game-mode"
    active = state_dir / "active"
    snapshot = state_dir / "hyprland-before.json"
    if not active.exists() or not snapshot.exists():
        return
    current = json.loads(snapshot.read_text(encoding="utf-8"))
    current.update({
        "general:gaps_in": int(window_settings["gapsIn"]),
        "general:gaps_out": int(window_settings["gapsOut"]),
        "general:border_size": int(window_settings["borderSize"]),
        "decoration:rounding": int(window_settings["rounding"]),
        "decoration:active_opacity": float(window_settings["activeOpacity"]),
        "decoration:inactive_opacity": float(window_settings["inactiveOpacity"]),
        "decoration:fullscreen_opacity": float(window_settings["fullscreenOpacity"]),
        "decoration:blur:enabled": bool(window_settings["blurEnabled"]),
        "decoration:shadow:enabled": bool(window_settings["shadowEnabled"]),
        "animations:enabled": bool(window_settings["animationsEnabled"]),
    })
    atomic_write(snapshot, json.dumps(current, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--settings", required=True, type=Path)
    parser.add_argument("--shell-dir", required=True, type=Path)
    args = parser.parse_args()

    document = json.loads(args.settings.read_text(encoding="utf-8"))
    provided_quickisland = document.get("quickisland", {})
    default_keybinds = {
        "airdrop": "Super+D", "controlCenter": "Super+N", "clipboard": "Super+V",
        "emoji": "Super+period", "keyboardShortcuts": "Super+slash", "lockScreen": "Super+L",
        "fullscreen": "Super+F", "screenTools": "Super+P", "monitorSettings": "Super+M",
        "wallpaper": "Super+Shift+W", "themePicker": "Super+Shift+T",
        "virtualOverview": "Super+Ctrl+Space", "overviewAlternate": "Super+grave",
        "workspaceOverview": "Super+Tab",
            "windowFocusLeft": "Super+Left", "windowFocusRight": "Super+Right",
            "moveWindowLeft": "Super+Shift+Left", "moveWindowRight": "Super+Shift+Right",
    }
    quickisland = {
        "settingsKeybind": "Super+I",
        "launcherKeybind": "Super+A",
        "gameModeKeybind": "Super+G",
        "sessionMenuKeybind": "Ctrl+Alt+Delete",
        **provided_quickisland,
    }
    quickisland["keybinds"] = {**default_keybinds, **provided_quickisland.get("keybinds", {})}
    windows = {
        "gapsIn": 5,
        "gapsOut": 10,
        "borderSize": 0,
        "rounding": 18,
        "activeOpacity": 1.0,
        "inactiveOpacity": 1.0,
        "fullscreenOpacity": 1.0,
        "shadowEnabled": False,
        "blurEnabled": False,
        "animationsEnabled": True,
        **quickisland.get("windows", {}),
    }

    gaps_in = int(number(windows, "gapsIn", minimum=0, maximum=30))
    gaps_out = int(number(windows, "gapsOut", minimum=0, maximum=50))
    border_size = int(number(windows, "borderSize", minimum=0, maximum=8))
    rounding = int(number(windows, "rounding", minimum=0, maximum=40))
    active_opacity = number(windows, "activeOpacity", minimum=0.5, maximum=1)
    inactive_opacity = number(windows, "inactiveOpacity", minimum=0.5, maximum=1)
    fullscreen_opacity = number(windows, "fullscreenOpacity", minimum=0.5, maximum=1)

    ipc = f"/usr/bin/quickshell ipc -p {shlex.quote(str(args.shell_dir))} call"
    lua_bindings = []
    shortcuts = set()
    for setting, label, action in ACTIONS:
        value = quickisland
        for part in setting.split("."):
            value = value[part]
        chord = str(value)
        normalized = " ".join(hypr_chord(chord))
        if normalized in shortcuts:
            raise ValueError(f"Duplicate QuickIsland shortcut: {chord}")
        shortcuts.add(normalized)
        modifiers, key = hypr_chord(chord)
        description = f"QuickIsland: {label}"
        if action.startswith("__focus_"):
            direction = "l" if action.endswith("left__") else "r"
            direction_name = "left" if direction == "l" else "right"
            lua_bindings.append((lua_chord(chord), f"focus:{direction_name}", description))
        elif action.startswith("__move_"):
            direction = "l" if action.endswith("left__") else "r"
            direction_name = "left" if direction == "l" else "right"
            lua_bindings.append((lua_chord(chord), f"move:{direction_name}", description))
        else:
            command = (
                shlex.quote(str(args.shell_dir / "scripts/session_menu.sh"))
                if action == "__session_menu__"
                else f"{ipc} {action}"
            )
            lua_bindings.append((lua_chord(chord), command, description))

    window_lines = [
        "# Generated by QuickIsland Settings. Changes are overwritten.",
        "general {",
        f"    gaps_in = {gaps_in}",
        f"    gaps_out = {gaps_out}",
        f"    border_size = {border_size}",
        "}",
        "decoration {",
        f"    rounding = {rounding}",
        f"    active_opacity = {active_opacity:g}",
        f"    inactive_opacity = {inactive_opacity:g}",
        f"    fullscreen_opacity = {fullscreen_opacity:g}",
        "    blur {",
        f"        enabled = {'true' if windows['blurEnabled'] else 'false'}",
        "    }",
        "    shadow {",
        f"        enabled = {'true' if windows['shadowEnabled'] else 'false'}",
        "    }",
        "}",
        "animations {",
        f"    enabled = {'true' if windows['animationsEnabled'] else 'false'}",
        "}",
        "",
    ]

    config_dir = args.settings.parent
    atomic_write(config_dir / "quickisland-window-settings.conf", "\n".join(window_lines))
    (config_dir / "quickisland-settings-keybindings.conf").unlink(missing_ok=True)

    lua_lines = [
        "-- Generated by QuickIsland Settings. Changes are overwritten.",
        "local bindings = {",
    ]
    for chord, command, description in lua_bindings:
        lua_lines.append(f"    {{ {json.dumps(chord)}, {json.dumps(command)}, {json.dumps(description)} }},")
    lua_lines.extend([
        "}",
        "for _, item in ipairs(bindings) do",
        "    local action = item[2]",
        "    if action:sub(1, 6) == \"focus:\" then",
        "        hl.bind(item[1], hl.dsp.focus({ direction = action:sub(7) }), { description = item[3] })",
        "    elseif action:sub(1, 5) == \"move:\" then",
        "        hl.bind(item[1], hl.dsp.window.move({ direction = action:sub(6) }), { description = item[3] })",
        "    else",
        "        hl.bind(item[1], hl.dsp.exec_cmd(action), { description = item[3] })",
        "    end",
        "end",
        "",
    ])
    profile_dir = Path(os.environ.get("HYPR_QUICKISLAND_PROFILE_DIR", str(Path.home() / ".config/hypr")))
    atomic_write(profile_dir / "quickisland_settings_keybindings.lua", "\n".join(lua_lines))

    update_game_mode_snapshot(windows)
    result = subprocess.run(["hyprctl", "reload"], check=True, capture_output=True, text=True)
    print(result.stdout.strip() or "QuickIsland settings applied and Hyprland reloaded.")


if __name__ == "__main__":
    main()
