#!/usr/bin/env python3
"""
Rock-solid Coordinate-Locked Spatial Workspace Engine for Hyprland.

Maintains an absolute virtual coordinate grid (vx, vy) for each window.
Prevents window drift, loss of coordinates, and animation lag corruption.
Windows remain pinned to their exact virtual workspace coordinate forever.
When Spatial Workspace is disabled, seamlessly navigates physical Hyprland workspaces.
"""

import sys
import os
import json
import subprocess
import fcntl
import math
import time

STATE_DIR = os.path.expanduser("~/.cache/quickisland")
STATE_FILE = os.path.join(STATE_DIR, "spatial_workspace_state.json")
LEGACY_STATE_FILE = os.path.join(STATE_DIR, "infinite_canvas_state.json")
COORD_FILE = os.path.join(STATE_DIR, "spatial_workspace_coords")
LEGACY_COORD_FILE = os.path.join(STATE_DIR, "infinite_canvas_coords")
LOCK_FILE = os.path.join(STATE_DIR, "spatial_workspace.lock")
SPATIAL_STATE_FILE = os.path.join(STATE_DIR, "spatial_wm_state")


def is_spatial_enabled():
    try:
        if os.path.exists(SPATIAL_STATE_FILE):
            with open(SPATIAL_STATE_FILE, "r") as f:
                return f.read().strip() == "1"
    except Exception:
        pass
    return False


def get_hypr_env():
    env = dict(os.environ)
    if "HYPRLAND_INSTANCE_SIGNATURE" not in env:
        hypr_dir = f"/run/user/{os.getuid()}/hypr"
        if os.path.exists(hypr_dir):
            dirs = [d for d in os.listdir(hypr_dir) if os.path.isdir(os.path.join(hypr_dir, d)) and "_" in d]
            if dirs:
                dirs.sort(key=lambda d: os.path.getmtime(os.path.join(hypr_dir, d)), reverse=True)
                env["HYPRLAND_INSTANCE_SIGNATURE"] = dirs[0]
    return env


def run_json(cmd, env):
    try:
        out = subprocess.check_output(cmd, shell=True, env=env, timeout=3).decode()
        return json.loads(out)
    except Exception:
        return None


def load_state():
    for fpath in (STATE_FILE, LEGACY_STATE_FILE):
        if os.path.exists(fpath):
            try:
                with open(fpath, "r") as f:
                    return json.load(f)
            except Exception:
                pass
    # Fallback to COORD_FILE
    cur_vx, cur_vy = 0, 0
    for cpath in (COORD_FILE, LEGACY_COORD_FILE):
        if os.path.exists(cpath):
            try:
                with open(cpath, "r") as f:
                    parts = f.read().strip().split()
                    if len(parts) >= 2:
                        cur_vx, cur_vy = int(parts[0]), int(parts[1])
                        break
            except Exception:
                pass
    return {"cur_vx": cur_vx, "cur_vy": cur_vy, "windows": {}}


def save_state(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    coords_content = f"{state['cur_vx']} {state['cur_vy']}\n"
    for fpath in (STATE_FILE, LEGACY_STATE_FILE):
        try:
            with open(fpath, "w") as f:
                json.dump(state, f, indent=2)
        except Exception:
            pass
    for cpath in (COORD_FILE, LEGACY_COORD_FILE):
        try:
            with open(cpath, "w") as f:
                f.write(coords_content)
        except Exception:
            pass


def main():
    if len(sys.argv) < 2:
        print("Usage: spatial_workspace.py left|right|up|down|jump <vx> <vy>|reset", file=sys.stderr)
        sys.exit(1)

    action = sys.argv[1].lower()
    os.makedirs(STATE_DIR, exist_ok=True)
    env = get_hypr_env()

    # If spatial workspace is toggled off, fallback to default window focus switching
    if not is_spatial_enabled():
        if action == "left":
            subprocess.run(["hyprctl", "dispatch", "movefocus", "l"], env=env)
        elif action == "right":
            subprocess.run(["hyprctl", "dispatch", "movefocus", "r"], env=env)
        elif action == "up":
            subprocess.run(["hyprctl", "dispatch", "movefocus", "u"], env=env)
        elif action == "down":
            subprocess.run(["hyprctl", "dispatch", "movefocus", "d"], env=env)
        elif action == "jump" and len(sys.argv) > 2:
            try:
                target_ws = int(sys.argv[2]) + 1
                subprocess.run(["hyprctl", "dispatch", "workspace", str(target_ws)], env=env)
            except Exception:
                pass
        return

    # Use file locking to guarantee atomic execution across rapid keypresses
    lock_fd = open(LOCK_FILE, "w")
    fcntl.flock(lock_fd, fcntl.LOCK_EX)

    try:
        monitors = run_json("hyprctl monitors -j", env=env) or []
        if not monitors:
            return
        mon = next((m for m in monitors if m.get("focused")), monitors[0])
        scale = mon.get("scale", 1.0)
        mon_x = mon["x"]
        mon_y = mon["y"]
        mon_w = int(mon["width"] / scale)
        mon_h = int(mon["height"] / scale)

        active_ws_info = run_json("hyprctl activeworkspace -j", env=env) or {}
        active_ws_id = active_ws_info.get("id", 1)

        clients = run_json("hyprctl clients -j", env=env) or []
        all_clients = {c["address"]: c for c in clients}
        ws_clients = {addr: c for addr, c in all_clients.items() if c.get("workspace", {}).get("id") == active_ws_id}

        state = load_state()
        ws_key = str(active_ws_id)
        workspaces = state.setdefault("workspaces", {})
        if ws_key not in workspaces:
            workspaces[ws_key] = {
                "cur_vx": state.get("cur_vx", 0),
                "cur_vy": state.get("cur_vy", 0)
            }
        cur_vx = workspaces[ws_key].get("cur_vx", 0)
        cur_vy = workspaces[ws_key].get("cur_vy", 0)
        windows = state.get("windows", {})

        now = time.time()
        last_action_time = state.get("last_action_time", 0)
        last_action = state.get("last_action", "")

        # Debounce: ignore rapid duplicate triggers within 120ms
        if action in ("left", "right", "up", "down") and action == last_action and (now - last_action_time) < 0.12:
            return

        state["last_action_time"] = now
        state["last_action"] = action

        # Clean up only windows that have actually been closed/destroyed in Hyprland
        windows = {addr: win for addr, win in windows.items() if addr in all_clients}

        # Track and register any newly opened windows on the active workspace
        for addr, c in ws_clients.items():
            cx, cy = c["at"]
            cw, ch = c["size"]
            app_class = c.get("class", "")
            if addr not in windows:
                is_on_screen = (cx >= mon_x - 50 and cx < mon_x + mon_w + 50 and
                                cy >= mon_y - 50 and cy < mon_y + mon_h + 50)
                if is_on_screen:
                    local_x = max(0, min(mon_w - 50, cx - mon_x))
                    local_y = max(0, min(mon_h - 50, cy - mon_y))
                    win_vx = cur_vx
                    win_vy = cur_vy
                else:
                    win_vx = cur_vx + int(math.floor((cx + cw / 2 - mon_x) / mon_w))
                    win_vy = cur_vy - int(math.floor((cy + ch / 2 - mon_y) / mon_h))
                    row_origin_y = mon_y - (win_vy - cur_vy) * mon_h
                    local_x = cx - (mon_x + (win_vx - cur_vx) * mon_w)
                    local_y = cy - row_origin_y

                windows[addr] = {
                    "ws": active_ws_id,
                    "vx": win_vx,
                    "vy": win_vy,
                    "local_x": round(local_x),
                    "local_y": round(local_y),
                    "w": cw,
                    "h": ch,
                    "class": app_class,
                    "was_floating": c.get("floating", False)  # remember original floating state
                }
            else:
                win = windows[addr]
                win["ws"] = active_ws_id
                if app_class:
                    win["class"] = app_class
                # If window belongs to this physical workspace and is on current virtual cell, update its local position/size if moved
                if win.get("vx") == cur_vx and win.get("vy") == cur_vy:
                    is_on_screen = (cx >= mon_x - 50 and cx < mon_x + mon_w + 50 and
                                    cy >= mon_y - 50 and cy < mon_y + mon_h + 50)
                    if is_on_screen:
                        win["local_x"] = max(0, min(mon_w - 50, cx - mon_x))
                        win["local_y"] = max(0, min(mon_h - 50, cy - mon_y))
                        win["w"] = cw
                        win["h"] = ch

        # Calculate new virtual coordinates
        new_vx = cur_vx
        new_vy = cur_vy

        if action == "left":
            new_vx -= 1
        elif action == "right":
            new_vx += 1
        elif action == "up":
            new_vy += 1
        elif action == "down":
            new_vy -= 1
        elif action == "jump":
            try:
                new_vx = int(sys.argv[2])
                new_vy = int(sys.argv[3])
            except Exception:
                pass
        elif action == "reset":
            new_vx = 0
            new_vy = 0
            # Reset all current windows on active workspace to (0, 0)
            for win in windows.values():
                if win.get("ws") == active_ws_id:
                    win["vx"] = 0
                    win["vy"] = 0

        workspaces[ws_key]["cur_vx"] = new_vx
        workspaces[ws_key]["cur_vy"] = new_vy
        state["cur_vx"] = new_vx
        state["cur_vy"] = new_vy
        state["windows"] = windows
        state["workspaces"] = workspaces

        # Generate exact, deterministic target positions for every window
        batch_cmds = []
        best_focus_addr = None
        best_focus_dist = 999999999
        center_x = mon_x + mon_w / 2
        center_y = mon_y + mon_h / 2

        for addr, win in windows.items():
            c = ws_clients.get(addr)
            if not c:
                continue

            target_x = int(mon_x + (win["vx"] - new_vx) * mon_w + win["local_x"])
            target_y = int(mon_y - (win["vy"] - new_vy) * mon_h + win["local_y"])
            win_w = win.get("w", c["size"][0])
            win_h = win.get("h", c["size"][1])

            is_on_screen = (win["vx"] == new_vx and win["vy"] == new_vy)
            currently_floating = c.get("floating", False)

            # Backfill was_floating for windows registered before this fix,
            # but only when the window is currently on-screen (hasn't been force-floated yet).
            # Default False — assume originally tiled if unknown.
            if "was_floating" not in win:
                win["was_floating"] = currently_floating if is_on_screen else False
            was_floating = win["was_floating"]

            if c.get("fullscreen", 0) > 0:
                batch_cmds.append(f"dispatch fullscreen 0,address:{addr}")

            if is_on_screen:
                # Window returning to viewport — restore original float state
                if not was_floating and currently_floating:
                    # Was originally tiled — restore to tiled
                    batch_cmds.append(f"dispatch togglefloating address:{addr}")
                elif was_floating and not currently_floating:
                    # Was originally floating — restore to floating
                    batch_cmds.append(f"dispatch togglefloating address:{addr}")
            else:
                # Window going off-screen — must float to move freely
                if not currently_floating:
                    batch_cmds.append(f"dispatch togglefloating address:{addr}")

            # Tiled windows coming back: let Hyprland layout handle position/size
            if is_on_screen and not was_floating:
                pass
            else:
                if c.get("size") != [win_w, win_h]:
                    batch_cmds.append(f"dispatch resizewindowpixel exact {win_w} {win_h},address:{addr}")
                batch_cmds.append(f"dispatch movewindowpixel exact {target_x} {target_y},address:{addr}")

            # If window is now on screen, check distance to center for focus
            if is_on_screen:
                dx = (target_x + win_w / 2) - center_x
                dy = (target_y + win_h / 2) - center_y
                dist = dx * dx + dy * dy
                if dist < best_focus_dist:
                    best_focus_dist = dist
                    best_focus_addr = addr

        if best_focus_addr:
            batch_cmds.append(f"dispatch focuswindow address:{best_focus_addr}")

        if batch_cmds:
            batch_str = ";".join(batch_cmds) + ";"
            subprocess.run(["hyprctl", "--batch", batch_str], env=env, timeout=3)

        save_state(state)

        # Notify quickisland of coordinate change
        subprocess.Popen([
            "quickshell", "ipc", "-p",
            os.path.expanduser("~/.config/quickshell/quickisland"),
            "call", "virtual_workspace", "set_coords", str(new_vx), str(new_vy)
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    finally:
        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        lock_fd.close()


if __name__ == "__main__":
    main()
