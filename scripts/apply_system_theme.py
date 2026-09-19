#!/usr/bin/env python3
import sys
import json
import os
import subprocess
from pathlib import Path

def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip("#")
    if len(hex_str) == 3:
        hex_str = "".join([c*2 for c in hex_str])
    return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(rgb):
    return f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}"

def blend(c1, c2, factor):
    r1, g1, b1 = hex_to_rgb(c1)
    r2, g2, b2 = hex_to_rgb(c2)
    r = int(r1 * (1 - factor) + r2 * factor)
    g = int(g1 * (1 - factor) + g2 * factor)
    b = int(b1 * (1 - factor) + b2 * factor)
    return rgb_to_hex((r, g, b))

def main():
    if len(sys.argv) < 2:
        print("Usage: apply_system_theme.py '<theme_json>'")
        sys.exit(1)

    try:
        data = json.loads(sys.argv[1])
    except Exception as e:
        print(f"Error parsing theme JSON: {e}")
        sys.exit(1)

    name = data.get("name", "custom")
    accent = data.get("accent", "#cba6f7")
    surface = data.get("surface", "#11111b")
    surface_alt = data.get("surfaceAlt", "#1e1e2e")
    surface_bright = data.get("surfaceBright", "#313244")
    text_primary = data.get("textPrimary", "#cdd6f4")
    text_secondary = data.get("textSecondary", "#a6adc8")
    text_muted = data.get("textMuted", "#6c7086")

    dot1 = data.get("dot1") or blend(surface, accent, 0.35)
    dot2 = data.get("dot2") or blend(surface, accent, 0.55)
    dot3 = data.get("dot3") or blend(surface, accent, 0.75)
    dot4 = data.get("dot4") or accent
    dot5 = data.get("dot5") or blend(accent, text_primary, 0.35)
    dot6 = data.get("dot6") or blend(accent, text_primary, 0.75)

    red = data.get("red") or dot1
    green = data.get("green") or dot2
    peach = data.get("peach") or dot3
    blue = data.get("blue") or dot4

    home = Path.home()

    # 1. Update Kitty Terminal Theme
    kitty_theme_file = home / ".config/kitty/current-theme.conf"
    kitty_theme_file.parent.mkdir(parents=True, exist_ok=True)
    kitty_content = f"""# QuickIsland Auto-Generated Theme: {name}
color0 {surface}
color1 {dot1}
color2 {dot2}
color3 {dot3}
color4 {dot4}
color5 {dot5}
color6 {dot6}
color7 {text_secondary}
color8 {surface_bright}
color9 {dot1}
color10 {dot2}
color11 {dot3}
color12 {dot4}
color13 {dot5}
color14 {dot6}
color15 {text_primary}

cursor                {accent}
cursor_text_color     {surface}
background            {surface}
foreground            {text_primary}
selection_foreground  {surface}
selection_background  {accent}
active_border_color   {accent}
inactive_border_color {surface_bright}
url_color             {accent}

active_tab_foreground   {surface}
active_tab_background   {accent}
inactive_tab_foreground {text_secondary}
inactive_tab_background {surface_alt}
cursor_trail_color      {accent}
"""
    try:
        kitty_theme_file.write_text(kitty_content)
        # Notify kitty instances to reload config
        subprocess.run(["killall", "-SIGUSR1", "kitty"], stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"Error updating Kitty: {e}")

    # 2. Update Hyprland Borders & Window styling
    clean_accent = accent.lstrip("#")
    clean_surface = surface_alt.lstrip("#")
    try:
        subprocess.run([
            "hyprctl", "keyword", "general:col.active_border", f"rgb({clean_accent})"
        ], stderr=subprocess.DEVNULL)
        subprocess.run([
            "hyprctl", "keyword", "general:col.inactive_border", f"rgb({clean_surface})"
        ], stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"Error updating Hyprland: {e}")

    # 3. Update GTK 3 & 4 (Nautilus, text editors, etc.)
    # Map theme name to installed GTK themes if available
    gtk_theme_map = {
        "catppuccin": "Catppuccin-Mocha",
        "tokyo night": "Tokyo-Night",
        "gruvbox": "Gruvbox-Retro",
        "nord": "Nordic-Blue",
        "rose pine": "Rose-Pine",
        "synthwave": "Synth-Wave",
        "anime": "Catppuccin-Mocha",
        "ariadne": "Decay-Green"
    }
    matched_gtk_theme = gtk_theme_map.get(name.lower(), "Catppuccin-Mocha")

    # Set gsettings
    try:
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"], stderr=subprocess.DEVNULL)
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", matched_gtk_theme], stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"Error setting gsettings: {e}")

    # Write GTK 3 settings.ini
    gtk3_ini = home / ".config/gtk-3.0/settings.ini"
    if gtk3_ini.exists():
        try:
            content = gtk3_ini.read_text()
            lines = []
            for line in content.splitlines():
                if line.startswith("gtk-theme-name="):
                    lines.append(f"gtk-theme-name={matched_gtk_theme}")
                else:
                    lines.append(line)
            gtk3_ini.write_text("\n".join(lines) + "\n")
        except Exception as e:
            print(f"Error updating gtk-3 settings: {e}")

    # Write GTK 4 settings.ini
    gtk4_ini = home / ".config/gtk-4.0/settings.ini"
    if gtk4_ini.exists():
        try:
            content = gtk4_ini.read_text()
            lines = []
            for line in content.splitlines():
                if line.startswith("gtk-theme-name="):
                    lines.append(f"gtk-theme-name={matched_gtk_theme}")
                else:
                    lines.append(line)
            gtk4_ini.write_text("\n".join(lines) + "\n")
        except Exception as e:
            print(f"Error updating gtk-4 settings: {e}")

    # Write GTK 4 & libadwaita custom accent/colors (gtk-4.0/gtk.css) for Nautilus and libadwaita apps
    gtk4_css = home / ".config/gtk-4.0/gtk.css"
    gtk3_css = home / ".config/gtk-3.0/gtk.css"
    gtk_css_content = f"""/* QuickIsland Live Theme: {name} */
@define-color accent_color {accent};
@define-color accent_bg_color {accent};
@define-color accent_fg_color {surface};

@define-color window_bg_color {surface};
@define-color window_fg_color {text_primary};
@define-color view_bg_color {surface};
@define-color view_fg_color {text_primary};
@define-color headerbar_bg_color {surface_alt};
@define-color headerbar_fg_color {text_primary};
@define-color card_bg_color {surface_alt};
@define-color card_fg_color {text_primary};
@define-color popover_bg_color {surface_alt};
@define-color popover_fg_color {text_primary};
@define-color dialog_bg_color {surface};
@define-color dialog_fg_color {text_primary};

@define-color error_bg_color {red};
@define-color error_fg_color {surface};
@define-color warning_bg_color {peach};
@define-color warning_fg_color {surface};
@define-color success_bg_color {green};
@define-color success_fg_color {surface};
"""
    try:
        gtk4_css.write_text(gtk_css_content)
        gtk3_css.write_text(gtk_css_content)
    except Exception as e:
        print(f"Error writing GTK CSS: {e}")

    # 4. Update VS Code (Code & Code - OSS)
    code_user_dirs = [
        home / ".config/Code/User",
        home / ".config/Code - OSS/User"
    ]
    for user_dir in code_user_dirs:
        if not user_dir.exists():
            continue
        settings_file = user_dir / "settings.json"
        try:
            if settings_file.exists():
                cfg = json.loads(settings_file.read_text())
            else:
                cfg = {}

            # Background theme map for each theme
            theme_bg_map = {
                "catppuccin": ("#1e1e2e", "#181825", "#313244"),
                "tokyo night": ("#1a1b26", "#16161e", "#24283b"),
                "gruvbox": ("#282828", "#1d2021", "#3c3836"),
                "nord": ("#2e3440", "#242933", "#3b4252"),
                "everforest": ("#2d353b", "#232a2e", "#343f44"),
                "rose pine": ("#191724", "#1f1d2e", "#26233a"),
                "dracula": ("#282a36", "#21222c", "#343746"),
                "one dark": ("#282c34", "#21252b", "#2c313a"),
                "synthwave": ("#262335", "#1e1c2a", "#34294f"),
                "anime": ("#261a20", "#1e1419", "#38252f"),
                "ariadne": ("#142422", "#0d1a18", "#1e3633"),
                "wp coastal ocean": ("#0e2220", "#091816", "#183633"),
                "wp glacier mist": ("#162323", "#101a1a", "#223535"),
                "wp cosmic drift": ("#141d24", "#0e141a", "#202d38"),
                "wp emerald canopy": ("#142419", "#0e1a12", "#1f3827"),
                "wp autumn lake": ("#221a28", "#18121d", "#35293e"),
                "wp golden dusk": ("#262214", "#1b180e", "#3b351f"),
                "wp amber sunset": ("#261f14", "#1b160e", "#3b301f"),
                "wp misty mountain": ("#182026", "#11171c", "#25323c"),
                "wp azure ocean": ("#121f26", "#0c161b", "#1c303c"),
                "wp amethyst violet": ("#211628", "#170f1d", "#34233f"),
                "wp desert gold": ("#262014", "#1b170e", "#3a311f"),
                "wp earthy sand": ("#251f18", "#1a1611", "#393026"),
                "wp warm taupe": ("#251e17", "#1a1510", "#392f25"),
                "wp cyan breeze": ("#0e2321", "#091917", "#173633")
            }
            if name.lower() in theme_bg_map:
                theme_bg, theme_bg_alt, theme_bg_surface = theme_bg_map[name.lower()]
            else:
                theme_bg = blend(surface, accent, 0.18)
                theme_bg_alt = blend(surface, accent, 0.10)
                theme_bg_surface = blend(surface, accent, 0.32)

            # Preserve user's preferred code syntax theme (Material Theme Ocean)
            if not cfg.get("workbench.colorTheme") or cfg.get("workbench.colorTheme") in [
                "Everforest Dark", "Catppuccin Mocha", "Tokyo Night", "Gruvbox Dark Medium", "Nord", "Rosé Pine", "Atom One Dark", "Material Theme Deepforest"
            ]:
                cfg["workbench.colorTheme"] = "Material Theme Ocean"

            # Apply background theme colors to editor/UI while leaving code text syntax untouched
            customizations = cfg.get("workbench.colorCustomizations", {})

            # Clean up old overrides
            for k in [
                "editor.foreground", "terminal.foreground", "sideBar.foreground", "statusBar.foreground",
                "titleBar.activeForeground", "activityBar.foreground", "tab.inactiveForeground",
                "input.foreground", "sideBarSectionHeader.background", "editorLineNumber.foreground", "editorLineNumber.activeForeground"
            ]:
                customizations.pop(k, None)

            # Update background theme and accents
            customizations.update({
                "editor.background": theme_bg,
                "sideBar.background": theme_bg_alt,
                "activityBar.background": theme_bg_alt,
                "statusBar.background": theme_bg_alt,
                "titleBar.activeBackground": theme_bg_alt,
                "terminal.background": theme_bg,
                "tab.activeBackground": theme_bg,
                "tab.inactiveBackground": theme_bg_alt,
                "tab.activeBorder": accent,
                "tab.activeForeground": accent,
                "editorCursor.foreground": accent,
                "focusBorder": accent,
                "activityBar.activeBorder": accent,
                "sideBarSectionHeader.foreground": accent,
                "input.background": theme_bg_surface,
                "input.border": accent,
                "list.activeSelectionBackground": theme_bg_surface,
                "list.activeSelectionForeground": accent,
                "list.hoverBackground": blend(theme_bg, theme_bg_surface, 0.5)
            })
            cfg["workbench.colorCustomizations"] = customizations
            settings_file.write_text(json.dumps(cfg, indent=2))
        except Exception as e:
            print(f"Error updating VS Code in {user_dir}: {e}")

    # 5. Sync Pywal cache file so Pywal-based tools update as well
    pywal_file = home / ".cache/wal/colors.json"
    pywal_file.parent.mkdir(parents=True, exist_ok=True)
    pywal_json = {
        "wallpaper": "None",
        "alpha": "100",
        "special": {
            "background": surface,
            "foreground": text_primary,
            "cursor": accent
        },
        "colors": {
            "color0": surface,
            "color1": dot1,
            "color2": dot2,
            "color3": dot3,
            "color4": dot4,
            "color5": dot5,
            "color6": dot6,
            "color7": text_secondary,
            "color8": surface_bright,
            "color9": dot1,
            "color10": dot2,
            "color11": dot3,
            "color12": dot4,
            "color13": dot5,
            "color14": dot6,
            "color15": text_primary
        }
    }
    try:
        pywal_file.write_text(json.dumps(pywal_json, indent=2))
    except Exception as e:
        print(f"Error writing Pywal cache: {e}")

    print(f"Successfully applied system-wide theme: {name}")

if __name__ == "__main__":
    main()
