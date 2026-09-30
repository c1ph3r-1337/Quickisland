#!/usr/bin/env python3
"""
Material Shell-style spatial overview manager for Infinite Canvas on Hyprland.

Actions:
  enter  — Capture window screenshots, generate layout JSON for QML
  exit   — Clean up captures and layout files
  jump VX VY — Clean up and jump to target virtual workspace
"""

import json
import subprocess
import os
import sys
import math
import shutil
import time

STATE_DIR = os.path.expanduser("~/.cache/quickisland")
SAVE_FILE = os.path.join(STATE_DIR, "overview_saved.json")
LAYOUT_FILE = os.path.join(STATE_DIR, "overview_layout.json")
COORD_FILE = os.path.join(STATE_DIR, "infinite_canvas_coords")
CAPTURES_DIR = os.path.join(STATE_DIR, "overview_captures")


def log(msg):
    print(f"[overview] {msg}", file=sys.stderr)


def run_json(cmd):
    """Run a command and parse JSON output."""
    try:
        out = subprocess.check_output(cmd, shell=True, timeout=5).decode()
        return json.loads(out)
    except Exception as e:
        log(f"run_json failed for '{cmd}': {e}")
        return None


def get_virtual_pos():
    try:
        with open(COORD_FILE) as f:
            parts = f.read().strip().split()
            return int(parts[0]), int(parts[1])
    except Exception:
        return 0, 0


def get_monitor():
    monitors = run_json("hyprctl monitors -j")
    if not monitors:
        return None
    for m in monitors:
        if m.get("focused"):
            scale = m.get("scale", 1.0)
            return {
                "x": m["x"],
                "y": m["y"],
                "w": int(m["width"] / scale),
                "h": int(m["height"] / scale),
                "scale": scale,
            }
    # Fallback to first monitor
    m = monitors[0]
    scale = m.get("scale", 1.0)
    return {
        "x": m["x"],
        "y": m["y"],
        "w": int(m["width"] / scale),
        "h": int(m["height"] / scale),
        "scale": scale,
    }


def get_clients():
    clients = run_json("hyprctl clients -j")
    if not clients:
        return []
    return [c for c in clients if c.get("mapped")]


def get_active_workspace_id():
    ws = run_json("hyprctl activeworkspace -j")
    if ws:
        return ws.get("id", 1)
    return 1


def capture_region(x, y, w, h, output_path):
    """Capture a screen region using grim. Returns True on success."""
    try:
        # -l 1 = fast compression, -s 0.5 = half resolution for thumbnails
        subprocess.run(
            ["grim", "-g", f"{x},{y} {w}x{h}", "-t", "png", "-l", "1", "-s", "0.5", output_path],
            timeout=5,
            check=True,
            capture_output=True,
        )
        return True
    except Exception as e:
        log(f"grim capture failed for region {x},{y} {w}x{h}: {e}")
        return False


def enter_overview():
    t0 = time.time()

    mon = get_monitor()
    if not mon:
        log("No monitor found")
        return

    cur_vx, cur_vy = get_virtual_pos()
    ws_id = get_active_workspace_id()
    all_clients = get_clients()

    # Filter to current workspace
    clients = [c for c in all_clients if c.get("workspace", {}).get("id") == ws_id]

    # Calculate virtual cell for each window
    windows_by_cell = {}  # (vx, vy) -> list of window info
    saved_windows = []

    for c in clients:
        cx = c["at"][0] + c["size"][0] / 2.0  # window center x
        cy = c["at"][1] + c["size"][1] / 2.0  # window center y

        vwx = cur_vx + int(math.floor((cx - mon["x"]) / mon["w"]))
        vwy = cur_vy - int(math.floor((cy - mon["y"]) / mon["h"]))

        win_info = {
            "address": c["address"],
            "class": c.get("class", ""),
            "title": c.get("title", ""),
            "vwx": vwx,
            "vwy": vwy,
        }

        key = (vwx, vwy)
        if key not in windows_by_cell:
            windows_by_cell[key] = []
        windows_by_cell[key].append(win_info)

        # Save state for restoration
        saved_windows.append({
            "address": c["address"],
            "class": c.get("class", ""),
            "orig_x": c["at"][0],
            "orig_y": c["at"][1],
            "orig_w": c["size"][0],
            "orig_h": c["size"][1],
            "orig_floating": c.get("floating", False),
            "fullscreen": c.get("fullscreen", 0),
            "vwx": vwx,
            "vwy": vwy,
        })

    # Save original window states
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(SAVE_FILE, "w") as f:
        json.dump(saved_windows, f)

    # Determine grid bounds from occupied cells
    all_vx = set(k[0] for k in windows_by_cell.keys())
    all_vy = set(k[1] for k in windows_by_cell.keys())

    # Always include current position
    all_vx.add(cur_vx)
    all_vy.add(cur_vy)

    min_vx = min(all_vx)
    max_vx = max(all_vx)
    min_vy = min(all_vy)
    max_vy = max(all_vy)

    cols = max(max_vx - min_vx + 1, 1)
    rows = max(max_vy - min_vy + 1, 1)

    # Prepare captures directory
    if os.path.exists(CAPTURES_DIR):
        shutil.rmtree(CAPTURES_DIR)
    os.makedirs(CAPTURES_DIR, exist_ok=True)

    # Build cells array (top to bottom, left to right)
    cells = []
    for vy in range(max_vy, min_vy - 1, -1):  # highest vy first (top row)
        for vx in range(min_vx, max_vx + 1):
            key = (vx, vy)
            cell_windows = windows_by_cell.get(key, [])
            is_current = (vx == cur_vx and vy == cur_vy)

            # Calculate physical region for this cell
            phys_x = mon["x"] + (vx - cur_vx) * mon["w"]
            phys_y = mon["y"] - (vy - cur_vy) * mon["h"]

            # Check if region overlaps with monitor (i.e., is visible/capturable)
            # A region is capturable if it overlaps with the monitor bounds
            mon_right = mon["x"] + mon["w"]
            mon_bottom = mon["y"] + mon["h"]
            region_right = phys_x + mon["w"]
            region_bottom = phys_y + mon["h"]

            can_capture = (
                phys_x < mon_right
                and region_right > mon["x"]
                and phys_y < mon_bottom
                and region_bottom > mon["y"]
            )

            screenshot_path = None
            if can_capture and (cell_windows or is_current):
                fname = f"cell_{vx}_{vy}.png"
                fpath = os.path.join(CAPTURES_DIR, fname)
                if capture_region(phys_x, phys_y, mon["w"], mon["h"], fpath):
                    screenshot_path = fpath

            cells.append({
                "vx": vx,
                "vy": vy,
                "is_current": is_current,
                "screenshot": screenshot_path,
                "window_count": len(cell_windows),
                "windows": [
                    {"address": w["address"], "class": w["class"], "title": w["title"]}
                    for w in cell_windows
                ],
            })

    # Generate layout JSON
    layout = {
        "cells": cells,
        "grid": {
            "cols": cols,
            "rows": rows,
            "min_vx": min_vx,
            "max_vx": max_vx,
            "min_vy": min_vy,
            "max_vy": max_vy,
            "current_vx": cur_vx,
            "current_vy": cur_vy,
        },
        "monitor": {
            "x": mon["x"],
            "y": mon["y"],
            "w": mon["w"],
            "h": mon["h"],
        },
    }

    with open(LAYOUT_FILE, "w") as f:
        json.dump(layout, f)

    elapsed = (time.time() - t0) * 1000
    log(f"enter took {elapsed:.0f}ms — {len(cells)} cells, {len(saved_windows)} windows")


def exit_overview():
    """Clean up overview files."""
    for path in [SAVE_FILE, LAYOUT_FILE]:
        try:
            os.remove(path)
        except FileNotFoundError:
            pass

    if os.path.exists(CAPTURES_DIR):
        shutil.rmtree(CAPTURES_DIR, ignore_errors=True)

    log("exit — cleaned up")


def jump_to(target_vx, target_vy):
    """Clean up and jump to target virtual workspace."""
    cur_vx, cur_vy = get_virtual_pos()
    exit_overview()

    if target_vx != cur_vx or target_vy != cur_vy:
        script = os.path.expanduser(
            "~/.config/quickshell/quickisland/scripts/infinite_canvas.sh"
        )
        try:
            subprocess.run(
                ["bash", script, "jump", str(target_vx), str(target_vy)],
                timeout=5,
            )
        except Exception as e:
            log(f"jump failed: {e}")

    log(f"jumped to ({target_vx}, {target_vy})")


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else ""

    if action == "enter":
        enter_overview()
    elif action == "exit":
        exit_overview()
    elif action == "jump":
        vx = int(sys.argv[2]) if len(sys.argv) > 2 else 0
        vy = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        jump_to(vx, vy)
    else:
        print(f"Usage: {sys.argv[0]} enter|exit|jump [vx] [vy]", file=sys.stderr)
        sys.exit(1)
