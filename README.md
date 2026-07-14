# Quickisland 🏝️

[![Preview Video](https://img.shields.io/badge/YouTube-Preview-red?style=for-the-badge&logo=youtube)](https://youtu.be/uPwyolLwxvs)

A premium, state-of-the-art Dynamic Island, Control Center, and Desktop Shell for **Hyprland**, built using **Quickshell** (QML/C++). Designed for speed, responsiveness, and minimal resource usage, Quickisland provides macOS-style dynamic island notifications, a comprehensive control center, and utility tools directly integrated into your status bar.

---

## 🎥 Video Preview

Click the badge below or the preview image to watch the unlisted preview of Quickisland on YouTube:

[![Quickisland Preview](https://img.youtube.com/vi/uPwyolLwxvs/maxresdefault.jpg)](https://youtu.be/uPwyolLwxvs)

---

## 🚀 Key Features

* **⚡ Ultra-Lightweight & Low Resources:** 
  * Only uses **about 500 MB** of VRAM/RAM under typical running conditions.
  * Optimized with lazy-loading QML components and strict layer-gating to ensure **near-zero CPU usage** when idle.
* **🌀 Quick and Smooth Transitions:** 
  * Responsive morphing transitions that automatically resize the island based on its active state.
  * Instant, snappy wallpaper transition options.
* **🔊 Volume & Brightness Controls:**
  * Beautiful volume and brightness bar OSD overlays that morph dynamically out of the central island.
* **🔔 Integrated Notification System:**
  * Clean, non-intrusive desktop notification toasts that display inside the island, with support for clearing and history.
* **🎨 Personalization & Palette Generation:**
  * Persistent custom wallpaper management using `awww`.
  * Dynamic, automatic color scheme generation based on your active wallpaper.
  * Custom Palette Designer to fine-tune your accent, surface, and text colors on the fly.
* **🎵 Media Controls:**
  * Full MPRIS-compatible media control card displaying player info, metadata, track navigation, and high-quality album art.
* **🛠️ Screen Toolkit:**
  * A full suite of desktop tools containing:
    * **Annotate:** Draw directly on your screen.
    * **Measure:** Pixel-accurate ruler.
    * **Region Selector:** Screen recorder and region screenshot tool.
    * **Color Picker:** Hex color grabber.
    * **OCR Scanner:** Extract text instantly from a screen region.
    * **QR Helper:** Generate and read QR codes.
* **🖐️ Touchpad & Mouse Gestures:**
  * Complete gesture support: swipe left/right to seamlessly switch between the App Launcher, Control Center, and Session Menu.
  * Vertical scroll pass-through for lists.
* **⚙️ Control Center, Launcher, & Session Hub:**
  * Quick-access buttons for Wi-Fi, Bluetooth, Performance Profiles, Night Light, Dark Mode, and more.

---

## ⌨️ Keyboard Shortcuts

Quickisland integrates globally with your Hyprland configuration. The default keybindings are:

| Shortcut | Action |
|---|---|
| `Super + A` | Toggle Application Launcher |
| `Super + N` | Toggle Control Center |
| `Super + V` | Toggle Clipboard History |
| `Super + .` | Toggle Emoji Board |
| `Super + /` | Toggle Keyboard Shortcuts Help (Island Popup) |
| `Super + L` | Lock Screen |
| `Ctrl + Alt + Delete` | Open Session / Power Menu |
| `Swipe Left / Right` | Switch between CC / Launcher / Power (when open) |

---

## 📦 Easy Installation

Quickisland comes with an automated `install.sh` script to set up all system dependencies, compile plugins, and merge keybindings automatically.

### Installation Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/c1ph3r-1337/Quickisland.git
   cd Quickisland
   ```

2. **Make the installer executable:**
   ```bash
   chmod +x install.sh
   ```

3. **Run the installer:**
   ```bash
   ./install.sh
   ```

The script will:
* Check for package dependencies (`quickshell-git`, `awww`, etc.).
* Build local plugins.
* Prompt to append Quickisland-specific hotkeys to your Hyprland configuration.

---

## 🛠️ Tech Stack & Requirements

* **Framework:** [Quickshell](https://github.com/outfoxxed/quickshell) (Wayland-native QML shell)
* **Compositor:** [Hyprland](https://hyprland.org/)
* **Wallpaper Backend:** `awww`
* **Color Schemes:** Wallbash/Noctalia
