#!/usr/bin/env python3
"""
Coordinate-aware Material Shell spatial overview manager for QuickIsland.

Manages the Infinite Canvas (Virtual Spatial Workspaces) on Hyprland:
- Every virtual workspace cell is defined by (vx, vy) coordinates.
- Workspaces are structured in a 2D coordinate grid (rows = vy, columns = vx).
- Windows are positioned in their exact coordinate cells with live screenshots.
- Selecting any cell or window navigates the canvas to that exact (vx, vy) coordinate.
"""

import json
import subprocess
import os
import sys
import math
import time

STATE_DIR = os.path.expanduser("~/.cache/quickisland")
LAYOUT_FILE = os.path.join(STATE_DIR, "overview_layout.json")
COORD_FILE = os.path.join(STATE_DIR, "infinite_canvas_coords")
CAPTURES_DIR = os.path.join(STATE_DIR, "overview_captures")


def log(msg):
    print(f"[overview] {msg}", file=sys.stderr)


def get_hypr_env():
    """Ensure HYPRLAND_INSTANCE_SIGNATURE is available."""
    env = dict(os.environ)
    if "HYPRLAND_INSTANCE_SIGNATURE" not in env:
        hypr_dir = f"/run/user/{os.getuid()}/hypr"
        if os.path.exists(hypr_dir):
            dirs = [d for d in os.listdir(hypr_dir) if os.path.isdir(os.path.join(hypr_dir, d)) and "_" in d]
            if dirs:
                dirs.sort(key=lambda d: os.path.getmtime(os.path.join(hypr_dir, d)), reverse=True)
                env["HYPRLAND_INSTANCE_SIGNATURE"] = dirs[0]
    return env


def run_json(cmd, env=None):
    try:
        out = subprocess.check_output(cmd, shell=True, env=env, timeout=3).decode()
        return json.loads(out)
    except Exception as e:
        log(f"run_json failed for '{cmd}': {e}")
        return None


def get_virtual_coords():
    try:
        if os.path.exists(COORD_FILE):
            with open(COORD_FILE) as f:
                parts = f.read().strip().split()
                if len(parts) >= 2:
                    return int(parts[0]), int(parts[1])
    except Exception:
        pass
    return 0, 0


def enter_overview():
    t0 = time.time()
    env = get_hypr_env()

    monitors = run_json("hyprctl monitors -j", env=env)
    if not monitors:
        log("No monitors found")
        return

    mon = next((m for m in monitors if m.get("focused")), monitors[0])
    scale = mon.get("scale", 1.0)
    mon_x = mon["x"]
    mon_y = mon["y"]
    mon_w = int(mon["width"] / scale)
    mon_h = int(mon["height"] / scale)

    cur_vx, cur_vy = get_virtual_coords()

    active_ws_info = run_json("hyprctl activeworkspace -j", env=env) or {}
    active_ws_id = active_ws_info.get("id", 1)

    clients = run_json("hyprctl clients -j", env=env) or []
    # Filter clients: mapped and on the current active Hyprland workspace
    ws_clients = [c for c in clients if c.get("mapped") and c.get("workspace", {}).get("id") == active_ws_id]

    os.makedirs(CAPTURES_DIR, exist_ok=True)

    # Map windows to their virtual coordinate cells (vwx, vwy) and row offsets
    all_windows = []
    occupied_vys = set([cur_vy])
    for c in ws_clients:
        cx, cy = c["at"]
        cw, ch = c["size"]
        center_x = cx + cw / 2
        center_y = cy + ch / 2

        vwx = cur_vx + int(math.floor((center_x - mon_x) / mon_w))
        vwy = cur_vy - int(math.floor((center_y - mon_y) / mon_h))
        occupied_vys.add(vwy)

        # Offset relative to center monitor viewport (0..1 = inside card, <0 = left, >1 = right)
        offset_x = (cx - mon_x) / mon_w
        # Offset relative to row vertical boundaries
        row_origin_y = mon_y - (vwy - cur_vy) * mon_h
        offset_y = max(0.0, min(1.0, (cy - row_origin_y) / mon_h))
        rel_w = max(0.08, min(1.0, cw / mon_w))
        rel_h = max(0.08, min(1.0, ch / mon_h))

        clean_addr = c["address"].replace("0x", "")
        shot_file = os.path.join(CAPTURES_DIR, f"win_{clean_addr}.png")
        screenshot_path = None

        is_visible_on_screen = (
            cx >= mon_x and (cx + cw) <= (mon_x + mon_w) and
            cy >= mon_y and (cy + ch) <= (mon_y + mon_h) and
            not c.get("hidden", False)
        )

        if is_visible_on_screen:
            try:
                subprocess.run(
                    ["grim", "-g", f"{cx},{cy} {cw}x{ch}", "-t", "png", "-l", "1", shot_file],
                    timeout=1.5,
                    check=True,
                    capture_output=True,
                    env=env,
                )
                screenshot_path = shot_file
            except Exception:
                screenshot_path = None
        elif os.path.exists(shot_file):
            screenshot_path = shot_file

        win_obj = {
            "address": c["address"],
            "class": c.get("class", ""),
            "title": c.get("title", ""),
            "focused": (c.get("focusHistoryID") == 0),
            "vwx": vwx,
            "vwy": vwy,
            "offset_x": round(offset_x, 4),
            "offset_y": round(offset_y, 4),
            "rel_w": round(rel_w, 4),
            "rel_h": round(rel_h, 4),
            "screenshot": screenshot_path,
        }
        all_windows.append(win_obj)

    # Exactly 3 vertical rows: cur_vy + 1 (top), cur_vy (current), cur_vy - 1 (bottom)
    display_vys = [cur_vy + 1, cur_vy, cur_vy - 1]

    # Build rows (descending vy: top-to-bottom, matching Material Shell)
    rows = []
    selected_row_idx = 0

    for r_idx, vy in enumerate(display_vys):
        is_active_row = (vy == cur_vy)
        if is_active_row:
            selected_row_idx = r_idx

        row_wins = [w for w in all_windows if w["vwy"] == vy]
        row_wins.sort(key=lambda w: w["offset_x"])

        rows.append({
            "vy": vy,
            "row_index": r_idx,
            "is_active": is_active_row,
            "window_count": len(row_wins),
            "windows": row_wins,
        })

    wallpaper_path = os.path.expanduser("~/.cache/wal/current-wallpaper")
    layout = {
        "cur_vx": cur_vx,
        "cur_vy": cur_vy,
        "selected_row": selected_row_idx,
        "wallpaper": wallpaper_path if os.path.exists(wallpaper_path) else "",
        "rows": rows,
    }

    os.makedirs(STATE_DIR, exist_ok=True)
    with open(LAYOUT_FILE, "w") as f:
        json.dump(layout, f)

    elapsed = (time.time() - t0) * 1000
    log(f"enter took {elapsed:.0f}ms — {len(rows)} rows, current ({cur_vx}, {cur_vy})")


def exit_overview():
    log("exit overview")


def jump_to(target_arg):
    """Jump to target virtual workspace coordinate (format: 'vx_vy' or 'vx vy')."""
    canvas_script = os.path.expanduser("~/.config/quickshell/quickisland/scripts/infinite_canvas.sh")
    if not os.path.exists(canvas_script):
        log(f"Canvas script not found: {canvas_script}")
        return

    cur_vx, cur_vy = get_virtual_coords()
    target_vx = cur_vx
    target_vy = cur_vy

    str_arg = str(target_arg).strip()
    if "_" in str_arg:
        parts = str_arg.split("_")
        try:
            target_vx = int(parts[0])
            target_vy = int(parts[1])
        except Exception:
            pass
    elif " " in str_arg:
        parts = str_arg.split()
        try:
            target_vx = int(parts[0])
            target_vy = int(parts[1])
        except Exception:
            pass
    else:
        try:
            target_vy = int(str_arg)
        except Exception:
            pass

    log(f"jumping to virtual workspace ({target_vx}, {target_vy})")
    subprocess.run([canvas_script, "jump", str(target_vx), str(target_vy)], timeout=2)
    exit_overview()


def focus_window(addr):
    """Focus a window, jumping the canvas to its virtual cell first if needed."""
    env = get_hypr_env()
    canvas_script = os.path.expanduser("~/.config/quickshell/quickisland/scripts/infinite_canvas.sh")

    monitors = run_json("hyprctl monitors -j", env=env) or [{}]
    mon = next((m for m in monitors if m.get("focused")), monitors[0])
    scale = mon.get("scale", 1.0)
    mon_x = mon.get("x", 0)
    mon_y = mon.get("y", 0)
    mon_w = int(mon.get("width", 1600) / scale)
    mon_h = int(mon.get("height", 900) / scale)

    cur_vx, cur_vy = get_virtual_coords()

    clients = run_json("hyprctl clients -j", env=env) or []
    target_win = next((c for c in clients if c.get("address") == addr), None)

    if target_win and os.path.exists(canvas_script):
        cx, cy = target_win["at"]
        cw, ch = target_win["size"]
        vwx = cur_vx + int(math.floor(((cx + cw / 2) - mon_x) / mon_w))
        vwy = cur_vy - int(math.floor(((cy + ch / 2) - mon_y) / mon_h))

        if vwx != cur_vx or vwy != cur_vy:
            log(f"window at virtual ({vwx}, {vwy}) -> jumping canvas")
            subprocess.run([canvas_script, "jump", str(vwx), str(vwy)], timeout=2)

    try:
        subprocess.run(["hyprctl", "dispatch", "focuswindow", f"address:{addr}"], env=env, timeout=2)
    except Exception as e:
        log(f"focus failed: {e}")
    exit_overview()


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else ""

    if action == "enter":
        enter_overview()
    elif action == "exit":
        exit_overview()
    elif action == "jump":
        target = sys.argv[2] if len(sys.argv) > 2 else "0_0"
        jump_to(target)
    elif action == "focus":
        addr = sys.argv[2] if len(sys.argv) > 2 else ""
        focus_window(addr)
    else:
        print(f"Usage: {sys.argv[0]} enter|exit|jump <target>|focus <address>", file=sys.stderr)
        sys.exit(1)
