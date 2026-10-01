#!/usr/bin/env python3
"""
Coordinate-Locked Material Shell Spatial Overview Manager for QuickIsland.

Manages the Infinite Canvas (Virtual Spatial Workspaces) on Hyprland:
- Reads the authoritative infinite_canvas_state.json.
- Positions windows in their exact virtual coordinate cells with live screenshots.
- Zero coordinate drift or missing windows.
- Selecting any window or cell navigates directly to that exact (vx, vy) coordinate.
"""

import json
import subprocess
import os
import sys
import math
import time

STATE_DIR = os.path.expanduser("~/.cache/quickisland")
STATE_FILE = os.path.join(STATE_DIR, "infinite_canvas_state.json")
LAYOUT_FILE = os.path.join(STATE_DIR, "overview_layout.json")
COORD_FILE = os.path.join(STATE_DIR, "infinite_canvas_coords")
CAPTURES_DIR = os.path.join(STATE_DIR, "overview_captures")
SAVED_COORDS_FILE = os.path.join(STATE_DIR, "overview_saved_coords.json")


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


def load_state():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    cur_vx, cur_vy = 0, 0
    if os.path.exists(COORD_FILE):
        try:
            with open(COORD_FILE, "r") as f:
                parts = f.read().strip().split()
                if len(parts) >= 2:
                    cur_vx, cur_vy = int(parts[0]), int(parts[1])
        except Exception:
            pass
    return {"cur_vx": cur_vx, "cur_vy": cur_vy, "windows": {}}


def save_state(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)
    with open(COORD_FILE, "w") as f:
        f.write(f"{state['cur_vx']} {state['cur_vy']}\n")


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

    active_ws_info = run_json("hyprctl activeworkspace -j", env=env) or {}
    active_ws_id = active_ws_info.get("id", 1)

    clients = run_json("hyprctl clients -j", env=env) or []
    all_clients = {c["address"]: c for c in clients}
    all_mapped = {c["address"]: c for c in clients if c.get("mapped")}
    ws_clients = {addr: c for addr, c in all_clients.items() if c.get("workspace", {}).get("id") == active_ws_id}

    ws_key = str(active_ws_id)
    state = load_state()
    workspaces = state.setdefault("workspaces", {})
    if ws_key not in workspaces:
        workspaces[ws_key] = {
            "cur_vx": state.get("cur_vx", 0),
            "cur_vy": state.get("cur_vy", 0)
        }
    cur_vx = workspaces[ws_key].get("cur_vx", 0)
    cur_vy = workspaces[ws_key].get("cur_vy", 0)
    windows = state.get("windows", {})

    # Clean up closed windows
    windows = {addr: win for addr, win in windows.items() if addr in all_clients}

    os.makedirs(CAPTURES_DIR, exist_ok=True)

    # Synchronize any windows on active workspace
    state_changed = False
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
                "class": app_class
            }
            state_changed = True
        else:
            win = windows[addr]
            win["ws"] = active_ws_id
            if app_class:
                win["class"] = app_class
            # If window is on the current viewport and stationary on screen, capture latest local offset
            if win.get("vx") == cur_vx and win.get("vy") == cur_vy:
                is_on_screen = (cx >= mon_x - 50 and cx < mon_x + mon_w + 50 and
                                cy >= mon_y - 50 and cy < mon_y + mon_h + 50)
                if is_on_screen:
                    win["local_x"] = max(0, min(mon_w - 50, cx - mon_x))
                    win["local_y"] = max(0, min(mon_h - 50, cy - mon_y))
                    win["w"] = cw
                    win["h"] = ch
                    state_changed = True

    if state_changed:
        state["windows"] = windows
        state["workspaces"] = workspaces
        save_state(state)

    # Process all windows on this active workspace
    all_windows = []
    occupied_vys = {cur_vy}

    for addr, win in windows.items():
        c = ws_clients.get(addr)
        if not c:
            continue

        vwx = win.get("vx", cur_vx)
        vwy = win.get("vy", cur_vy)
        occupied_vys.add(vwy)

        local_x = win.get("local_x", 0)
        local_y = win.get("local_y", 0)
        win_w = win.get("w", c["size"][0])
        win_h = win.get("h", c["size"][1])

        # Offset relative to center monitor viewport (0..1 = inside card, <0 = left, >1 = right)
        offset_x = (vwx - cur_vx) + (local_x / mon_w)
        offset_y = max(0.0, min(1.0, local_y / mon_h))
        rel_w = max(0.08, min(1.0, win_w / mon_w))
        rel_h = max(0.08, min(1.0, win_h / mon_h))

        clean_addr = addr.replace("0x", "")
        shot_file = os.path.join(CAPTURES_DIR, f"win_{clean_addr}.png")
        screenshot_path = None

        # Screencopy is handled in real-time by ScreencopyView in QML via DMA-BUF.
        screenshot_path = shot_file if os.path.exists(shot_file) else None

        win_obj = {
            "address": addr,
            "class": c.get("class", ""),
            "title": c.get("title", ""),
            "focused": (c.get("focusHistoryID") == 0),
            "vwx": vwx,
            "vwy": vwy,
            "rel_x": round(max(0.0, min(1.0, local_x / mon_w)), 4),
            "rel_y": round(max(0.0, min(1.0, local_y / mon_h)), 4),
            "offset_x": round(offset_x, 4),
            "offset_y": round(offset_y, 4),
            "rel_w": round(rel_w, 4),
            "rel_h": round(rel_h, 4),
            "screenshot": screenshot_path,
        }
        all_windows.append(win_obj)

    # Collect all horizontal cell coordinates (vx) across all windows and cur_vx
    all_vxs = {cur_vx}
    for w in all_windows:
        all_vxs.add(w["vwx"])
    min_all_vx = min(all_vxs)
    max_all_vx = max(all_vxs)

    # Dynamic row stack: show only rows that have at least one window (or active workspace)
    display_vys = sorted(list(occupied_vys), reverse=True)

    # Build rows (descending vy: top-to-bottom, matching Material Shell)
    rows = []
    selected_row_idx = 0

    for r_idx, vy in enumerate(display_vys):
        is_active_row = (vy == cur_vy)
        if is_active_row:
            selected_row_idx = r_idx

        row_wins = [w for w in all_windows if w["vwy"] == vy]
        row_wins.sort(key=lambda w: (w["vwx"], w["rel_x"]))

        # Workspaces with at least one window in this row
        occupied_vx_set = {w["vwx"] for w in row_wins}
        if not occupied_vx_set and vy == cur_vy:
            occupied_vx_set.add(cur_vx)

        # Center windows within each workspace cell preview
        for vx in occupied_vx_set:
            cell_wins = [w for w in row_wins if w["vwx"] == vx]
            if not cell_wins:
                continue
            min_x = min(w["rel_x"] for w in cell_wins)
            max_x = max(w["rel_x"] + w["rel_w"] for w in cell_wins)
            total_w = max_x - min_x

            min_y = min(w["rel_y"] for w in cell_wins)
            max_y = max(w["rel_y"] + w["rel_h"] for w in cell_wins)
            total_h = max_y - min_y

            shift_x = round((1.0 - total_w) / 2.0 - min_x, 4)
            shift_y = round((1.0 - total_h) / 2.0 - min_y, 4)

            for w in cell_wins:
                w["rel_x"] = round(max(0.01, min(0.99 - w["rel_w"], w["rel_x"] + shift_x)), 4)
                w["rel_y"] = round(max(0.01, min(0.99 - w["rel_h"], w["rel_y"] + shift_y)), 4)

        cells = []
        for vx in sorted(list(occupied_vx_set)):
            has_w = any(w["vwx"] == vx for w in row_wins)
            cells.append({
                "vx": vx,
                "is_current": (vx == cur_vx and vy == cur_vy),
                "is_current_col": (vx == cur_vx),
                "has_windows": has_w
            })

        rows.append({
            "vy": vy,
            "row_index": r_idx,
            "is_active": is_active_row,
            "cells": cells,
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

    # Ensure all off-screen windows on this workspace are temporarily placed within monitor bounds
    # so Hyprland's compositor commits their frames to Wayland screencopy via zero-copy DMA-BUF.
    saved_coords = {}
    if os.path.exists(SAVED_COORDS_FILE):
        try:
            with open(SAVED_COORDS_FILE, "r") as f:
                saved_coords = json.load(f)
        except Exception:
            saved_coords = {}

    batch_moves = []
    for addr, c in ws_clients.items():
        cx, cy = c["at"]
        cw, ch = c["size"]
        is_on_screen = (cx >= mon_x - 50 and cx < mon_x + mon_w + 50 and
                        cy >= mon_y - 50 and cy < mon_y + mon_h + 50)
        if not is_on_screen:
            if addr not in saved_coords:
                saved_coords[addr] = [cx, cy]
            target_temp_x = int(mon_x + 50)
            target_temp_y = int(mon_y + 50)
            batch_moves.append(f"dispatch movewindowpixel exact {target_temp_x} {target_temp_y},address:{addr}")

    if saved_coords:
        with open(SAVED_COORDS_FILE, "w") as f:
            json.dump(saved_coords, f)

    if batch_moves:
        batch_cmd = "keyword animations:enabled false;" + ";".join(batch_moves) + ";keyword animations:enabled true;"
        subprocess.run(["hyprctl", "--batch", batch_cmd], env=env, timeout=2)

    elapsed = (time.time() - t0) * 1000
    log(f"enter took {elapsed:.0f}ms — {len(rows)} rows, current ({cur_vx}, {cur_vy})")


def restore_saved_coords(cleanup_only=False):
    """Restore off-screen windows to their saved positions."""
    env = get_hypr_env()
    if os.path.exists(SAVED_COORDS_FILE):
        if not cleanup_only:
            try:
                with open(SAVED_COORDS_FILE, "r") as f:
                    saved_coords = json.load(f)
                if saved_coords:
                    batch_restores = [
                        f"dispatch movewindowpixel exact {coords[0]} {coords[1]},address:{addr}"
                        for addr, coords in saved_coords.items()
                    ]
                    batch_cmd = "keyword animations:enabled false;" + ";".join(batch_restores) + ";keyword animations:enabled true;"
                    subprocess.run(["hyprctl", "--batch", batch_cmd], env=env, timeout=2)
            except Exception as e:
                log(f"Error restoring saved coords: {e}")
        try:
            os.remove(SAVED_COORDS_FILE)
        except Exception:
            pass


def exit_overview():
    log("exit overview")
    restore_saved_coords(cleanup_only=False)


def jump_to(target_arg):
    """Jump to target virtual workspace coordinate (format: 'vx_vy' or 'vx vy')."""
    canvas_script = os.path.expanduser("~/.config/quickshell/quickisland/scripts/infinite_canvas.sh")
    if not os.path.exists(canvas_script):
        log(f"Canvas script not found: {canvas_script}")
        return

    env = get_hypr_env()
    active_ws_info = run_json("hyprctl activeworkspace -j", env=env) or {}
    active_ws_id = active_ws_info.get("id", 1)
    ws_key = str(active_ws_id)

    state = load_state()
    workspaces = state.get("workspaces", {})
    ws_coords = workspaces.get(ws_key, {})
    cur_vx = ws_coords.get("cur_vx", state.get("cur_vx", 0))
    cur_vy = ws_coords.get("cur_vy", state.get("cur_vy", 0))
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

    if target_vx == cur_vx and target_vy == cur_vy:
        exit_overview()
        return

    log(f"jumping to virtual workspace ({target_vx}, {target_vy})")
    restore_saved_coords(cleanup_only=True)
    subprocess.run([canvas_script, "jump", str(target_vx), str(target_vy)], timeout=2)


def focus_window(addr):
    """Focus a window, jumping the canvas to its exact virtual cell first if needed."""
    env = get_hypr_env()
    canvas_script = os.path.expanduser("~/.config/quickshell/quickisland/scripts/infinite_canvas.sh")

    active_ws_info = run_json("hyprctl activeworkspace -j", env=env) or {}
    active_ws_id = active_ws_info.get("id", 1)
    ws_key = str(active_ws_id)

    state = load_state()
    workspaces = state.get("workspaces", {})
    ws_coords = workspaces.get(ws_key, {})
    cur_vx = ws_coords.get("cur_vx", state.get("cur_vx", 0))
    cur_vy = ws_coords.get("cur_vy", state.get("cur_vy", 0))
    win_state = state.get("windows", {}).get(addr)

    if win_state:
        target_vx = win_state.get("vx", cur_vx)
        target_vy = win_state.get("vy", cur_vy)
        if target_vx != cur_vx or target_vy != cur_vy:
            log(f"window {addr} at virtual ({target_vx}, {target_vy}) -> jumping canvas")
            restore_saved_coords(cleanup_only=True)
            subprocess.run([canvas_script, "jump", str(target_vx), str(target_vy)], timeout=2)
        else:
            restore_saved_coords(cleanup_only=False)
    else:
        restore_saved_coords(cleanup_only=False)

    try:
        subprocess.run(["hyprctl", "dispatch", "focuswindow", f"address:{addr}"], env=env, timeout=2)
    except Exception as e:
        log(f"focus failed: {e}")



if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else ""

    if action == "enter":
        enter_overview()
    elif action == "exit":
        exit_overview()
    elif action == "jump":
        target = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else "0_0"
        jump_to(target)
    elif action == "focus":
        addr = sys.argv[2] if len(sys.argv) > 2 else ""
        focus_window(addr)
    else:
        print(f"Usage: {sys.argv[0]} enter|exit|jump <target>|focus <address>", file=sys.stderr)
        sys.exit(1)
