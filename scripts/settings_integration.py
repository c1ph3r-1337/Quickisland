#!/usr/bin/env python3
"""Install or remove the small, reversible Hyprland hook for QuickIsland Settings."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path


HOME = Path.home()
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", str(HOME / ".local/state"))) / "quickisland/settings-integration"
USERPREFS = Path(os.environ.get("HYPR_USERPREFS_FILE", str(HOME / ".config/hypr/userprefs.conf")))
PROFILE_DIR = Path(os.environ.get("HYPR_QUICKISLAND_PROFILE_DIR", str(HOME / ".config/hypr")))
LUA_BINDINGS = Path(os.environ.get("HYPR_QUICKISLAND_LUA_FILE", str(PROFILE_DIR / "quickisland_keybindings.lua")))
STATE_FILE = STATE_DIR / "integration.json"
START = "# BEGIN QuickIsland Settings integration"
END = "# END QuickIsland Settings integration"
LUA_GENERATED = PROFILE_DIR / "quickisland_settings_keybindings.lua"
LUA_REQUIRE = f'dofile("{LUA_GENERATED}")'


def install() -> None:
    if not USERPREFS.is_file() or not LUA_BINDINGS.is_file():
        raise FileNotFoundError(f"Expected Hyprland files were not found: {USERPREFS} and {LUA_BINDINGS}")
    if STATE_FILE.exists():
        print("QuickIsland settings integration is already installed.")
        return

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(USERPREFS, STATE_DIR / "userprefs.before")
    shutil.copy2(LUA_BINDINGS, STATE_DIR / "quickisland_keybindings.before")

    userprefs_text = USERPREFS.read_text(encoding="utf-8")
    userprefs_lines = userprefs_text.splitlines()
    removed_userprefs = [
        line for line in userprefs_lines
        if line.lstrip().startswith("bind =")
        and (
            ("quickshell ipc" in line and "/quickisland" in line and "spatial_workspace.sh" not in line)
            or any(dispatcher in line for dispatcher in ("movefocus, l", "movefocus, r", "movewindow, l", "movewindow, r"))
        )
    ]
    removed_lua = [
        line for line in LUA_BINDINGS.read_text(encoding="utf-8").splitlines()
        if line.lstrip().startswith('qi("SUPER +')
        or ('run("SUPER + G",' in line and "game_mode toggle" in line)
        or ('run("CTRL + ALT + Delete",' in line and "session_menu.sh" in line)
        or line.lstrip().startswith('focus("SUPER + Left"')
        or line.lstrip().startswith('focus("SUPER + Right"')
        or line.lstrip().startswith('move("SUPER + SHIFT + Left"')
        or line.lstrip().startswith('move("SUPER + SHIFT + Right"')
    ]
    STATE_FILE.write_text(json.dumps({
        "userprefs": str(USERPREFS),
        "luaBindings": str(LUA_BINDINGS),
        "userprefsRemoved": removed_userprefs,
        "luaRemoved": removed_lua,
    }, indent=2) + "\n", encoding="utf-8")

    userprefs_lines = [line for line in userprefs_lines if line not in removed_userprefs]
    include_block = [
        START,
        f"source = {HOME / '.config/quickisland/quickisland-window-settings.conf'}",
        END,
    ]
    userprefs_lines.extend(["", *include_block])
    USERPREFS.write_text("\n".join(userprefs_lines) + "\n", encoding="utf-8")

    lua_text = LUA_BINDINGS.read_text(encoding="utf-8")
    lua_lines = lua_text.splitlines()
    lua_lines = [line for line in lua_lines if line not in removed_lua and line.strip() != LUA_REQUIRE]
    lua_lines.extend(["", "-- QuickIsland Settings manages these shortcuts from settings.json.", LUA_REQUIRE])
    LUA_BINDINGS.write_text("\n".join(lua_lines) + "\n", encoding="utf-8")

    print(f"Installed reversible QuickIsland Settings hooks in {USERPREFS} and {LUA_BINDINGS}.")


def uninstall() -> None:
    if not STATE_FILE.exists():
        print("QuickIsland settings integration is not installed.")
        return
    state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    userprefs = Path(state["userprefs"])
    userprefs_lines = userprefs.read_text(encoding="utf-8").splitlines()
    result: list[str] = []
    in_block = False
    for line in userprefs_lines:
        if line.strip() == START:
            in_block = True
            continue
        if line.strip() == END:
            in_block = False
            continue
        if not in_block:
            result.append(line)
    result.extend(line for line in state["userprefsRemoved"] if line not in result)
    userprefs.write_text("\n".join(result) + "\n", encoding="utf-8")

    lua_bindings = Path(state["luaBindings"])
    lua_lines = [
        line for line in lua_bindings.read_text(encoding="utf-8").splitlines()
        if line.strip() != LUA_REQUIRE and "QuickIsland Settings manages these shortcuts" not in line
    ]
    lua_lines.extend(line for line in state["luaRemoved"] if line not in lua_lines)
    lua_bindings.write_text("\n".join(lua_lines) + "\n", encoding="utf-8")

    for generated in (
        HOME / ".config/quickisland/quickisland-settings-keybindings.conf",
        HOME / ".config/quickisland/quickisland-window-settings.conf",
        PROFILE_DIR / "quickisland_settings_keybindings.lua",
    ):
        generated.unlink(missing_ok=True)
    STATE_FILE.unlink()
    print("Removed the QuickIsland Settings hooks and restored their previous shortcuts.")


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("install", "uninstall"))
    action = parser.parse_args().action
    if action == "install":
        install()
        settings_file = Path(os.environ.get("QUICKISLAND_SETTINGS_FILE", os.environ.get("NOCTALIA_SETTINGS_FILE", str(HOME / ".config/quickisland/settings.json"))))
        shell_dir = Path(__file__).resolve().parent.parent
        subprocess.run([
            "python3", str(Path(__file__).with_name("sync_settings.py")),
            "--settings", str(settings_file), "--shell-dir", str(shell_dir),
        ], check=True)
        return
    uninstall()
    result = subprocess.run(["hyprctl", "reload"], capture_output=True, text=True)
    if result.returncode:
        print(result.stderr.strip() or "Hyprland reload was unavailable; the file changes are in place.")
    else:
        print(result.stdout.strip() or "Hyprland reloaded.")


if __name__ == "__main__":
    main()
