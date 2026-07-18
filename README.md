<div align="center">

# Quickisland

[![Preview](https://img.shields.io/badge/YouTube-Preview-red?style=flat-square&logo=youtube)](https://youtu.be/uPwyolLwxvs)

A premium, Wayland-native desktop shell, status bar, and Dynamic Island for the Hyprland compositor, built on the Quickshell framework.

---

[![Quickisland Preview](https://img.youtube.com/vi/Fv100o7fDag/maxresdefault.jpg)](https://youtu.be/Fv100o7fDag)

---

</div>

## Performance Specs

* **Lightweight Memory Footprint:** Approximately 500 MB of VRAM/RAM under normal workloads.
* **Optimized CPU Utilization:** Proactive visual layer-gating and event-driven timer throttling ensure near-zero idle overhead.
* **Smooth Transitions:** Morphing physics and transition engines tuned for instant visual responses.
* **Hardware Acceleration:** Rendered directly via Qt Quick Scene Graph using hardware graphics APIs.

---

## Major Modules

* **Dynamic Island & Status OSD:** Provides volume and brightness visual feedback overlays that expand out of a central, pill-shaped desktop island. Offers real-time feedback with premium animations.
* **Desktop Notifications:** Wayland-native desktop notifications displayed as animated island expanders. Includes a notification history view, individual notification clearing, and status toggles.
* **Control Center:** Includes status indicators and controls for Wi-Fi networks, Bluetooth devices, active VPN connections, audio inputs/outputs, system performance modes, and night light.
* **Application Launcher:** A clean, grid-based application search and launcher with custom navigation and vertical list scrolling pass-through.
* **Media Controller:** Full MPRIS-compatible dashboard showing metadata, playback controls (play, pause, skip, backward), track duration progress, and album art.
* **Theme Personalization:** Wallpaper management with active color extraction, generating custom accent, surface, and text color palettes based on your wallpaper colors. Features an interactive Color Palette Designer.

---

## Screen Toolkit

* **Annotate:** Draw and write directly on top of active screen displays for notes or presentations.
* **Measure:** A pixel-accurate measurement ruler to evaluate lengths, offsets, and element coordinates.
* **Region Recorder:** Record videos of defined screen regions or capture cropped screenshots.
* **Color Picker:** Select any pixel on the screen and copy its HEX value.
* **OCR Scanner:** Instantly extract text from any selected region of the screen and copy it to the clipboard.
* **QR Helper:** Scan existing QR codes from your screen or quickly generate new ones.

---

## Gestures & Navigation

* **Horizontal Swipes:** Swipe left or right inside the active menu zones to switch between the Control Center, App Launcher, and Power Menu.
* **Vertical Scrolling:** Vertical scrolling automatically passes through to underneath lists (such as notification logs and app grids) while preserving horizontal swipe boundaries.

---

## Keyboard Shortcuts

| Keybinding | Action |
|---|---|
| Super + A | Toggle Application Launcher |
| Super + N | Toggle Control Center |
| Super + V | Toggle Clipboard History |
| Super + . | Toggle Emoji Board |
| Super + / | Toggle Keyboard Shortcuts Help Overlay |
| Super + L | Lock Screen |
| Ctrl + Alt + Delete | Open Session / Power Menu |

---

## File Structure & Standalone Architecture

```
quickisland/
├── shell.qml                # Main shell declaration and UI state management
├── launch.sh                # Launcher daemon script
├── install.sh               # Dependency and install compiler script
├── LiquidGlassBackground.qml# Custom glass effect shader renderer
├── LockScreen.qml           # Lockscreen layout and auth handling
├── qs/                      # Standalone backend service modules
│   ├── Services/            # Core system interfaces (Network, Bluetooth, MPRIS, VPN)
│   ├── Modules/             # UI elements (Control Center, Setup Wizard, Toasts)
│   └── Widgets/             # Modular reusable components
├── Assets/                  # Fonts, default wallpapers, and color themes
└── scripts/                 # Auxiliary helper scripts (color extractors, pickers)
```

---

## Installation

```bash
git clone https://github.com/c1ph3r-1337/Quickisland.git
cd Quickisland
chmod +x install.sh
./install.sh
```

---

## System Requirements

* **Wayland Compositor:** Hyprland
* **Wallpaper Backend:** awww daemon
* **Base Engine:** Quickshell (Wayland QML shell framework)
