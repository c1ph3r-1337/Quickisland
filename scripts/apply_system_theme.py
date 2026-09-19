#!/usr/bin/env python3
import sys
import json
import os
import re
import subprocess
from pathlib import Path

def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip("#")
    if len(hex_str) == 3:
        hex_str = "".join([c*2 for c in hex_str])
    elif len(hex_str) == 8:
        hex_str = hex_str[:6]
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

def get_luminance(hex_str):
    r, g, b = hex_to_rgb(hex_str)
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

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

    # ---------------------------------------------------------
    # 1. Kitty Terminal Theme
    # ---------------------------------------------------------
    kitty_theme_file = home / ".config/kitty/current-theme.conf"
    try:
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
        kitty_theme_file.write_text(kitty_content)
        subprocess.run(["killall", "-SIGUSR1", "kitty"], stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"Error updating Kitty: {e}")

    # ---------------------------------------------------------
    # 2. Alacritty Terminal Theme
    # ---------------------------------------------------------
    alacritty_dir = home / ".config/alacritty"
    if alacritty_dir.exists():
        try:
            themes_dir = alacritty_dir / "themes"
            themes_dir.mkdir(parents=True, exist_ok=True)
            
            alacritty_content = f"""# QuickIsland Auto-Generated Theme: {name}
[colors.primary]
background = '{surface}'
foreground = '{text_primary}'

[colors.cursor]
text = '{surface}'
cursor = '{accent}'

[colors.vi_mode_cursor]
text = '{surface}'
cursor = '{text_primary}'

[colors.search.matches]
foreground = '{surface}'
background = '{accent}'

[colors.search.focused_match]
foreground = '{surface}'
background = '{text_primary}'

[colors.footer_bar]
foreground = '{text_secondary}'
background = '{surface_alt}'

[colors.hints.start]
foreground = '{surface}'
background = '{peach}'

[colors.hints.end]
foreground = '{surface}'
background = '{accent}'

[colors.selection]
text = '{surface}'
background = '{accent}'

[colors.normal]
black = '{surface_alt}'
red = '{red}'
green = '{green}'
yellow = '{peach}'
blue = '{blue}'
magenta = '{dot5}'
cyan = '{dot6}'
white = '{text_secondary}'

[colors.bright]
black = '{surface_bright}'
red = '{red}'
green = '{green}'
yellow = '{peach}'
blue = '{blue}'
magenta = '{accent}'
cyan = '{dot6}'
white = '{text_primary}'

[colors.dim]
black = '{surface}'
red = '{red}'
green = '{green}'
yellow = '{peach}'
blue = '{blue}'
magenta = '{dot5}'
cyan = '{dot6}'
white = '{text_muted}'
"""
            # noctalia.toml is imported by default in alacritty.toml
            (themes_dir / "noctalia.toml").write_text(alacritty_content)
            (themes_dir / "quickisland.toml").write_text(alacritty_content)
        except Exception as e:
            print(f"Error updating Alacritty: {e}")

    # ---------------------------------------------------------
    # 3. Hyprland Window Borders & Shadows
    # ---------------------------------------------------------
    clean_accent = accent.lstrip("#")
    clean_surface = surface_alt.lstrip("#")
    clean_surface_bright = surface_bright.lstrip("#")
    try:
        # Live reload via hyprctl
        subprocess.run([
            "hyprctl", "keyword", "general:col.active_border", f"rgb({clean_accent})"
        ], stderr=subprocess.DEVNULL)
        subprocess.run([
            "hyprctl", "keyword", "general:col.inactive_border", f"rgb({clean_surface_bright})"
        ], stderr=subprocess.DEVNULL)
        subprocess.run([
            "hyprctl", "keyword", "group:col.border_active", f"rgba({clean_accent}ff)"
        ], stderr=subprocess.DEVNULL)
        subprocess.run([
            "hyprctl", "keyword", "group:col.border_inactive", f"rgba({clean_surface_bright}cc)"
        ], stderr=subprocess.DEVNULL)

        # Persistent config files
        hypr_conf_candidates = [
            home / ".config/profiles/noctalia/hypr/themes/theme.conf",
            home / ".config/hypr/themes/theme.conf"
        ]
        for h_conf in hypr_conf_candidates:
            if h_conf.exists() and not h_conf.is_symlink():
                txt = h_conf.read_text()
                txt = re.sub(r'col\.active_border\s*=\s*[^\n]+', f'col.active_border = rgba({clean_accent}ff) 45deg', txt)
                txt = re.sub(r'col\.inactive_border\s*=\s*[^\n]+', f'col.inactive_border = rgba({clean_surface_bright}cc) 45deg', txt)
                h_conf.write_text(txt)
    except Exception as e:
        print(f"Error updating Hyprland: {e}")

    # ---------------------------------------------------------
    # 4. GTK 2, 3 & 4 / Libadwaita & Wallbash-Gtk
    # ---------------------------------------------------------
    name_clean = name.lower().strip()
    matched_gtk_theme = "Wallbash-Gtk"

    if "catppuccin latte" in name_clean:
        matched_gtk_theme = "Catppuccin-Latte"
    elif "catppuccin" in name_clean or "mocha" in name_clean:
        matched_gtk_theme = "Catppuccin-Mocha"
    elif "tokyo" in name_clean:
        matched_gtk_theme = "Tokyo-Night"
    elif "gruvbox" in name_clean:
        matched_gtk_theme = "Gruvbox-Retro"
    elif "nord" in name_clean:
        matched_gtk_theme = "Nordic-Blue"
    elif "rose" in name_clean or "rosé" in name_clean:
        matched_gtk_theme = "Rose-Pine"
    elif "synth" in name_clean:
        matched_gtk_theme = "Synth-Wave"
    elif "ariadne" in name_clean or "decay" in name_clean:
        matched_gtk_theme = "Decay-Green"
    elif "cyberpunk" in name_clean or "edge" in name_clean or "runner" in name_clean:
        matched_gtk_theme = "Edge-Runner"
    elif "anime" in name_clean or "sakura" in name_clean or "material" in name_clean:
        matched_gtk_theme = "Material-Sakura"
    elif "frosted" in name_clean or "glass" in name_clean:
        matched_gtk_theme = "Frosted-Glass"
    elif any(k in name_clean for k in ["graphite", "mono", "monokai", "github", "ashes"]):
        matched_gtk_theme = "Graphite-Mono"
    else:
        # All wallpaper themes ("wp ...", "Wallpaper ...") and custom palettes
        # use Wallbash-Gtk which dynamically adapts to the exact palette colors
        matched_gtk_theme = "Wallbash-Gtk"

    # Helper to calculate high-contrast foreground (light or dark)
    def get_contrast_fg(hex_code, fallback_dark="#11111b", fallback_light="#ffffff"):
        try:
            h_clean = hex_code.lstrip('#')
            r_val, g_val, b_val = int(h_clean[0:2], 16), int(h_clean[2:4], 16), int(h_clean[4:6], 16)
            lum = (0.299 * r_val + 0.587 * g_val + 0.114 * b_val) / 255.0
            return fallback_dark if lum > 0.55 else fallback_light
        except Exception:
            return fallback_light

    accent_fg = get_contrast_fg(accent, fallback_dark=surface, fallback_light=text_primary)
    red_fg = get_contrast_fg(red, fallback_dark=surface, fallback_light="#ffffff")
    peach_fg = get_contrast_fg(peach, fallback_dark=surface, fallback_light="#ffffff")
    green_fg = get_contrast_fg(green, fallback_dark=surface, fallback_light="#ffffff")

    # Match best icon theme from installed icons to coordinate with theme
    installed_icons = []
    for icon_dir in [home / ".local/share/icons", Path("/usr/share/icons")]:
        if icon_dir.exists():
            for p in icon_dir.iterdir():
                if p.is_dir():
                    installed_icons.append(p.name)

    matched_icon_theme = "Tela-circle-dracula"
    if "gruvbox" in name_clean:
        matched_icon_theme = "Gruvbox-Plus-Dark" if "Gruvbox-Plus-Dark" in installed_icons else "Tela-circle-yellow"
    elif "nord" in name_clean:
        matched_icon_theme = "Nordzy" if "Nordzy" in installed_icons else "Tela-circle-blue"
    elif "dracula" in name_clean:
        matched_icon_theme = "Tela-circle-dracula"
    elif any(k in name_clean for k in ["sakura", "pink", "rose"]):
        matched_icon_theme = "Tela-circle-pink"
    elif any(k in name_clean for k in ["tokyo", "blue", "ocean"]):
        matched_icon_theme = "Tela-circle-blue"
    elif any(k in name_clean for k in ["decay", "green", "mint", "teal"]):
        matched_icon_theme = "Tela-circle-green"
    elif any(k in name_clean for k in ["catppuccin", "mocha", "purple"]):
        matched_icon_theme = "Tela-circle-purple"
    else:
        # Match dominant hue of accent color
        try:
            h_str = accent.lstrip('#')
            r_c = int(h_str[0:2], 16) / 255.0
            g_c = int(h_str[2:4], 16) / 255.0
            b_c = int(h_str[4:6], 16) / 255.0
            import colorsys
            h, s, v = colorsys.rgb_to_hsv(r_c, g_c, b_c)
            hue_deg = h * 360.0
            if s < 0.15:
                matched_icon_theme = "Tela-circle-grey"
            elif 60 <= hue_deg < 175:
                matched_icon_theme = "Tela-circle-green"
            elif 175 <= hue_deg < 255:
                matched_icon_theme = "Tela-circle-blue"
            elif 255 <= hue_deg < 320:
                matched_icon_theme = "Tela-circle-dracula"
            elif 320 <= hue_deg < 360 or hue_deg < 20:
                matched_icon_theme = "Tela-circle-pink"
            else:
                matched_icon_theme = "Tela-circle-yellow"
        except Exception:
            matched_icon_theme = "Tela-circle-dracula"

    if matched_icon_theme not in installed_icons:
        for fb in ["Tela-circle-dracula", "Tela-circle-blue", "breeze-dark", "Adwaita"]:
            if fb in installed_icons:
                matched_icon_theme = fb
                break

    # Set gsettings with live-reload toggle
    try:
        current_gtk = ""
        try:
            current_gtk = subprocess.check_output(
                ["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"],
                text=True, stderr=subprocess.DEVNULL
            ).strip().strip("'")
        except Exception:
            pass

        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"], stderr=subprocess.DEVNULL)
        
        # If theme name is identical, toggle briefly to trigger GSettings change signal for running apps
        if current_gtk == matched_gtk_theme:
            temp_theme = "Adwaita" if matched_gtk_theme != "Adwaita" else "Default"
            subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", temp_theme], stderr=subprocess.DEVNULL)
        
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", matched_gtk_theme], stderr=subprocess.DEVNULL)
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", matched_icon_theme], stderr=subprocess.DEVNULL)

        # Clear any hardcoded GTK_THEME environment variables from active Hyprland & systemd sessions
        try:
            subprocess.run(["hyprctl", "keyword", "env", "GTK_THEME,"], stderr=subprocess.DEVNULL)
            subprocess.run(["systemctl", "--user", "unset-environment", "GTK_THEME"], stderr=subprocess.DEVNULL)
        except Exception:
            pass
    except Exception as e:
        print(f"Error setting gsettings: {e}")

    # Write GTK 3 & 4 settings.ini
    for ini_path in [
        home / ".config/gtk-3.0/settings.ini",
        home / ".config/gtk-4.0/settings.ini",
        home / ".config/profiles/noctalia/gtk-3.0/settings.ini"
    ]:
        if ini_path.exists():
            try:
                content = ini_path.read_text()
                if "gtk-theme-name=" in content:
                    content = re.sub(r'gtk-theme-name=.*', f'gtk-theme-name={matched_gtk_theme}', content)
                else:
                    content = content + f"\ngtk-theme-name={matched_gtk_theme}\n"
                if "gtk-icon-theme-name=" in content:
                    content = re.sub(r'gtk-icon-theme-name=.*', f'gtk-icon-theme-name={matched_icon_theme}', content)
                else:
                    content = content + f"\ngtk-icon-theme-name={matched_icon_theme}\n"
                if "gtk-font-name=" in content and "Masaram" in content:
                    content = re.sub(r'gtk-font-name=.*', 'gtk-font-name=Noto Sans 10', content)
                ini_path.write_text(content)
            except Exception as e:
                print(f"Error updating {ini_path}: {e}")

    # Update GTK 2 (~/.gtkrc-2.0)
    gtk2_file = home / ".gtkrc-2.0"
    if gtk2_file.exists():
        try:
            g2 = gtk2_file.read_text()
            if "gtk-theme-name=" in g2:
                g2 = re.sub(r'gtk-theme-name\s*=\s*"[^"]*"', f'gtk-theme-name="{matched_gtk_theme}"', g2)
            if "gtk-icon-theme-name=" in g2:
                g2 = re.sub(r'gtk-icon-theme-name\s*=\s*"[^"]*"', f'gtk-icon-theme-name="{matched_icon_theme}"', g2)
            gtk2_file.write_text(g2)
        except Exception as e:
            print(f"Error updating gtkrc-2.0: {e}")

    # Update xsettingsd
    xsettingsd_file = home / ".config/xsettingsd/xsettingsd.conf"
    if xsettingsd_file.exists():
        try:
            xc = xsettingsd_file.read_text()
            if "Net/ThemeName" in xc:
                xc = re.sub(r'Net/ThemeName\s+"[^"]*"', f'Net/ThemeName "{matched_gtk_theme}"', xc)
            if "Net/IconThemeName" in xc:
                xc = re.sub(r'Net/IconThemeName\s+"[^"]*"', f'Net/IconThemeName "{matched_icon_theme}"', xc)
            else:
                xc = xc + f'\nNet/IconThemeName "{matched_icon_theme}"\n'
            xsettingsd_file.write_text(xc)
            subprocess.run(["killall", "-HUP", "xsettingsd"], stderr=subprocess.DEVNULL)
        except Exception as e:
            print(f"Error updating xsettingsd: {e}")

    # Update Wallbash-Gtk theme color definitions directly
    wallbash_dir = home / ".local/share/themes/Wallbash-Gtk"
    if wallbash_dir.exists():
        try:
            for wb_css_file in [wallbash_dir / "gtk-3.0/gtk.css", wallbash_dir / "gtk-3.0/gtk-dark.css"]:
                if wb_css_file.exists():
                    txt = wb_css_file.read_text()
                    txt = re.sub(r'@define-color theme_fg_color\s+[^;]+;', f'@define-color theme_fg_color {text_primary};', txt)
                    txt = re.sub(r'@define-color theme_text_color\s+[^;]+;', f'@define-color theme_text_color {text_primary};', txt)
                    txt = re.sub(r'@define-color theme_bg_color\s+[^;]+;', f'@define-color theme_bg_color {surface};', txt)
                    txt = re.sub(r'@define-color theme_base_color\s+[^;]+;', f'@define-color theme_base_color {surface};', txt)
                    txt = re.sub(r'@define-color theme_selected_bg_color\s+[^;]+;', f'@define-color theme_selected_bg_color {accent};', txt)
                    txt = re.sub(r'@define-color theme_selected_fg_color\s+[^;]+;', f'@define-color theme_selected_fg_color {accent_fg};', txt)
                    txt = re.sub(r'@define-color theme_unfocused_fg_color\s+[^;]+;', f'@define-color theme_unfocused_fg_color {text_secondary};', txt)
                    txt = re.sub(r'@define-color theme_unfocused_text_color\s+[^;]+;', f'@define-color theme_unfocused_text_color {text_secondary};', txt)
                    txt = re.sub(r'@define-color theme_unfocused_bg_color\s+[^;]+;', f'@define-color theme_unfocused_bg_color {surface};', txt)
                    txt = re.sub(r'@define-color theme_unfocused_base_color\s+[^;]+;', f'@define-color theme_unfocused_base_color {surface};', txt)
                    txt = re.sub(r'@define-color theme_unfocused_selected_bg_color\s+[^;]+;', f'@define-color theme_unfocused_selected_bg_color {accent};', txt)
                    txt = re.sub(r'@define-color theme_unfocused_selected_fg_color\s+[^;]+;', f'@define-color theme_unfocused_selected_fg_color {accent_fg};', txt)
                    txt = re.sub(r'@define-color borders\s+[^;]+;', f'@define-color borders {surface_bright};', txt)
                    txt = re.sub(r'@define-color warning_color\s+[^;]+;', f'@define-color warning_color {peach};', txt)
                    txt = re.sub(r'@define-color error_color\s+[^;]+;', f'@define-color error_color {red};', txt)
                    txt = re.sub(r'@define-color success_color\s+[^;]+;', f'@define-color success_color {green};', txt)
                    wb_css_file.write_text(txt)
        except Exception as e:
            print(f"Error updating Wallbash-Gtk internal CSS: {e}")

    # Write GTK 3 CSS (GTK 3 only supports @define-color)
    gtk3_css_content = f"""/* QuickIsland Live Theme (GTK 3): {name} */

/* --- GTK 3 Named Colors --- */
@define-color theme_bg_color {surface};
@define-color theme_fg_color {text_primary};
@define-color theme_base_color {surface};
@define-color theme_text_color {text_primary};
@define-color theme_selected_bg_color {accent};
@define-color theme_selected_fg_color {accent_fg};
@define-color theme_unfocused_bg_color {surface};
@define-color theme_unfocused_fg_color {text_secondary};
@define-color theme_unfocused_base_color {surface};
@define-color theme_unfocused_text_color {text_secondary};
@define-color theme_unfocused_selected_bg_color {accent};
@define-color theme_unfocused_selected_fg_color {accent_fg};
@define-color borders {surface_bright};
@define-color unfocused_borders {surface_alt};
@define-color insensitive_bg_color {surface};
@define-color insensitive_fg_color {text_muted};
@define-color insensitive_base_color {surface_alt};
@define-color warning_color {peach};
@define-color error_color {red};
@define-color success_color {green};
@define-color content_view_bg {surface};
@define-color text_view_bg {surface_alt};
"""
    for css_target in [
        home / ".config/gtk-3.0/gtk.css",
        home / ".config/gtk-3.0/gtk-dark.css",
        home / ".config/profiles/noctalia/gtk-3.0/gtk.css",
        home / ".config/profiles/noctalia/gtk-3.0/gtk-dark.css"
    ]:
        try:
            css_target.parent.mkdir(parents=True, exist_ok=True)
            css_target.write_text(gtk3_css_content)
        except Exception as e:
            print(f"Error writing GTK 3 CSS to {css_target}: {e}")

    # Write GTK 4 / Libadwaita CSS (supports @media queries and :root CSS variables)
    gtk4_css_content = f"""/* QuickIsland Live Theme (GTK 4 / Libadwaita): {name} */

/* --- Libadwaita / GTK 4 Named Colors --- */
@define-color accent_color {accent};
@define-color accent_bg_color {accent};
@define-color accent_fg_color {accent_fg};

@define-color destructive_bg_color {red};
@define-color destructive_fg_color {red_fg};
@define-color error_bg_color {red};
@define-color error_fg_color {red_fg};

@define-color window_bg_color {surface};
@define-color window_fg_color {text_primary};
@define-color view_bg_color {surface};
@define-color view_fg_color {text_primary};
@define-color headerbar_bg_color {surface_alt};
@define-color headerbar_fg_color {text_primary};
@define-color headerbar_backdrop_color @window_bg_color;
@define-color card_bg_color {surface_alt};
@define-color card_fg_color {text_primary};
@define-color popover_bg_color {surface_alt};
@define-color popover_fg_color {text_primary};
@define-color dialog_bg_color {surface};
@define-color dialog_fg_color {text_primary};

@define-color sidebar_bg_color {surface_alt};
@define-color sidebar_fg_color {text_primary};
@define-color sidebar_backdrop_color @window_bg_color;
@define-color sidebar_border_color @window_bg_color;

@define-color secondary_sidebar_bg_color {surface};
@define-color secondary_sidebar_fg_color {text_primary};

@define-color warning_bg_color {peach};
@define-color warning_fg_color {peach_fg};
@define-color success_bg_color {green};
@define-color success_fg_color {green_fg};

/* Override Libadwaita dark mode media query so dark mode honors the theme palette */
@media (prefers-color-scheme: dark) {{
    @define-color window_bg_color {surface};
    @define-color window_fg_color {text_primary};
    @define-color view_bg_color {surface};
    @define-color view_fg_color {text_primary};
    @define-color headerbar_bg_color {surface_alt};
    @define-color headerbar_fg_color {text_primary};
    @define-color headerbar_backdrop_color @window_bg_color;
    @define-color card_bg_color {surface_alt};
    @define-color card_fg_color {text_primary};
    @define-color popover_bg_color {surface_alt};
    @define-color popover_fg_color {text_primary};
    @define-color dialog_bg_color {surface};
    @define-color dialog_fg_color {text_primary};
    @define-color sidebar_bg_color {surface_alt};
    @define-color sidebar_fg_color {text_primary};
    @define-color sidebar_backdrop_color @window_bg_color;
    @define-color sidebar_border_color @window_bg_color;
    @define-color secondary_sidebar_bg_color {surface};
    @define-color secondary_sidebar_fg_color {text_primary};

    :root {{
        --window-bg-color: {surface};
        --window-fg-color: {text_primary};
        --view-bg-color: {surface};
        --view-fg-color: {text_primary};
        --headerbar-bg-color: {surface_alt};
        --headerbar-fg-color: {text_primary};
        --sidebar-bg-color: {surface_alt};
        --sidebar-fg-color: {text_primary};
        --card-bg-color: {surface_alt};
        --card-fg-color: {text_primary};
        --dialog-bg-color: {surface};
        --dialog-fg-color: {text_primary};
        --popover-bg-color: {surface_alt};
        --popover-fg-color: {text_primary};
    }}
}}

/* --- Libadwaita CSS Variables --- */
:root {{
    --accent-color: {accent};
    --accent-bg-color: {accent};
    --accent-fg-color: {accent_fg};

    --destructive-bg-color: {red};
    --destructive-fg-color: {red_fg};
    --error-bg-color: {red};
    --error-fg-color: {red_fg};

    --window-bg-color: {surface};
    --window-fg-color: {text_primary};

    --view-bg-color: {surface};
    --view-fg-color: {text_primary};

    --headerbar-bg-color: {surface_alt};
    --headerbar-fg-color: {text_primary};
    --headerbar-backdrop-color: @window_bg_color;

    --popover-bg-color: {surface_alt};
    --popover-fg-color: {text_primary};

    --card-bg-color: {surface_alt};
    --card-fg-color: {text_primary};

    --dialog-bg-color: {surface};
    --dialog-fg-color: {text_primary};

    --sidebar-bg-color: {surface_alt};
    --sidebar-fg-color: {text_primary};
    --sidebar-backdrop-color: @window_bg_color;
    --sidebar-border-color: @window_bg_color;

    --warning-bg-color: {peach};
    --warning-fg-color: {peach_fg};
    --success-bg-color: {green};
    --success-fg-color: {green_fg};
}}
"""
    for css_target in [
        home / ".config/gtk-4.0/gtk.css",
        home / ".config/gtk-4.0/gtk-dark.css",
        home / ".local/share/themes/Wallbash-Gtk/gtk-4.0/gtk.css",
        home / ".local/share/themes/Wallbash-Gtk/gtk-4.0/gtk-dark.css"
    ]:
        try:
            css_target.parent.mkdir(parents=True, exist_ok=True)
            css_target.write_text(gtk4_css_content)
        except Exception as e:
            print(f"Error writing GTK 4 CSS to {css_target}: {e}")

    # ---------------------------------------------------------
    # 5. Rofi Application Launcher
    # ---------------------------------------------------------
    rofi_theme_candidates = [
        home / ".config/profiles/noctalia/rofi/theme.rasi",
        home / ".config/rofi/theme.rasi"
    ]
    accent_lum = get_luminance(accent)
    select_fg = surface if accent_lum > 0.45 else "#ffffff"
    clean_surface_hex = surface.lstrip("#")
    clean_text_hex = text_primary.lstrip("#")
    clean_bright_hex = surface_bright.lstrip("#")
    clean_alt_hex = surface_alt.lstrip("#")
    clean_accent_hex = accent.lstrip("#")
    clean_select_fg = select_fg.lstrip("#")

    rofi_content = f"""* {{
    main-bg:            #{clean_surface_hex}CC;
    main-fg:            #{clean_text_hex}E6;
    main-br:            #{clean_bright_hex}E6;
    main-ex:            #{clean_alt_hex}E6;
    select-bg:          #{clean_accent_hex}CC;
    select-fg:          #{clean_select_fg}FF;
}}
"""
    for r_file in rofi_theme_candidates:
        if r_file.exists():
            try:
                # If it's a symlink, resolve real target to write safely
                real_target = r_file.resolve()
                real_target.write_text(rofi_content)
            except Exception as e:
                print(f"Error writing Rofi theme at {r_file}: {e}")

    # ---------------------------------------------------------
    # 6. Btop Resource Monitor
    # ---------------------------------------------------------
    btop_dir = home / ".config/btop"
    if btop_dir.exists():
        try:
            btop_themes = btop_dir / "themes"
            btop_themes.mkdir(parents=True, exist_ok=True)
            btop_theme_file = btop_themes / "quickisland.theme"
            btop_theme_content = f"""# QuickIsland Live Theme: {name}
theme[main_bg]="{surface}"
theme[main_fg]="{text_primary}"
theme[title]="{accent}"
theme[hi_fg]="{accent}"
theme[selected_bg]="{surface_bright}"
theme[selected_fg]="{accent}"
theme[inactive_fg]="{text_muted}"
theme[graph_text]="{text_secondary}"
theme[proc_misc]="{accent}"
theme[cpu_box]="{surface_bright}"
theme[mem_box]="{surface_bright}"
theme[net_box]="{surface_bright}"
theme[proc_box]="{surface_bright}"
theme[div_line]="{surface_bright}"

theme[temp_start]="{blue}"
theme[temp_mid]="{peach}"
theme[temp_end]="{red}"

theme[cpu_start]="{blue}"
theme[cpu_mid]="{accent}"
theme[cpu_end]="{red}"

theme[free_start]="{green}"
theme[free_mid]="{blue}"
theme[free_end]="{accent}"

theme[cached_start]="{blue}"
theme[cached_mid]="{accent}"
theme[cached_end]="{red}"

theme[available_start]="{green}"
theme[available_mid]="{peach}"
theme[available_end]="{red}"

theme[used_start]="{red}"
theme[used_mid]="{peach}"
theme[used_end]="{accent}"

theme[download_start]="{blue}"
theme[download_mid]="{accent}"
theme[download_end]="{green}"

theme[upload_start]="{blue}"
theme[upload_mid]="{accent}"
theme[upload_end]="{peach}"

theme[process_start]="{blue}"
theme[process_mid]="{accent}"
theme[process_end]="{red}"
"""
            btop_theme_file.write_text(btop_theme_content)

            # Ensure color_theme in btop.conf is set to quickisland
            btop_conf = btop_dir / "btop.conf"
            if btop_conf.exists():
                c = btop_conf.read_text()
                if 'color_theme = "quickisland"' not in c:
                    c = re.sub(r'color_theme\s*=\s*"[^"]*"', 'color_theme = "quickisland"', c)
                    btop_conf.write_text(c)
        except Exception as e:
            print(f"Error updating Btop: {e}")

    # ---------------------------------------------------------
    # 7. Waybar & wlogout Theme Styling
    # ---------------------------------------------------------
    try:
        sr, sg, sb = hex_to_rgb(surface)
        ar, ag, ab = hex_to_rgb(accent)
        sbr_r, sbr_g, sbr_b = hex_to_rgb(surface_bright)
        waybar_css = f"""/* QuickIsland Live Waybar & wlogout Theme: {name} */
@define-color bar-bg rgba({sr}, {sg}, {sb}, 0.65);
@define-color main-bg rgba({sr}, {sg}, {sb}, 0.85);
@define-color main-fg {text_primary};
@define-color wb-act-bg rgba({ar}, {ag}, {ab}, 0.45);
@define-color wb-act-fg {text_primary};
@define-color wb-hvr-bg rgba({sbr_r}, {sbr_g}, {sbr_b}, 0.55);
@define-color wb-hvr-fg {accent};
"""
        waybar_candidates = [
            home / ".config/profiles/noctalia/waybar/theme.css",
            home / ".config/waybar/theme.css"
        ]
        for wb_file in waybar_candidates:
            wb_file.parent.mkdir(parents=True, exist_ok=True)
            wb_file.write_text(waybar_css)
    except Exception as e:
        print(f"Error updating Waybar/wlogout: {e}")

    # ---------------------------------------------------------
    # 8. Dunst Notifications
    # ---------------------------------------------------------
    dunst_conf = home / ".config/dunst/dunstrc"
    if dunst_conf.exists():
        try:
            d_content = dunst_conf.read_text()
            # Update urgency_low, urgency_normal, urgency_critical frame and background
            d_content = re.sub(r'(\[urgency_low\][^\[]*?frame_color\s*=\s*")[^"]*(")', rf'\g<1>{surface_bright}\g<2>', d_content)
            d_content = re.sub(r'(\[urgency_normal\][^\[]*?frame_color\s*=\s*")[^"]*(")', rf'\g<1>{accent}\g<2>', d_content)
            d_content = re.sub(r'(\[urgency_critical\][^\[]*?frame_color\s*=\s*")[^"]*(")', rf'\g<1>{red}\g<2>', d_content)
            dunst_conf.write_text(d_content)
            subprocess.run(["killall", "-SIGUSR2", "dunst"], stderr=subprocess.DEVNULL)
        except Exception as e:
            print(f"Error updating Dunst: {e}")

    # ---------------------------------------------------------
    # 9. Pywal Cache
    # ---------------------------------------------------------
    pywal_file = home / ".cache/wal/colors.json"
    try:
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
        pywal_file.write_text(json.dumps(pywal_json, indent=2))
    except Exception as e:
        print(f"Error writing Pywal cache: {e}")

    # ---------------------------------------------------------
    # 10. VS Code — accent-tinted dark backgrounds only
    #     We blend near-black (#0d0d0d) with the accent at a
    #     low factor so the workspace feels dark but tinted,
    #     like a black+accent mix.  Syntax / token colors are
    #     NEVER touched — VS Code's own theme handles those.
    # ---------------------------------------------------------
    BLACK = "#0d0d0d"
    # Main editor area — 8% accent in deep black
    vsc_editor_bg   = blend(BLACK, accent, 0.08)
    # Sidebar slightly lighter — 10% accent
    vsc_sidebar_bg  = blend(BLACK, accent, 0.10)
    # Tab bar / title area — between the two
    vsc_tabs_bg     = blend(BLACK, accent, 0.09)
    # Active tab slightly brighter
    vsc_tab_active  = blend(BLACK, accent, 0.13)
    # Inactive tab, indistinguishable from tabs bar
    vsc_tab_inactive = vsc_tabs_bg
    # Editor group empty state
    vsc_group_bg    = vsc_editor_bg
    # Input / dropdown backgrounds
    vsc_input_bg    = blend(BLACK, accent, 0.12)
    # List hover  
    vsc_list_hover  = blend(BLACK, accent, 0.18)
    # Scrollbar track
    vsc_scroll      = blend(BLACK, accent, 0.06)
    # Panel (terminal) area
    vsc_panel_bg    = blend(BLACK, accent, 0.07)
    # Borders / separators — very subtle accent tint
    vsc_border      = blend(BLACK, accent, 0.20)
    # Cursor / active line
    vsc_cursor      = accent

    vsc_colors = {
        # Core backgrounds
        "editor.background":                         vsc_editor_bg,
        "sideBar.background":                        vsc_sidebar_bg,
        "sideBarSectionHeader.background":           vsc_sidebar_bg,
        "activityBar.background":                    vsc_sidebar_bg,
        "editorGroupHeader.tabsBackground":          vsc_tabs_bg,
        "editorGroupHeader.noTabsBackground":        vsc_tabs_bg,
        "tab.activeBackground":                      vsc_tab_active,
        "tab.inactiveBackground":                    vsc_tab_inactive,
        "tab.unfocusedActiveBackground":             vsc_tab_active,
        # Filename accent — active tab text uses the accent color
        "tab.activeForeground":                      accent,
        "tab.unfocusedActiveForeground":             blend(accent, text_secondary, 0.4),
        "editorGroup.emptyBackground":               vsc_group_bg,
        "panel.background":                          vsc_panel_bg,
        "panelSectionHeader.background":             vsc_panel_bg,
        "terminal.background":                       vsc_panel_bg,
        "breadcrumb.background":                     vsc_editor_bg,
        "input.background":                          vsc_input_bg,
        "dropdown.background":                       vsc_input_bg,
        "quickInput.background":                     vsc_sidebar_bg,
        "quickInputList.focusBackground":            vsc_list_hover,
        # Borders — all transparent to remove separator lines
        "sideBar.border":                            "#00000000",
        "tab.border":                                "#00000000",
        "tab.activeBorder":                          "#00000000",
        "tab.activeBorderTop":                       "#00000000",
        "tab.unfocusedActiveBorder":                 "#00000000",
        "tab.unfocusedActiveBorderTop":              "#00000000",
        "editorGroupHeader.border":                  "#00000000",
        "editorGroup.border":                        "#00000000",
        "panel.border":                              "#00000000",
        # List hover
        "list.hoverBackground":                      vsc_list_hover,
        "list.focusBackground":                      vsc_list_hover,
        # Scrollbars
        "scrollbarSlider.background":                vsc_scroll + "44",
        "scrollbarSlider.hoverBackground":           vsc_scroll + "66",
        "scrollbarSlider.activeBackground":          vsc_scroll + "88",
        # Cursor color (accent)
        "editorCursor.foreground":                   vsc_cursor,
        # Keep overview ruler transparent (user preference)
        "editor.lineHighlightBackground":            "#00000000",
        "editor.lineHighlightBorder":                "#00000000",
        "editorOverviewRuler.errorForeground":       "#00000000",
        "editorOverviewRuler.warningForeground":     "#00000000",
        "editorOverviewRuler.infoForeground":        "#00000000",
        "editorOverviewRuler.modifiedForeground":    "#00000000",
        "editorOverviewRuler.addedForeground":       "#00000000",
        "editorOverviewRuler.deletedForeground":     "#00000000",
        "editorOverviewRuler.selectionHighlightForeground": "#00000000",
        "editorOverviewRuler.findMatchForeground":   "#00000000",
        "editorOverviewRuler.rangeHighlightForeground": "#00000000",
        "editorOverviewRuler.wordHighlightForeground": "#00000000",
        "editorOverviewRuler.wordHighlightStrongForeground": "#00000000",
        "editorOverviewRuler.currentContentForeground": "#00000000",
        "editorOverviewRuler.cursorForeground":      "#00000000",
        "editorOverviewRuler.bracketMatchForeground": "#00000000",
        "editorOverviewRuler.border":                "#00000000",
    }

    for settings_path in [
        home / ".config/Code/User/settings.json",
        home / ".config/Code - OSS/User/settings.json",
    ]:
        if not settings_path.exists():
            continue
        try:
            with open(settings_path, "r") as f:
                vsc_settings = json.load(f)
            vsc_settings["workbench.colorCustomizations"] = vsc_colors
            # Hide path beside filename natively (no CSS needed)
            vsc_settings["workbench.editor.labelFormat"] = "short"
            with open(settings_path, "w") as f:
                json.dump(vsc_settings, f, indent=2)
        except Exception as e:
            print(f"Error updating VS Code settings at {settings_path}: {e}")

    print(f"Successfully applied system-wide theme: {name}")

if __name__ == "__main__":
    main()
