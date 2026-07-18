#!/usr/bin/env bash
# ==============================================================================
#  QuickIsland — Standalone Installer
# ==============================================================================
#  Installs all runtime dependencies, sets up the QuickIsland shell profile,
#  configures Hyprland keybindings, and optionally adds itself to autostart.
#
#  Works on:
#    • A fresh Arch Linux install (or Arch-based: CachyOS, EndeavourOS, Manjaro)
#    • An existing running machine
#    • Fedora and Debian/Ubuntu (best-effort)
#
#  Usage:
#    chmod +x install.sh && ./install.sh
# ==============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}  ▸ $*${NC}"; }
success() { echo -e "${GREEN}  ✔ $*${NC}"; }
warn()    { echo -e "${YELLOW}  ⚠ $*${NC}"; }
fail()    { echo -e "${RED}  ✘ $*${NC}"; }
header()  { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BOLD}${CYAN}  $*${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$HOME/.config/quickshell/quickisland"

# ==============================================================================
header "QuickIsland — Standalone Installer"
# ==============================================================================

# ── Step 1: OS Detection ─────────────────────────────────────────────────────
header "Step 1/6 — Detecting System"

OS_NAME=""
OS_PRETTY=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="$ID"
    OS_PRETTY="${PRETTY_NAME:-$ID}"
fi

if [ -z "$OS_NAME" ]; then
    fail "Could not detect your Linux distribution."
    fail "Please install the dependencies manually (listed below)."
fi

info "OS:     ${BOLD}${OS_PRETTY}${NC}"
info "Kernel: ${BOLD}$(uname -r)${NC}"
info "Arch:   ${BOLD}$(uname -m)${NC}"

# Check if Hyprland is the compositor
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || pgrep -x Hyprland &>/dev/null; then
    success "Hyprland compositor detected"
else
    warn "Hyprland not detected. QuickIsland requires Hyprland as its compositor."
    read -rp "  Continue anyway? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || exit 1
fi

# ── Step 2: Install Dependencies ─────────────────────────────────────────────
header "Step 2/6 — Installing Dependencies"

install_arch() {
    # Optimize compilation thread settings to prevent Out-Of-Memory (OOM) compiler crashes
    local total_mem_kb
    total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_gb=$(( total_mem_kb / 1024 / 1024 ))
    local build_jobs=1
    
    if [ "$total_mem_gb" -ge 32 ]; then
        build_jobs=8
    elif [ "$total_mem_gb" -ge 16 ]; then
        build_jobs=4
    elif [ "$total_mem_gb" -ge 10 ]; then
        build_jobs=2
    else
        build_jobs=1
    fi
    
    info "Optimizing build parameters for ${total_mem_gb}GB RAM (Jobs: $build_jobs)"
    export MAKEFLAGS="-j$build_jobs"
    export CARGO_BUILD_JOBS="$build_jobs"

    local pacman_deps=(
        # Core
        brightnessctl
        wl-clipboard
        imagemagick
        networkmanager
        bluez
        bluez-utils
        git
        wget
        curl
        jq
        bc
        xdg-utils

        # Clipboard history
        cliphist

        # Audio spectrum support
        fftw

        # Screen Toolkit dependencies
        grim
        slurp
        hyprpicker
        tesseract
        tesseract-data-eng
        zbar
        ffmpeg
        wtype

        # Folder picker UI
        gtk3
        python-gobject

        # Shell translation
        translate-shell
    )

    info "Installing system packages via pacman..."
    if ! sudo pacman -S --needed --noconfirm "${pacman_deps[@]}"; then
        warn "Package installation failed. This is usually caused by outdated local package databases (dependency conflicts)."
        echo -e "  ${BOLD}Would you like to run a full system upgrade (pacman -Syu) to resolve this?${NC}"
        read -rp "  Run system upgrade? [y/N] " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            info "Running full system upgrade and installing dependencies..."
            sudo pacman -Syu --needed --noconfirm "${pacman_deps[@]}"
        else
            fail "Could not install dependencies. Please resolve package conflicts manually and re-run the installer."
            exit 1
        fi
    fi

    # Detect AUR helper
    local aur_helper=""
    if command -v paru &>/dev/null; then
        aur_helper="paru"
    elif command -v yay &>/dev/null; then
        aur_helper="yay"
    fi

    if [ -z "$aur_helper" ]; then
        warn "No AUR helper found (paru or yay)!"
        echo -e "  ${BOLD}Would you like to automatically install 'yay' to build AUR packages?${NC}"
        read -rp "  Install 'yay'? [Y/n] " install_yay_ans
        install_yay_ans="${install_yay_ans:-Y}"
        if [[ "$install_yay_ans" =~ ^[Yy]$ ]]; then
            info "Installing prerequisites for building packages (base-devel)..."
            sudo pacman -S --needed --noconfirm base-devel git
            
            info "Cloning and building 'yay-bin' from the AUR..."
            rm -rf /tmp/yay-bin
            git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
            (cd /tmp/yay-bin && makepkg -si --noconfirm)
            rm -rf /tmp/yay-bin
            
            if command -v yay &>/dev/null; then
                success "Successfully installed 'yay'"
                aur_helper="yay"
            else
                fail "Failed to install 'yay'."
            fi
        fi
    fi

    if [ -n "$aur_helper" ]; then
        success "Found AUR helper: $aur_helper"

        # Install wl-screenrec if missing
        if ! command -v wl-screenrec &>/dev/null; then
            info "Installing wl-screenrec..."
            if sudo pacman -S --needed --noconfirm wl-screenrec 2>/dev/null; then
                success "Successfully installed pre-compiled wl-screenrec"
            else
                info "Pre-compiled wl-screenrec not found. Building from AUR..."
                $aur_helper -S --noconfirm wl-screenrec 2>/dev/null || warn "Could not install wl-screenrec from AUR."
            fi
        fi

        # Install Quickshell (FFTW/spectrum support)
        if command -v quickshell &>/dev/null; then
            success "Quickshell is already installed"
        else
            info "Attempting to install pre-compiled Quickshell from repositories..."
            if sudo pacman -S --needed --noconfirm quickshell 2>/dev/null || sudo pacman -S --needed --noconfirm noctalia-qs 2>/dev/null; then
                success "Successfully installed pre-compiled Quickshell"
            else
                info "Pre-compiled package not found. Building Quickshell from AUR (this may take some time)..."
                $aur_helper -S --noconfirm noctalia-qs 2>/dev/null \
                    || $aur_helper -S --noconfirm noctalia-qs-git 2>/dev/null \
                    || { fail "Failed to install Quickshell. Install it manually from the AUR."; exit 1; }
            fi
        fi
    else
        warn "No AUR helper available."
        if ! command -v wl-screenrec &>/dev/null; then
            warn "wl-screenrec is not installed. Please install it manually."
        fi
        if ! command -v quickshell &>/dev/null; then
            fail "Quickshell is not installed and no AUR helper is available."
            fail "Please install 'paru' or 'yay' first, then re-run this script."
            exit 1
        else
            success "Quickshell is already installed"
        fi
    fi
}

install_fedora() {
    local deps=(
        brightnessctl wl-clipboard ImageMagick NetworkManager bluez
        fftw-devel gtk3-devel python3-gobject git wget curl jq bc xdg-utils
        grim slurp tesseract tesseract-langpack-eng zbar ffmpeg wf-recorder wtype
        cliphist hyprpicker translate-shell
    )
    info "Installing system packages via dnf..."
    sudo dnf install -y "${deps[@]}" 2>&1 | tail -n 5
    warn "Please ensure 'quickshell' is compiled and installed for Fedora."
}

install_debian() {
    local deps=(
        brightnessctl wl-clipboard imagemagick network-manager bluez
        libfftw3-dev libgtk-3-dev python3-gi git wget curl jq bc xdg-utils
        grim slurp tesseract-ocr tesseract-ocr-eng zbar-tools ffmpeg wf-recorder wtype
        cliphist translate-shell
    )
    info "Installing system packages via apt..."
    sudo apt update -qq
    sudo apt install -y "${deps[@]}" 2>&1 | tail -n 5
    warn "Please ensure 'quickshell' is compiled and installed from source."
}

case "$OS_NAME" in
    arch|cachyos|manjaro|endeavouros|garuda|artix)
        install_arch ;;
    fedora)
        install_fedora ;;
    ubuntu|debian|pop|mint|zorin)
        install_debian ;;
    *)
        warn "Unsupported distro: $OS_NAME"
        echo -e "  ${DIM}Required packages: quickshell, brightnessctl, wl-clipboard, imagemagick,"
        echo -e "  networkmanager, bluez, fftw, grim, slurp, hyprpicker, cliphist, jq, curl${NC}"
        read -rp "  Continue with manual dependency management? [y/N] " answer
        [[ "$answer" =~ ^[Yy]$ ]] || exit 1
        ;;
esac

success "Dependencies installed"

# ── Step 3: Install Profile ──────────────────────────────────────────────────
header "Step 3/6 — Installing QuickIsland Profile"

mkdir -p "$PROFILE_DIR"

if [ "$SCRIPT_DIR" != "$PROFILE_DIR" ]; then
    info "Copying QuickIsland to $PROFILE_DIR..."
    # Use rsync if available for better handling, fallback to cp
    if command -v rsync &>/dev/null; then
        rsync -a --delete --exclude='.git' "$SCRIPT_DIR/" "$PROFILE_DIR/"
    else
        cp -a "$SCRIPT_DIR"/. "$PROFILE_DIR/"
    fi
    success "Profile copied to $PROFILE_DIR"
else
    success "Already running from the install location"
fi

# ── Step 4: Set Permissions ──────────────────────────────────────────────────
header "Step 4/6 — Setting Permissions"

chmod +x "$PROFILE_DIR/install.sh"
chmod +x "$PROFILE_DIR/launch.sh"
chmod +x "$PROFILE_DIR/scripts/"*.sh 2>/dev/null || true
chmod +x "$PROFILE_DIR/scripts/"*.py 2>/dev/null || true
chmod +x "$PROFILE_DIR/ScreenToolkit/scripts/"*.sh 2>/dev/null || true
chmod +x "$PROFILE_DIR/ScreenToolkit/scripts/"*.py 2>/dev/null || true

success "Permissions set"

# ── Step 5: Configure Hyprland Keybindings ───────────────────────────────────
header "Step 5/6 — Configuring Keybindings"

HYPR_DIR="$HOME/.config/hypr"
KEYBIND_FILE="$HYPR_DIR/keybindings.conf"

configure_keybind() {
    local key="$1"
    local desc="$2"
    local ipc_cmd="$3"
    local search_pattern="$4"
    local bind_line="bindd = \$mainMod, $key, \$d $desc , exec, quickshell -p ~/.config/quickshell/quickisland/ ipc call $ipc_cmd"

    if grep -q "$search_pattern" "$KEYBIND_FILE" 2>/dev/null; then
        info "Keybinding for $desc already exists, updating..."
        # Remove old line and add new one
        grep -v "$search_pattern" "$KEYBIND_FILE" > "$KEYBIND_FILE.tmp" && mv "$KEYBIND_FILE.tmp" "$KEYBIND_FILE"
    fi
    echo -e "\n# QuickIsland: $desc\n$bind_line" >> "$KEYBIND_FILE"
    success "Bound Super + $key → $desc"
}

if [ -d "$HYPR_DIR" ]; then
    [ -f "$KEYBIND_FILE" ] || touch "$KEYBIND_FILE"

    configure_keybind "A"      "toggle launcher"        "state toggle 4"                      "ipc call state toggle 4"
    configure_keybind "N"      "toggle control center"  "state toggle 5"                      "ipc call state toggle 5"
    configure_keybind "V"      "clipboard"              "clipboard toggle"                    "ipc call clipboard toggle"
    configure_keybind "period"  "emoji picker"          "emoji toggle"                        "ipc call emoji toggle"
    configure_keybind "slash"   "toggle keybindings help" "state toggle 16"                     "ipc call state toggle 16"

    # Shift keybindings (different syntax)
    ANNOTATE_LINE="bindd = \$mainMod SHIFT, S, \$d annotate region , exec, quickshell -p ~/.config/quickshell/quickisland/ ipc call plugin:screen-toolkit annotate"
    if ! grep -q "plugin:screen-toolkit annotate" "$KEYBIND_FILE" 2>/dev/null; then
        echo -e "\n# QuickIsland: Screen Annotate\n$ANNOTATE_LINE" >> "$KEYBIND_FILE"
        success "Bound Super + Shift + S → annotate region"
    else
        success "Super + Shift + S already configured"
    fi

    PICKER_LINE="bindd = \$mainMod SHIFT, C, \$d color picker , exec, quickshell -p ~/.config/quickshell/quickisland/ ipc call plugin:screen-toolkit colorPicker"
    if ! grep -q "plugin:screen-toolkit colorPicker" "$KEYBIND_FILE" 2>/dev/null; then
        echo -e "\n# QuickIsland: Color Picker\n$PICKER_LINE" >> "$KEYBIND_FILE"
        success "Bound Super + Shift + C → color picker"
    else
        success "Super + Shift + C already configured"
    fi

    # Reload Hyprland config if running
    if command -v hyprctl &>/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl reload &>/dev/null && success "Hyprland config reloaded" || true
    fi
else
    warn "Hyprland config directory not found at $HYPR_DIR"
    warn "Skipping keybinding setup — configure manually after installing Hyprland."
fi

# ── Step 6: Autostart Configuration ──────────────────────────────────────────
header "Step 6/6 — Autostart Configuration"

HYPR_CONF="$HYPR_DIR/hyprland.conf"
LAUNCH_CMD="exec-once = ~/.config/quickshell/quickisland/launch.sh"

if [ -f "$HYPR_CONF" ]; then
    if grep -q "quickisland/launch.sh" "$HYPR_CONF" 2>/dev/null; then
        success "Autostart already configured in hyprland.conf"
    else
        echo ""
        echo -e "  ${BOLD}Would you like to add QuickIsland to Hyprland autostart?${NC}"
        echo -e "  ${DIM}This adds '${LAUNCH_CMD}' to your hyprland.conf${NC}"
        read -rp "  Add to autostart? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo -e "\n# QuickIsland Morphing Shell\n$LAUNCH_CMD" >> "$HYPR_CONF"
            success "Added to autostart"
        else
            info "Skipped — you can add it manually later"
        fi
    fi
else
    warn "hyprland.conf not found. Add this line to your config to autostart:"
    echo -e "  ${CYAN}$LAUNCH_CMD${NC}"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  ★  QuickIsland installed successfully!  ★${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Launch now:${NC}"
echo -e "    ${CYAN}bash ~/.config/quickshell/quickisland/launch.sh${NC}"
echo ""
echo -e "  ${BOLD}Or restart Hyprland to trigger autostart:${NC}"
echo -e "    ${CYAN}hyprctl dispatch exit${NC}"
echo ""
echo -e "  ${BOLD}Keybindings:${NC}"
echo -e "    ${DIM}Super + A${NC}           → Toggle Application Launcher"
echo -e "    ${DIM}Super + N${NC}           → Toggle Control Center"
echo -e "    ${DIM}Super + V${NC}           → Clipboard History"
echo -e "    ${DIM}Super + .${NC}           → Emoji Picker"
echo -e "    ${DIM}Super + /${NC}           → Keyboard Shortcuts Help"
echo -e "    ${DIM}Super + Shift + S${NC}   → Screen Annotate"
echo -e "    ${DIM}Super + Shift + C${NC}   → Color Picker"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
