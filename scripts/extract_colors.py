#!/usr/bin/env python3
"""Extract a dark-mode color palette from a wallpaper using ImageMagick."""
import json, subprocess, sys, colorsys

def rgb_to_hsl(r, g, b):
    h, l, s = colorsys.rgb_to_hls(r/255, g/255, b/255)
    return h*360, s*100, l*100

def hsl_to_hex(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h/360, l/100, s/100)
    return "#{:02x}{:02x}{:02x}".format(int(r*255), int(g*255), int(b*255))

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def get_dominant_colors(image_path, count=8):
    """Use ImageMagick to extract dominant colors."""
    result = subprocess.run([
        "magick", image_path,
        "-resize", "100x100!",
        "-colors", str(count),
        "-unique-colors",
        "-format", "%c",
        "histogram:info:-"
    ], capture_output=True, text=True, timeout=15)

    colors = []
    for line in result.stdout.strip().split('\n'):
        line = line.strip()
        if not line:
            continue
        # Parse: "  12345: (R,G,B,...) #HEXHEX srgb(...)"
        try:
            count_part = line.split(':')[0].strip()
            pixel_count = int(count_part)
            hex_start = line.index('#')
            hex_color = line[hex_start:hex_start+7]
            r, g, b = hex_to_rgb(hex_color)
            h, s, l = rgb_to_hsl(r, g, b)
            colors.append({
                'hex': hex_color, 'count': pixel_count,
                'h': h, 's': s, 'l': l, 'r': r, 'g': g, 'b': b
            })
        except (ValueError, IndexError):
            continue

    return colors

def pick_accent(colors):
    """Pick the most vibrant, saturated color as accent."""
    scored = []
    for c in colors:
        # Prefer saturated, medium-lightness colors
        sat_score = c['s']
        light_penalty = abs(c['l'] - 55) * 0.8  # prefer ~55% lightness
        score = sat_score * 2 - light_penalty + (c['count'] * 0.001)
        scored.append((score, c))
    scored.sort(key=lambda x: x[0], reverse=True)
    return scored[0][1] if scored else colors[0]

def generate_palette(image_path):
    """Generate a full dark-mode palette from a wallpaper."""
    colors = get_dominant_colors(image_path, 8)
    if not colors:
        # Fallback to Catppuccin Mocha
        return {
            "accent": "#cba6f7", "surface": "#11111b",
            "surfaceAlt": "#1e1e2e", "surfaceBright": "#313244",
            "textPrimary": "#cdd6f4", "textSecondary": "#a6adc8",
            "textMuted": "#6c7086", "red": "#f38ba8",
            "green": "#a6e3a1", "peach": "#fab387", "blue": "#89b4fa"
        }

    accent_color = pick_accent(colors)
    ah, as_, al = accent_color['h'], accent_color['s'], accent_color['l']

    # Generate accent: bump saturation and set lightness for dark mode visibility
    accent = hsl_to_hex(ah, min(as_ * 1.2, 90), max(min(al, 75), 60))
    accent_dim = accent  # will use Qt.rgba in QML

    # Surface colors: use accent hue but very dark and desaturated
    surface      = hsl_to_hex(ah, min(as_ * 0.15, 12), 6)
    surface_alt  = hsl_to_hex(ah, min(as_ * 0.15, 12), 10)
    surface_bright = hsl_to_hex(ah, min(as_ * 0.12, 10), 18)

    # Text colors: tinted toward accent hue
    text_primary   = hsl_to_hex(ah, min(as_ * 0.2, 18), 88)
    text_secondary = hsl_to_hex(ah, min(as_ * 0.18, 15), 72)
    text_muted     = hsl_to_hex(ah, min(as_ * 0.12, 10), 46)

    # Semantic colors: shift hue from accent
    red   = hsl_to_hex((ah + 340) % 360, 75, 68)
    green = hsl_to_hex((ah + 140) % 360, 65, 68)
    peach = hsl_to_hex((ah + 30) % 360, 80, 72)
    blue  = hsl_to_hex((ah + 210) % 360, 75, 72)

    return {
        "accent": accent, "surface": surface,
        "surfaceAlt": surface_alt, "surfaceBright": surface_bright,
        "textPrimary": text_primary, "textSecondary": text_secondary,
        "textMuted": text_muted, "red": red,
        "green": green, "peach": peach, "blue": blue
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No image path provided"}))
        sys.exit(1)
    try:
        palette = generate_palette(sys.argv[1])
        print(json.dumps(palette))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
