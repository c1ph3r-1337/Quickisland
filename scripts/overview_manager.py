#!/usr/bin/env python3
"""
Material Shell-style spatial overview manager for QuickIsland.

In Material Shell:
- Every workspace is a horizontal row
- In overview, workspace rows are stacked vertically in the center
- Inside each row, windows are displayed at their relative positions
- Keyboard Up/Down navigates workspaces (rows), Left/Right navigates windows
- Enter or click switches directly to that workspace/window
"""

import json
import subprocess
import os
import sys
import shutil
import time

STATE_DIR = os.path.expanduser("~/.cache/quickisland")
LAYOUT_FILE = os.path.join(STATE_DIR, "overview_layout.json")
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


def enter_overview():
    t0 = time.time()
    env = get_hypr_env()

    monitors = run_json("hyprctl monitors -j", env=env)
    if not monitors:
        log("No monitors found")
        return

    # Focused monitor
    mon = next((m for m in monitors if m.get("focused")), monitors[0])
    scale = mon.get("scale", 1.0)
    mon_x = mon["x"]
    mon_y = mon["y"]
    mon_w = int(mon["width"] / scale)
    mon_h = int(mon["height"] / scale)

    active_ws_info = run_json("hyprctl activeworkspace -j", env=env) or {}
    active_ws_id = active_ws_info.get("id", 1)

    workspaces = run_json("hyprctl workspaces -j", env=env) or []
    clients = run_json("hyprctl clients -j", env=env) or []

    # Filter clients: mapped and not special
    valid_clients = [c for c in clients if c.get("mapped") and c.get("workspace", {}).get("id", 0) > 0]

    # Collect all workspace IDs (always include 1, 2, 3 as minimum, plus existing)
    ws_ids = set([1, 2, 3, active_ws_id])
    for w in workspaces:
        if w.get("id", 0) > 0:
            ws_ids.add(w["id"])
    for c in valid_clients:
        ws_ids.add(c["workspace"]["id"])

    sorted_ws_ids = sorted(list(ws_ids))

    # Optional capture directory for active window screenshots
    os.makedirs(CAPTURES_DIR, exist_ok=True)

    # Build workspace rows
    rows = []
    for idx, ws_id in enumerate(sorted_ws_ids):
        ws_clients = [c for c in valid_clients if c["workspace"]["id"] == ws_id]
        
        # Sort clients from left to right (by X position)
        ws_clients.sort(key=lambda c: c["at"][0])

        windows = []
        for c in ws_clients:
            # Calculate normalized relative coordinates (0.0 to 1.0) inside workspace
            cx, cy = c["at"]
            cw, ch = c["size"]

            # Normalize relative to monitor
            rel_x = max(0.0, min(1.0, (cx - mon_x) / mon_w))
            rel_y = max(0.0, min(1.0, (cy - mon_y) / mon_h))
            rel_w = max(0.05, min(1.0, cw / mon_w))
            rel_h = max(0.05, min(1.0, ch / mon_h))

            # Attempt fast grim screenshot if window is on active workspace and visible
            screenshot_path = None
            if ws_id == active_ws_id and not c.get("hidden"):
                shot_file = os.path.join(CAPTURES_DIR, f"win_{c['address'].replace('0x', '')}.png")
                try:
                    # Capture exact window geometry at fast compression
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

            windows.append({
                "address": c["address"],
                "class": c.get("class", ""),
                "title": c.get("title", ""),
                "focused": (c.get("focusHistoryID") == 0),
                "rel_x": round(rel_x, 4),
                "rel_y": round(rel_y, 4),
                "rel_w": round(rel_w, 4),
                "rel_h": round(rel_h, 4),
                "screenshot": screenshot_path,
            })

        rows.append({
            "id": ws_id,
            "row": idx,
            "is_active": (ws_id == active_ws_id),
            "window_count": len(windows),
            "windows": windows,
        })

    layout = {
        "active_id": active_ws_id,
        "monitor": {
            "w": mon_w,
            "h": mon_h,
        },
        "rows": rows,
    }

    os.makedirs(STATE_DIR, exist_ok=True)
    with open(LAYOUT_FILE, "w") as f:
        json.dump(layout, f)

    elapsed = (time.time() - t0) * 1000
    log(f"enter took {elapsed:.0f}ms — {len(rows)} workspace rows, {len(valid_clients)} windows")


def exit_overview():
    try:
        os.remove(LAYOUT_FILE)
    except FileNotFoundError:
        pass
    if os.path.exists(CAPTURES_DIR):
        shutil.rmtree(CAPTURES_DIR, ignore_errors=True)
    log("exit — cleaned up")


def jump_to(ws_id):
    env = get_hypr_env()
    try:
        subprocess.run(["hyprctl", "dispatch", "workspace", str(ws_id)], env=env, timeout=2)
    except Exception as e:
        log(f"jump failed: {e}")
    exit_overview()


def focus_window(addr):
    env = get_hypr_env()
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
        ws = int(sys.argv[2]) if len(sys.argv) > 2 else 1
        jump_to(ws)
    elif action == "focus":
        addr = sys.argv[2] if len(sys.argv) > 2 else ""
        focus_window(addr)
    else:
        print(f"Usage: {sys.argv[0]} enter|exit|jump <ws_id>|focus <address>", file=sys.stderr)
        sys.exit(1)
