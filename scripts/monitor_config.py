#!/usr/bin/env python3
import sys
import os
import json
import re
import subprocess

MONITORS_CONF = os.path.expanduser("~/.config/hypr/monitors.conf")
WORKSPACES_CONF = os.path.expanduser("~/.config/hypr/workspaces.conf")
MONITORS_LUA = os.path.expanduser("~/.config/hypr/monitors.lua")
WORKSPACES_LUA = os.path.expanduser("~/.config/hypr/workspaces.lua")

def get_monitors():
    # Run hyprctl monitors all -j
    try:
        res = subprocess.run(["hyprctl", "monitors", "all", "-j"], capture_output=True, text=True)
        monitors = json.loads(res.stdout)
    except Exception as e:
        monitors = []

    conf_monitors = {}
    conf_workspaces = {}

    # Try parsing monitors.lua first (preferred in 0.55+)
    if os.path.exists(MONITORS_LUA):
        try:
            with open(MONITORS_LUA, "r") as f:
                content = f.read()
            blocks = re.findall(r"hl\.monitor\(\{([^}]+)\}\)", content, re.DOTALL)
            for b in blocks:
                pairs = re.findall(r"(\w+)\s*=\s*([^,\n]+)", b)
                m_info = {}
                for k, v in pairs:
                    k = k.strip()
                    v = v.strip().strip('"').strip("'")
                    m_info[k] = v
                name = m_info.get("output")
                if name:
                    # Convert fields back to list format to match conf parser format
                    # name -> [mode, position, scale, (transform/mirror parameters)]
                    mode = m_info.get("mode", "preferred")
                    position = m_info.get("position", "auto")
                    scale = m_info.get("scale", "1.0")
                    disabled = m_info.get("disabled", "false")
                    
                    parts = []
                    if disabled.lower() == "true":
                        parts.append("disable")
                    else:
                        parts.append(mode)
                        parts.append(position)
                        parts.append(scale)
                        
                        transform = m_info.get("transform")
                        if transform:
                            parts.append("transform")
                            parts.append(transform)
                            
                        mirror = m_info.get("mirror")
                        if mirror:
                            parts.append("mirror")
                            parts.append(mirror)
                            
                    conf_monitors[name] = parts
        except Exception as e:
            pass

    # Fallback to monitors.conf
    if not conf_monitors and os.path.exists(MONITORS_CONF):
        try:
            with open(MONITORS_CONF, "r") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("monitor="):
                        parts = line.split("=", 1)[1].split(",")
                        if len(parts) >= 1:
                            name = parts[0].strip()
                            conf_monitors[name] = parts[1:]
        except Exception as e:
            pass

    # Try parsing workspaces.lua first (preferred in 0.55+)
    if os.path.exists(WORKSPACES_LUA):
        try:
            with open(WORKSPACES_LUA, "r") as f:
                content = f.read()
            blocks = re.findall(r"hl\.workspace_rule\(\{([^}]+)\}\)", content, re.DOTALL)
            for b in blocks:
                pairs = re.findall(r"(\w+)\s*=\s*([^,\n]+)", b)
                ws_info = {}
                for k, v in pairs:
                    k = k.strip()
                    v = v.strip().strip('"').strip("'")
                    ws_info[k] = v
                ws_id_str = ws_info.get("workspace")
                mon_name = ws_info.get("monitor")
                if ws_id_str and mon_name:
                    try:
                        ws_id = int(ws_id_str)
                        if mon_name not in conf_workspaces:
                            conf_workspaces[mon_name] = []
                        conf_workspaces[mon_name].append(ws_id)
                    except: pass
        except Exception as e:
            pass

    # Fallback to workspaces.conf
    if not conf_workspaces and os.path.exists(WORKSPACES_CONF):
        try:
            with open(WORKSPACES_CONF, "r") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("workspace="):
                        parts = line.split("=", 1)[1].split(",")
                        if len(parts) >= 2:
                            ws_id_str = parts[0].strip()
                            mon_part = parts[1].strip()
                            if mon_part.startswith("monitor:"):
                                mon_name = mon_part.split(":", 1)[1].strip()
                                try:
                                    ws_id = int(ws_id_str)
                                    if mon_name not in conf_workspaces:
                                        conf_workspaces[mon_name] = []
                                    conf_workspaces[mon_name].append(ws_id)
                                except: pass
        except Exception as e:
            pass

    result = []
    for m in monitors:
        name = m.get("name", "")
        if not name:
            continue
        # Defaults
        disabled = m.get("disabled", False)
        width = m.get("width", 1920)
        height = m.get("height", 1080)
        hz = m.get("refreshRate", 60.0)
        x = m.get("x", 0)
        y = m.get("y", 0)
        scale = m.get("scale", 1.0)
        transform = m.get("transform", 0)
        mirror = m.get("mirrorOf", "none")

        # Overlay settings from conf_monitors if present
        if name in conf_monitors:
            conf_parts = conf_monitors[name]
            if len(conf_parts) >= 1:
                val = conf_parts[0].strip()
                if val == "disable" or val == "disabled":
                    disabled = True
                else:
                    disabled = False
                    if "@" in val:
                        res_hz = val.split("@")
                        res_parts = res_hz[0].split("x")
                        if len(res_parts) == 2:
                            try:
                                width = int(res_parts[0])
                                height = int(res_parts[1])
                            except: pass
                        try:
                            hz_str = res_hz[1].replace("Hz", "").replace("hz", "").strip()
                            hz = float(hz_str)
                        except: pass
                    elif "x" in val:
                        res_parts = val.split("x")
                        if len(res_parts) == 2:
                            try:
                                width = int(res_parts[0])
                                height = int(res_parts[1])
                            except: pass
            
            # Position
            if len(conf_parts) >= 2:
                pos = conf_parts[1].strip()
                if pos != "auto":
                    pos_parts = pos.split("x")
                    if len(pos_parts) == 2:
                        try:
                            x = int(pos_parts[0])
                            y = int(pos_parts[1])
                        except: pass
            
            # Scale
            if len(conf_parts) >= 3:
                scale_str = conf_parts[2].strip()
                if scale_str != "auto":
                    try:
                        scale = float(scale_str)
                    except: pass
            
            # Transform / mirror
            for i in range(3, len(conf_parts)):
                param = conf_parts[i].strip()
                if param == "mirror" and i + 1 < len(conf_parts):
                    mirror = conf_parts[i+1].strip()
                elif param == "transform" and i + 1 < len(conf_parts):
                    try:
                        transform = int(conf_parts[i+1].strip())
                    except: pass

        workspaces_list = conf_workspaces.get(name, [])

        result.append({
            "name": name,
            "description": m.get("description", ""),
            "make": m.get("make", ""),
            "model": m.get("model", ""),
            "serial": m.get("serial", ""),
            "width": width,
            "height": height,
            "refreshRate": hz,
            "x": x,
            "y": y,
            "scale": scale,
            "transform": transform,
            "disabled": disabled,
            "mirrorOf": mirror,
            "availableModes": m.get("availableModes", []),
            "workspaces": workspaces_list
        })
    
    return result

def set_monitors(config_data):
    monitor_lines_conf = []
    workspace_lines_conf = []
    
    monitor_lines_lua = []
    workspace_lines_lua = []
    
    for m in config_data:
        name = m.get("name")
        if not name:
            continue
            
        disabled = m.get("disabled", False)
        
        # --- CONF (legacy) format ---
        if disabled:
            monitor_lines_conf.append(f"monitor={name},disable")
            # Apply dynamic changes immediately
            subprocess.run(["hyprctl", "keyword", "monitor", f"{name},disable"])
        else:
            width = m.get("width", 1920)
            height = m.get("height", 1080)
            hz = m.get("refreshRate", 60.0)
            res_str = f"{width}x{height}@{hz}"
            pos = f"{m.get('x', 0)}x{m.get('y', 0)}"
            scale = str(m.get("scale", 1.0))
            
            line_conf = f"monitor={name},{res_str},{pos},{scale}"
            keyword_args = f"{name},{res_str},{pos},{scale}"
            
            transform = m.get("transform", 0)
            if transform > 0:
                line_conf += f",transform,{transform}"
                keyword_args += f",transform,{transform}"
                
            mirror = m.get("mirrorOf", "none")
            if mirror != "none" and mirror:
                line_conf += f",mirror,{mirror}"
                keyword_args += f",mirror,{mirror}"
                
            monitor_lines_conf.append(line_conf)
            # Apply dynamic changes immediately
            subprocess.run(["hyprctl", "keyword", "monitor", keyword_args])
            
            # Workspaces conf
            workspaces = m.get("workspaces", [])
            for ws in workspaces:
                workspace_lines_conf.append(f"workspace={ws},monitor:{name}")
                subprocess.run(["hyprctl", "keyword", "workspace", f"{ws},monitor:{name}"])

        # --- LUA format ---
        if disabled:
            monitor_lines_lua.append(f"hl.monitor({{\n    output = \"{name}\",\n    disabled = true\n}})")
        else:
            width = m.get("width", 1920)
            height = m.get("height", 1080)
            hz = m.get("refreshRate", 60.0)
            res_str = f"{width}x{height}@{hz}"
            pos = f"{m.get('x', 0)}x{m.get('y', 0)}"
            scale = m.get("scale", 1.0)
            
            lua_block = f"hl.monitor({{\n    output = \"{name}\",\n    mode = \"{res_str}\",\n    position = \"{pos}\",\n    scale = {scale}"
            
            transform = m.get("transform", 0)
            if transform > 0:
                lua_block += f",\n    transform = {transform}"
                
            mirror = m.get("mirrorOf", "none")
            if mirror != "none" and mirror:
                lua_block += f",\n    mirror = \"{mirror}\""
                
            lua_block += "\n})"
            monitor_lines_lua.append(lua_block)
            
            # Workspaces lua
            workspaces = m.get("workspaces", [])
            for ws in workspaces:
                workspace_lines_lua.append(f"hl.workspace_rule({{\n    workspace = \"{ws}\",\n    monitor = \"{name}\"\n}})")

    # Write monitors.conf
    with open(MONITORS_CONF, "w") as f:
        f.write("# Generated by Quickisland Monitor Settings Panel. Do not edit manually.\n\n")
        for line in monitor_lines_conf:
            f.write(line + "\n")
            
    # Write workspaces.conf
    with open(WORKSPACES_CONF, "w") as f:
        f.write("# Generated by Quickisland Monitor Settings Panel. Do not edit manually.\n\n")
        for line in workspace_lines_conf:
            f.write(line + "\n")

    # Write monitors.lua
    with open(MONITORS_LUA, "w") as f:
        f.write("-- Generated by Quickisland Monitor Settings Panel. Do not edit manually.\n\n")
        f.write("\n\n".join(monitor_lines_lua) + "\n")
        
    # Write workspaces.lua
    with open(WORKSPACES_LUA, "w") as f:
        f.write("-- Generated by Quickisland Monitor Settings Panel. Do not edit manually.\n\n")
        f.write("\n\n".join(workspace_lines_lua) + "\n")
            
    # Reload configs
    subprocess.run(["hyprctl", "reload"])
    return {"success": True}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: monitor_config.py [get|set] [json_config]")
        sys.exit(1)
        
    cmd = sys.argv[1]
    if cmd == "get":
        print(json.dumps(get_monitors()))
    elif cmd == "set":
        if len(sys.argv) < 3:
            print("Error: JSON config required for set command.")
            sys.exit(1)
        try:
            config_data = json.loads(sys.argv[2])
            res = set_monitors(config_data)
            print(json.dumps(res))
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
