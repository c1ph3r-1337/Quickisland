#!/usr/bin/env python3
"""
Hyprland Canvas Daemon: Real-Time Coordinate Memory & Auto-Binding Engine.

Listens to Hyprland socket2 IPC events:
1. When ANY window opens, it immediately binds it to its designated virtual workspace (vx, vy).
2. If an app was previously remembered or pinned in canvas_bindings.json, it automatically opens on that exact coordinate.
3. If an app is new, it binds to the current virtual coordinate and remembers it for future launches.
4. Prevents window coordinate drift, unexpected movements, or layout warping by Hyprland tiling.
"""

import socket
import subprocess
import json
import os
import sys
import glob
import time
import fcntl

STATE_DIR = os.path.expanduser("~/.cache/quickisland")
STATE_FILE = os.path.join(STATE_DIR, "spatial_workspace_state.json")
COORD_FILE = os.path.join(STATE_DIR, "spatial_workspace_coords")
BINDINGS_FILE = os.path.expanduser("~/.config/quickshell/quickisland/canvas_bindings.json")
LOCK_FILE = os.path.join(STATE_DIR, "canvas_daemon.lock")


def log(msg):
    print(f"[canvas-daemon] {msg}", file=sys.stderr, flush=True)


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
        out = subprocess.check_output(cmd, shell=True, env=env, timeout=2).decode()
        return json.loads(out)
    except Exception:
        return None


def load_state():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"cur_vx": 0, "cur_vy": 0, "windows": {}}


def save_state(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)
    with open(COORD_FILE, "w") as f:
        f.write(f"{state.get('cur_vx', 0)} {state.get('cur_vy', 0)}\n")


def load_bindings():
    if os.path.exists(BINDINGS_FILE):
        try:
            with open(BINDINGS_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"remember_last_coordinates": True, "default_bindings": {}, "remembered_apps": {}}


def save_bindings(bindings):
    try:
        os.makedirs(os.path.dirname(BINDINGS_FILE), exist_ok=True)
        with open(BINDINGS_FILE, "w") as f:
            json.dump(bindings, f, indent=2)
    except Exception as e:
        log(f"Failed to save bindings: {e}")


def get_monitor_info(env):
    monitors = run_json("hyprctl monitors -j", env=env) or []
    if not monitors:
        return 0, 0, 1600, 900
    mon = next((m for m in monitors if m.get("focused")), monitors[0])
    scale = mon.get("scale", 1.0)
    mon_x = mon.get("x", 0)
    mon_y = mon.get("y", 0)
    mon_w = int(mon.get("width", 1600) / scale)
    mon_h = int(mon.get("height", 900) / scale)
    return mon_x, mon_y, mon_w, mon_h


def on_window_open(addr, ws_name, win_class, title, env):
    # Short pause to let Hyprland allocate window properties
    time.sleep(0.04)

    clients = run_json("hyprctl clients -j", env=env) or []
    c = next((cl for cl in clients if cl.get("address") == addr or cl.get("address") == f"0x{addr}"), None)
    if not c:
        return

    full_addr = c["address"]
    mon_x, mon_y, mon_w, mon_h = get_monitor_info(env)

    state = load_state()
    cur_vx = state.get("cur_vx", 0)
    cur_vy = state.get("cur_vy", 0)
    windows = state.get("windows", {})


    app_class = c.get("class", win_class)

    target_vx = cur_vx
    target_vy = cur_vy
    win_w = c["size"][0] if c.get("size") and c["size"][0] > 100 else 1020
    win_h = c["size"][1] if c.get("size") and c["size"][1] > 100 else 580
    cx, cy = c.get("at", [mon_x + 10, mon_y + 43])
    local_x = max(0, min(mon_w - 50, cx - mon_x))
    local_y = max(0, min(mon_h - 50, cy - mon_y))
    log(f"Registered window {app_class} ({full_addr}) at current virtual ({target_vx}, {target_vy})")

    # Save to state
    active_ws_id = c.get("workspace", {}).get("id", 1)
    windows[full_addr] = {
        "ws": active_ws_id,
        "vx": target_vx,
        "vy": target_vy,
        "local_x": round(local_x),
        "local_y": round(local_y),
        "w": win_w,
        "h": win_h,
        "class": app_class,
    }
    state["windows"] = windows
    save_state(state)

    # Position window physically in Hyprland
    target_x = int(mon_x + (target_vx - cur_vx) * mon_w + local_x)
    target_y = int(mon_y - (target_vy - cur_vy) * mon_h + local_y)

    batch = []
    if not c.get("floating", False):
        batch.append(f"dispatch togglefloating address:{full_addr}")
    batch.append(f"dispatch resizewindowpixel exact {win_w} {win_h},address:{full_addr}")
    batch.append(f"dispatch movewindowpixel exact {target_x} {target_y},address:{full_addr}")
    if target_vx == cur_vx and target_vy == cur_vy:
        batch.append(f"dispatch focuswindow address:{full_addr}")

    cmd_str = ";".join(batch) + ";"
    subprocess.run(["hyprctl", "--batch", cmd_str], env=env, timeout=2)


def on_window_close(addr):
    state = load_state()
    windows = state.get("windows", {})
    cleaned = {a: win for a, win in windows.items() if not (a == addr or a == f"0x{addr}")}
    if len(cleaned) != len(windows):
        state["windows"] = cleaned
        save_state(state)


def find_socket2():
    pattern = f"/run/user/{os.getuid()}/hypr/*/.socket2.sock"
    sockets = glob.glob(pattern)
    if sockets:
        sockets.sort(key=os.path.getmtime, reverse=True)
        return sockets[0]
    return None


def main():
    # Enforce single instance
    os.makedirs(STATE_DIR, exist_ok=True)
    lock_fd = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        log("Daemon already running, exiting.")
        sys.exit(0)

    log("Starting Canvas Memory Daemon...")
    env = get_hypr_env()

    while True:
        sock_path = find_socket2()
        if not sock_path or not os.path.exists(sock_path):
            time.sleep(1)
            continue

        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            log(f"Connected to Hyprland socket2: {sock_path}")

            buffer = ""
            while True:
                data = s.recv(4096)
                if not data:
                    break
                buffer += data.decode("utf-8", errors="ignore")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line:
                        continue

                    if line.startswith("openwindow>>"):
                        parts = line[len("openwindow>>"):].split(",")
                        if len(parts) >= 4:
                            addr, ws_name, win_class, title = parts[0], parts[1], parts[2], parts[3]
                            try:
                                on_window_open(addr, ws_name, win_class, title, env)
                            except Exception as e:
                                log(f"Error handling openwindow: {e}")

                    elif line.startswith("closewindow>>"):
                        addr = line[len("closewindow>>"):].strip()
                        try:
                            on_window_close(addr)
                        except Exception as e:
                            log(f"Error handling closewindow: {e}")

        except Exception as e:
            log(f"Socket connection error: {e}. Reconnecting in 2s...")
            time.sleep(2)


if __name__ == "__main__":
    main()
