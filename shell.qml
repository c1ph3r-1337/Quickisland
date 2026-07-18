import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import qs.Services.Keyboard
import qs.Commons
import qs.Services.UI
import qs.Services.Hardware
import qs.Services.Networking
import "ScreenToolkit" as ST

ShellRoot {
    id: shell

    // =========================================================================
    // GLOBAL THEME PALETTE
    // =========================================================================
    property string themeMode: "wallpaper"   // "custom" or "wallpaper"
    property bool _loadingTheme: false
    onThemeModeChanged: saveCustomPalette()

    // Custom (Catppuccin Mocha) defaults
    property color customAccent:        "#cba6f7"
    property color customSurface:       "#11111b"
    property color customSurfaceAlt:    "#1e1e2e"
    property color customSurfaceBright: "#313244"
    property color customTextPrimary:   "#cdd6f4"
    property color customTextSecondary: "#a6adc8"
    property color customTextMuted:     "#6c7086"
    property color customRed:           "#f38ba8"
    property color customGreen:         "#a6e3a1"
    property color customPeach:         "#fab387"
    property color customBlue:          "#89b4fa"
    // Custom palette designer properties
    property string activeColorName: "Accent"
    property string activeColorKey: "customAccent"
    property string activeColorHex: "#cba6f7"
    property bool pickerRunning: false
    property bool locked: false

    function selectColor(name, key) {
        activeColorName = name;
        activeColorKey = key;
        activeColorHex = shell[key].toString();
    }

    function updateActiveColor(hex) {
        if (hex.match(/^#[0-9a-fA-F]{6}$/)) {
            shell[activeColorKey] = hex;
            saveCustomPalette();
        }
    }

    function toggleCustomPaletteWindow() {
        if (shell.currentState === 11) {
            shell.setState(12);
        } else {
            var path = shell.lastExtractedWallpaperPath;
            var saved = (path && customPaletteAdapter.palettes) ? customPaletteAdapter.palettes[path] : null;
            if (!saved) {
                // Copy wallpaper palette theme to custom colors first
                shell.customAccent = shell.wpAccent;
                shell.customSurface = shell.wpSurface;
                shell.customSurfaceAlt = shell.wpSurfaceAlt;
                shell.customSurfaceBright = shell.wpSurfaceBright;
                shell.customTextPrimary = shell.wpTextPrimary;
                shell.customTextSecondary = shell.wpTextSecondary;
                shell.customTextMuted = shell.wpTextMuted;
                shell.customRed = shell.wpRed;
                shell.customGreen = shell.wpGreen;
                shell.customPeach = shell.wpPeach;
                shell.customBlue = shell.wpBlue;

                // Save the custom colors
                shell.saveCustomPalette();
            } else {
                // Load saved colors
                shell.customAccent = saved.customAccent || shell.wpAccent;
                shell.customSurface = saved.customSurface || shell.wpSurface;
                shell.customSurfaceAlt = saved.customSurfaceAlt || shell.wpSurfaceAlt;
                shell.customSurfaceBright = saved.customSurfaceBright || shell.wpSurfaceBright;
                shell.customTextPrimary = saved.customTextPrimary || shell.wpTextPrimary;
                shell.customTextSecondary = saved.customTextSecondary || shell.wpTextSecondary;
                shell.customTextMuted = saved.customTextMuted || shell.wpTextMuted;
                shell.customRed = saved.customRed || shell.wpRed;
                shell.customGreen = saved.customGreen || shell.wpGreen;
                shell.customPeach = saved.customPeach || shell.wpPeach;
                shell.customBlue = saved.customBlue || shell.wpBlue;
            }

            // Sync color picker state
            shell.activeColorHex = shell[shell.activeColorKey].toString();

            shell.setState(11);
        }
    }

    readonly property var presets: [
        {
            name: "Catppuccin Mocha",
            accent: "#cba6f7", surface: "#11111b", surfaceAlt: "#1e1e2e", surfaceBright: "#313244",
            textPrimary: "#cdd6f4", textSecondary: "#a6adc8", textMuted: "#6c7086",
            red: "#f38ba8", green: "#a6e3a1", peach: "#fab387", blue: "#89b4fa"
        },
        {
            name: "Gruvbox Dark",
            accent: "#fabd2f", surface: "#1d2021", surfaceAlt: "#282828", surfaceBright: "#3c3836",
            textPrimary: "#fbf1c7", textSecondary: "#bdae93", textMuted: "#928374",
            red: "#fb4934", green: "#b8bb26", peach: "#fe8019", blue: "#83a598"
        },
        {
            name: "Tokyo Night",
            accent: "#7aa2f7", surface: "#1a1b26", surfaceAlt: "#24283b", surfaceBright: "#414868",
            textPrimary: "#c0caf5", textSecondary: "#a9b1d6", textMuted: "#565f89",
            red: "#f7768e", green: "#9ece6a", peach: "#ff9e64", blue: "#7accff"
        },
        {
            name: "Nord",
            accent: "#88c0d0", surface: "#2e3440", surfaceAlt: "#3b4252", surfaceBright: "#4c566a",
            textPrimary: "#eceff4", textSecondary: "#d8dee9", textMuted: "#4c566a",
            red: "#bf616a", green: "#a3be8c", peach: "#ebcb8b", blue: "#81a1c1"
        },
        {
            name: "Cyberpunk",
            accent: "#ff007f", surface: "#0b0813", surfaceAlt: "#161224", surfaceBright: "#2d1b4e",
            textPrimary: "#00ffff", textSecondary: "#e0ffff", textMuted: "#7b68ee",
            red: "#ff3333", green: "#33ff33", peach: "#ffaa00", blue: "#00aaff"
        }
    ]

    function applyPreset(p) {
        customAccent = p.accent;
        customSurface = p.surface;
        customSurfaceAlt = p.surfaceAlt;
        customSurfaceBright = p.surfaceBright;
        customTextPrimary = p.textPrimary;
        customTextSecondary = p.textSecondary;
        customTextMuted = p.textMuted;
        customRed = p.red;
        customGreen = p.green;
        customPeach = p.peach;
        customBlue = p.blue;
        activeColorHex = shell[activeColorKey].toString();
        saveCustomPalette();
    }

    function rgbToHsl(r, g, b) {
        let max = Math.max(r, g, b), min = Math.min(r, g, b);
        let h, s, l = (max + min) / 2;

        if (max === min) {
            h = s = 0;
        } else {
            let d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            switch (max) {
                case r: h = (g - b) / d + (g < b ? 6 : 0); break;
                case g: h = (b - r) / d + 2; break;
                case b: h = (r - g) / d + 4; break;
            }
            h /= 6;
        }
        return { h: h, s: s, l: l };
    }

    function generateFromAccent() {
        let r = shell.customAccent.r;
        let g = shell.customAccent.g;
        let b = shell.customAccent.b;
        let hsl = rgbToHsl(r, g, b);
        
        customSurface = Qt.hsla(hsl.h, Math.min(hsl.s * 0.25, 0.12), 0.06, 1.0);
        customSurfaceAlt = Qt.hsla(hsl.h, Math.min(hsl.s * 0.25, 0.12), 0.10, 1.0);
        customSurfaceBright = Qt.hsla(hsl.h, Math.min(hsl.s * 0.30, 0.18), 0.16, 1.0);
        customTextPrimary = Qt.hsla(hsl.h, Math.min(hsl.s * 0.15, 0.08), 0.94, 1.0);
        customTextSecondary = Qt.hsla(hsl.h, Math.min(hsl.s * 0.15, 0.08), 0.80, 1.0);
        customTextMuted = Qt.hsla(hsl.h, Math.min(hsl.s * 0.12, 0.06), 0.52, 1.0);
        customRed = Qt.hsla(345/360, Math.max(0.7, hsl.s), 0.72, 1.0);
        customGreen = Qt.hsla(120/360, Math.max(0.65, hsl.s), 0.74, 1.0);
        customPeach = Qt.hsla(25/360, Math.max(0.75, hsl.s), 0.74, 1.0);
        customBlue = Qt.hsla(215/360, Math.max(0.7, hsl.s), 0.76, 1.0);
        
        activeColorHex = shell[activeColorKey].toString();
        saveCustomPalette();
    }

    Connections {
        target: shell
        function onCustomAccentChanged() { if (shell.activeColorKey === "customAccent") shell.activeColorHex = shell.customAccent.toString(); }
        function onCustomSurfaceChanged() { if (shell.activeColorKey === "customSurface") shell.activeColorHex = shell.customSurface.toString(); }
        function onCustomSurfaceAltChanged() { if (shell.activeColorKey === "customSurfaceAlt") shell.activeColorHex = shell.customSurfaceAlt.toString(); }
        function onCustomSurfaceBrightChanged() { if (shell.activeColorKey === "customSurfaceBright") shell.activeColorHex = shell.customSurfaceBright.toString(); }
        function onCustomTextPrimaryChanged() { if (shell.activeColorKey === "customTextPrimary") shell.activeColorHex = shell.customTextPrimary.toString(); }
        function onCustomTextSecondaryChanged() { if (shell.activeColorKey === "customTextSecondary") shell.activeColorHex = shell.customTextSecondary.toString(); }
        function onCustomTextMutedChanged() { if (shell.activeColorKey === "customTextMuted") shell.activeColorHex = shell.customTextMuted.toString(); }
        function onCustomRedChanged() { if (shell.activeColorKey === "customRed") shell.activeColorHex = shell.customRed.toString(); }
        function onCustomGreenChanged() { if (shell.activeColorKey === "customGreen") shell.activeColorHex = shell.customGreen.toString(); }
        function onCustomPeachChanged() { if (shell.activeColorKey === "customPeach") shell.activeColorHex = shell.customPeach.toString(); }
        function onCustomBlueChanged() { if (shell.activeColorKey === "customBlue") shell.activeColorHex = shell.customBlue.toString(); }
    }

    // Sync quickisland theme colors
    Binding { target: Color; property: "mPrimary";          value: shell.accent }
    Binding { target: Color; property: "mOnPrimary";        value: shell.surface }
    Binding { target: Color; property: "mSurface";          value: shell.surface }
    Binding { target: Color; property: "mSurfaceVariant";   value: shell.surfaceAlt }
    Binding { target: Color; property: "mOnSurface";        value: shell.textPrimary }
    Binding { target: Color; property: "mOnSurfaceVariant"; value: shell.textSecondary }
    Binding { target: Color; property: "mError";            value: shell.red }
    Binding { target: Color; property: "mSecondary";        value: shell.accentDim }
    Binding { target: Color; property: "mOnSecondary";      value: shell.textPrimary }
    Binding { target: Color; property: "mHover";            value: shell.surfaceBright }
    Binding { target: Color; property: "mOnHover";          value: shell.textPrimary }

    // ── Screen Toolkit Standalone Setup ──────────────────────────────────
    FileView {
        id: screenToolkitEnJson
        path: Qt.resolvedUrl("ScreenToolkit/i18n/en.json").toString().replace("file://", "")
        printErrors: false
        watchChanges: false
        adapter: JsonAdapter {
            id: screenToolkitEnAdapter
            property var widget: ({})
            property var panel: ({})
            property var tools: ({})
            property var tooltips: ({})
            property var mirror: ({})
            property var record: ({})
            property var annotate: ({})
            property var messages: ({})
            property var settings: ({})
            property var pin: ({})
        }
        onLoaded: {
            var dict = {};
            dict["widget"] = screenToolkitEnAdapter.widget;
            dict["panel"] = screenToolkitEnAdapter.panel;
            dict["tools"] = screenToolkitEnAdapter.tools;
            dict["tooltips"] = screenToolkitEnAdapter.tooltips;
            dict["mirror"] = screenToolkitEnAdapter.mirror;
            dict["record"] = screenToolkitEnAdapter.record;
            dict["annotate"] = screenToolkitEnAdapter.annotate;
            dict["messages"] = screenToolkitEnAdapter.messages;
            dict["settings"] = screenToolkitEnAdapter.settings;
            dict["pin"] = screenToolkitEnAdapter.pin;
            screenToolkitApi.translations = dict;
        }
    }

    FileView {
        id: screenToolkitSettingsFile
        printErrors: false
        watchChanges: false
        Component.onCompleted: {
            if (typeof Settings !== "undefined" && Settings.cacheDir) {
                path = Settings.cacheDir + "screen-toolkit-settings.json";
            } else {
                path = Quickshell.env("HOME") + "/.config/quickshell/quickisland/screen-toolkit-settings.json";
            }
        }
        adapter: JsonAdapter {
            id: screenToolkitSettingsAdapter
            property string screenshotPath: ""
            property string videoPath: ""
            property string filenameFormat: ""
            property string selectedOcrLang: "eng"
            property bool recordSkipConfirmation: false
            property bool recordCopyToClipboard: false
            property int gifMaxSeconds: 30
            property var colorHistory: []
            property var paletteColors: []
            property string resultHex: ""
            property string resultRgb: ""
            property string resultHsv: ""
            property string resultHsl: ""
            property string colorCapturePath: ""
            property int colorCacheBust: 0
            property string ocrResult: ""
            property string ocrCapturePath: ""
            property string translateResult: ""
            property string qrResult: ""
            property string qrCapturePath: ""
            property var installedLangs: ["eng"]
            property bool transAvailable: false
            property string detectedRecorder: ""
            property string x02ApiKey: ""
            property string x02Expiry: "7d"
            property bool shareSkipPopover: false
            property string searchEngineUrl: ""
        }
        onLoaded: {
            var keys = [
                "screenshotPath", "videoPath", "filenameFormat", "selectedOcrLang",
                "recordSkipConfirmation", "recordCopyToClipboard", "gifMaxSeconds",
                "colorHistory", "paletteColors", "resultHex", "resultRgb", "resultHsv",
                "resultHsl", "colorCapturePath", "colorCacheBust", "ocrResult",
                "ocrCapturePath", "translateResult", "qrResult", "qrCapturePath",
                "installedLangs", "transAvailable", "detectedRecorder", "x02ApiKey",
                "x02Expiry", "shareSkipPopover", "searchEngineUrl"
            ];
            for (var i = 0; i < keys.length; i++) {
                var k = keys[i];
                if (screenToolkitSettingsAdapter[k] !== undefined) {
                    screenToolkitSettings[k] = screenToolkitSettingsAdapter[k];
                }
            }
        }
    }

    QtObject {
        id: screenToolkitApi
        property var mainInstance: screenToolkitMain
        property var pluginSettings: QtObject {
            id: screenToolkitSettings
            property string screenshotPath: ""
            property string videoPath: ""
            property string filenameFormat: ""
            property string selectedOcrLang: "eng"
            property bool recordSkipConfirmation: false
            property bool recordCopyToClipboard: false
            property int gifMaxSeconds: 30
            property var colorHistory: []
            property var paletteColors: []
            property string resultHex: ""
            property string resultRgb: ""
            property string resultHsv: ""
            property string resultHsl: ""
            property string colorCapturePath: ""
            property int colorCacheBust: 0
            property string ocrResult: ""
            property string ocrCapturePath: ""
            property string translateResult: ""
            property string qrResult: ""
            property string qrCapturePath: ""
            property var installedLangs: ["eng"]
            property bool transAvailable: false
            property string detectedRecorder: ""
            property string x02ApiKey: ""
            property string x02Expiry: "7d"
            property bool shareSkipPopover: false
            property string searchEngineUrl: ""
        }

        property var translations: ({})
        function tr(key, replacements) {
            var parts = key.split(".");
            var val = translations;
            for (var i = 0; i < parts.length; i++) {
                if (val && val[parts[i]] !== undefined) {
                    val = val[parts[i]];
                } else {
                    return key;
                }
            }
            if (typeof val !== "string") return key;
            var result = val;
            if (replacements) {
                for (var k in replacements) {
                    result = result.replace(new RegExp("{" + k + "}", "g"), replacements[k]);
                }
            }
            return result;
        }

        function saveSettings() {
            var keys = [
                "screenshotPath", "videoPath", "filenameFormat", "selectedOcrLang",
                "recordSkipConfirmation", "recordCopyToClipboard", "gifMaxSeconds",
                "colorHistory", "paletteColors", "resultHex", "resultRgb", "resultHsv",
                "resultHsl", "colorCapturePath", "colorCacheBust", "ocrResult",
                "ocrCapturePath", "translateResult", "qrResult", "qrCapturePath",
                "installedLangs", "transAvailable", "detectedRecorder", "x02ApiKey",
                "x02Expiry", "shareSkipPopover", "searchEngineUrl"
            ];
            for (var i = 0; i < keys.length; i++) {
                var k = keys[i];
                screenToolkitSettingsAdapter[k] = screenToolkitSettings[k];
            }
            screenToolkitSettingsFile.writeAdapter();
        }

        function withCurrentScreen(callback) {
            if (Quickshell.screens.length > 0) {
                callback(Quickshell.screens[0]);
            }
        }

        function closePanel(screen) {
            if (shell.prevState === 5) {
                shell.setState(5);
            } else {
                shell.setState(0);
            }
        }

        function openPanel(screen) {
            shell.setState(14);
        }

        function togglePanel(screen) {
            if (shell.currentState === 14) {
                shell.setState(0);
            } else {
                shell.setState(14);
            }
        }
    }

    ST.Main {
        id: screenToolkitMain
        pluginApi: screenToolkitApi
    }

    FileView {
        id: customPaletteFileView
        printErrors: false
        watchChanges: false
        adapter: JsonAdapter {
            id: customPaletteAdapter
            property var palettes: ({})
            property string themeMode: "wallpaper"
            property string customAccent: "#cba6f7"
            property string customSurface: "#11111b"
            property string customSurfaceAlt: "#1e1e2e"
            property string customSurfaceBright: "#313244"
            property string customTextPrimary: "#cdd6f4"
            property string customTextSecondary: "#a6adc8"
            property string customTextMuted: "#6c7086"
            property string customRed: "#f38ba8"
            property string customGreen: "#a6e3a1"
            property string customPeach: "#fab387"
            property string customBlue: "#89b4fa"
        }
        onLoaded: {
            shell.themeMode = customPaletteAdapter.themeMode || "wallpaper";
            shell.customAccent = customPaletteAdapter.customAccent || "#cba6f7";
            shell.customSurface = customPaletteAdapter.customSurface || "#11111b";
            shell.customSurfaceAlt = customPaletteAdapter.customSurfaceAlt || "#1e1e2e";
            shell.customSurfaceBright = customPaletteAdapter.customSurfaceBright || "#313244";
            shell.customTextPrimary = customPaletteAdapter.customTextPrimary || "#cdd6f4";
            shell.customTextSecondary = customPaletteAdapter.customTextSecondary || "#a6adc8";
            shell.customTextMuted = customPaletteAdapter.customTextMuted || "#6c7086";
            shell.customRed = customPaletteAdapter.customRed || "#f38ba8";
            shell.customGreen = customPaletteAdapter.customGreen || "#a6e3a1";
            shell.customPeach = customPaletteAdapter.customPeach || "#fab387";
            shell.customBlue = customPaletteAdapter.customBlue || "#89b4fa";
            shell.activeColorHex = shell[shell.activeColorKey].toString();
        }
    }

    Connections {
        target: WallpaperService
        function onWallpaperChanged(screenName, path) {
            shell.extractColorsFromWallpaper(path);
        }
    }

    Timer {
        id: startupWpTimer
        interval: 800
        running: true
        repeat: false
        onTriggered: {
            if (Quickshell.screens.length > 0) {
                var screenName = Quickshell.screens[0].name;
                var wpPath = WallpaperService.getWallpaper(screenName);
                if (wpPath) {
                    shell.extractColorsFromWallpaper(wpPath);
                } else {
                    var defaultWp = WallpaperService.defaultWallpaper;
                    if (defaultWp) {
                        shell.extractColorsFromWallpaper(defaultWp);
                    }
                }
            }
        }
    }

    function saveCustomPalette() {
        if (_loadingTheme) return;
        var path = shell.lastExtractedWallpaperPath;
        if (!path) return;

        var dict = customPaletteAdapter.palettes || {};
        dict[path] = {
            "themeMode": shell.themeMode,
            "customAccent": shell.customAccent.toString(),
            "customSurface": shell.customSurface.toString(),
            "customSurfaceAlt": shell.customSurfaceAlt.toString(),
            "customSurfaceBright": shell.customSurfaceBright.toString(),
            "customTextPrimary": shell.customTextPrimary.toString(),
            "customTextSecondary": shell.customTextSecondary.toString(),
            "customTextMuted": shell.customTextMuted.toString(),
            "customRed": shell.customRed.toString(),
            "customGreen": shell.customGreen.toString(),
            "customPeach": shell.customPeach.toString(),
            "customBlue": shell.customBlue.toString()
        };
        customPaletteAdapter.palettes = dict;
        customPaletteFileView.writeAdapter();
    }

    function loadThemeForWallpaper(path) {
        if (!path) return;
        _loadingTheme = true;
        var saved = (customPaletteAdapter.palettes && customPaletteAdapter.palettes[path]) ? customPaletteAdapter.palettes[path] : null;
        if (saved) {
            shell.customAccent = saved.customAccent || shell.wpAccent;
            shell.customSurface = saved.customSurface || shell.wpSurface;
            shell.customSurfaceAlt = saved.customSurfaceAlt || shell.wpSurfaceAlt;
            shell.customSurfaceBright = saved.customSurfaceBright || shell.wpSurfaceBright;
            shell.customTextPrimary = saved.customTextPrimary || shell.wpTextPrimary;
            shell.customTextSecondary = saved.customTextSecondary || shell.wpTextSecondary;
            shell.customTextMuted = saved.customTextMuted || shell.wpTextMuted;
            shell.customRed = saved.customRed || shell.wpRed;
            shell.customGreen = saved.customGreen || shell.wpGreen;
            shell.customPeach = saved.customPeach || shell.wpPeach;
            shell.customBlue = saved.customBlue || shell.wpBlue;
            shell.themeMode = saved.themeMode || "wallpaper";
        } else {
            shell.themeMode = "wallpaper";
            shell.customAccent = shell.wpAccent;
            shell.customSurface = shell.wpSurface;
            shell.customSurfaceAlt = shell.wpSurfaceAlt;
            shell.customSurfaceBright = shell.wpSurfaceBright;
            shell.customTextPrimary = shell.wpTextPrimary;
            shell.customTextSecondary = shell.wpTextSecondary;
            shell.customTextMuted = shell.wpTextMuted;
            shell.customRed = shell.wpRed;
            shell.customGreen = shell.wpGreen;
            shell.customPeach = shell.wpPeach;
            shell.customBlue = shell.wpBlue;
        }
        shell.activeColorHex = shell[shell.activeColorKey].toString();
        _loadingTheme = false;
    }

    IpcHandler {
        target: "clipboard"
        function toggle() {
            console.log("[IPC Debug] Clipboard toggle called. Current state: " + shell.currentState);
            if (shell.currentState === 13) {
                shell.setState(0);
            } else {
                shell.setState(13);
            }
        }
    }

    IpcHandler {
        target: "emoji"
        function toggle() {
            if (shell.currentState === 15) {
                shell.setState(0);
            } else {
                shell.setState(15);
            }
        }
    }

    IpcHandler {
        target: "state"
        function set(s: int) {
            shell.setState(s);
        }
        function toggle(s: int) {
            if (shell.currentState === s) {
                shell.setState(0);
            } else {
                shell.setState(s);
            }
        }
    }

    IpcHandler {
        target: "lockscreen"
        function lock() {
            shell.locked = true;
        }
        function unlock() {
            shell.locked = false;
        }
    }

    Process {
        id: pickerProc
        command: ["hyprpicker"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var hexColor = text.trim();
                if (hexColor.match(/^#[0-9a-fA-F]{6}$/)) {
                    shell.updateActiveColor(hexColor);
                }
                shell.pickerRunning = false;
            }
        }
    }


    // Wallpaper-extracted palette (updated by the extraction process)
    property color wpAccent:        "#cba6f7"
    property color wpSurface:       "#11111b"
    property color wpSurfaceAlt:    "#1e1e2e"
    property color wpSurfaceBright: "#313244"
    property color wpTextPrimary:   "#cdd6f4"
    property color wpTextSecondary: "#a6adc8"
    property color wpTextMuted:     "#6c7086"
    property color wpRed:           "#f38ba8"
    property color wpGreen:         "#a6e3a1"
    property color wpPeach:         "#fab387"
    property color wpBlue:          "#89b4fa"

    // Active palette — switches based on themeMode
    property color accent:          themeMode === "wallpaper" ? wpAccent        : customAccent
    property color accentDim:       Qt.rgba(accent.r, accent.g, accent.b, 0.15)
    // Base opaque colors for calculations
    readonly property color _baseSurface:       themeMode === "wallpaper" ? wpSurface       : customSurface
    readonly property color _baseSurfaceAlt:    themeMode === "wallpaper" ? wpSurfaceAlt    : customSurfaceAlt
    readonly property color _baseSurfaceBright: themeMode === "wallpaper" ? wpSurfaceBright : customSurfaceBright

    // Translucent Liquid Glass / Matte Blur equivalents
    property real _effectiveIntensity: (Settings.isLoaded && Settings.data.colorSchemes.hyprglass) ? 0.76 : 0.0

    property color surface:         _effectiveIntensity > 0.0
                                    ? Qt.rgba(_baseSurface.r, _baseSurface.g, _baseSurface.b, 1.0 - _effectiveIntensity)
                                    : _baseSurface
    property color surfaceAlt:      _effectiveIntensity > 0.0
                                    ? Qt.rgba(_baseSurfaceAlt.r, _baseSurfaceAlt.g, _baseSurfaceAlt.b, (1.0 - _effectiveIntensity) * (1.0 + _effectiveIntensity * 0.3))
                                    : _baseSurfaceAlt
    property color surfaceBright:   _effectiveIntensity > 0.0
                                    ? Qt.rgba(_baseSurfaceBright.r, _baseSurfaceBright.g, _baseSurfaceBright.b, (1.0 - _effectiveIntensity) * (1.0 + _effectiveIntensity * 0.6))
                                    : _baseSurfaceBright
    property color surfaceBorder:   _effectiveIntensity > 0.0
                                    ? Qt.rgba(1, 1, 1, 0.06 + _effectiveIntensity * 0.08)
                                    : Qt.rgba(1, 1, 1, 0.06)
    property color textPrimary:     themeMode === "wallpaper" ? wpTextPrimary   : customTextPrimary
    property color textSecondary:   themeMode === "wallpaper" ? wpTextSecondary : customTextSecondary
    property color textMuted:       themeMode === "wallpaper" ? wpTextMuted     : customTextMuted
    property color red:             themeMode === "wallpaper" ? wpRed           : customRed
    property color green:           themeMode === "wallpaper" ? wpGreen         : customGreen
    property color peach:           themeMode === "wallpaper" ? wpPeach         : customPeach
    property color blue:            themeMode === "wallpaper" ? wpBlue          : customBlue

    Behavior on accent        { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on surface       { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on surfaceAlt    { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on surfaceBright { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on textPrimary   { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on textSecondary { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on textMuted     { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on red           { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on green         { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on peach         { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on blue          { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }

    // Color extraction process
    property string lastExtractedWallpaperPath: ""
    property string _pendingWallpaperPath: ""

    Timer {
        id: debounceExtractTimer
        interval: 150
        running: false
        repeat: false
        onTriggered: {
            if (shell._pendingWallpaperPath && shell._pendingWallpaperPath !== shell.lastExtractedWallpaperPath) {
                colorExtractProc.running = false;
                colorExtractProc.running = true;
            }
        }
    }

    Process {
        id: colorExtractProc
        command: ["python3", Qt.resolvedUrl("scripts/extract_colors.py").toString().replace("file://", ""), shell._pendingWallpaperPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var palette = JSON.parse(text.trim());
                    if (palette.error) { console.log("Color extract error:", palette.error); return; }
                    shell.wpAccent        = palette.accent;
                    shell.wpSurface       = palette.surface;
                    shell.wpSurfaceAlt    = palette.surfaceAlt;
                    shell.wpSurfaceBright = palette.surfaceBright;
                    shell.wpTextPrimary   = palette.textPrimary;
                    shell.wpTextSecondary = palette.textSecondary;
                    shell.wpTextMuted     = palette.textMuted;
                    shell.wpRed           = palette.red;
                    shell.wpGreen         = palette.green;
                    shell.wpPeach         = palette.peach;
                    shell.wpBlue          = palette.blue;
                    shell.lastExtractedWallpaperPath = shell._pendingWallpaperPath;
                    shell.loadThemeForWallpaper(shell.lastExtractedWallpaperPath);
                } catch(e) { console.log("Color parse error:", e, text); }
            }
        }
    }

    function extractColorsFromWallpaper(imagePath) {
        if (!imagePath) return;

        var resolvedPath = imagePath;
        if (imagePath.startsWith("qs/")) {
            resolvedPath = Quickshell.env("HOME") + "/.config/quickshell/quickisland/" + imagePath.substring(3);
        }

        if (resolvedPath === shell.lastExtractedWallpaperPath) {
            return;
        }

        shell._pendingWallpaperPath = resolvedPath;
        debounceExtractTimer.restart();
    }

    readonly property int animFast:   75
    readonly property int animNormal: 140

    // =========================================================================
    // STATE MACHINE
    // 0=Idle 1=Expanded 2=OSD 3=Notification 4=Launcher 5=Control 6=Power 7=Polkit
    // =========================================================================
    property int currentState: 0
    property int prevState: 0
    property bool hoverCooldown: false
    property double lastState1Time: 0
    function setState(s) {
        console.log("[State Debug] setState called: " + currentState + " -> " + s);
        prevState = currentState;
        // Start cooldown when leaving any active state back to idle
        if (currentState > 0 && s === 0) {
            hoverCooldown = true;
            hoverCooldownTimer.restart();
        }
        if (s === 1) {
            lastState1Time = Date.now();
        }
        currentState = s;
    }
    Timer {
        id: hoverCooldownTimer
        interval: 50
        onTriggered: shell.hoverCooldown = false
    }

    property string currentTime12h: formatTime12h()

    Timer {
        id: centralClockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: shell.currentTime12h = shell.formatTime12h()
    }

    function formatTime12h() {
        let d = new Date();
        let h = d.getHours();
        let m = d.getMinutes();
        let h12 = (h % 12) || 12;
        let mStr = m < 10 ? "0" + m : m;
        return h12 + ":" + mStr;
    }



    // =========================================================================
    // REAL SERVICE BINDINGS
    // =========================================================================

    // ── Audio (Pipewire) ─────────────────────────────────────────────────
    readonly property var audioSink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: shell.audioSink ? [shell.audioSink] : [] }

    property bool volDragging: false
    property real sysVolume: 0
    Binding {
        target: shell
        property: "sysVolume"
        value: shell.audioSink && shell.audioSink.audio ? shell.audioSink.audio.volume : 0
        when: !shell.volDragging
    }
    property bool sysMuted: audioSink && audioSink.audio ? audioSink.audio.muted : true

    function setVolume(v) {
        if (audioSink && audioSink.audio) {
            var targetVol = Math.max(0, Math.min(1.0, v));
            shell.sysVolume = targetVol;
            audioSink.audio.volume = targetVol;
        }
    }
    function toggleMute() {
        if (audioSink && audioSink.audio) audioSink.audio.muted = !audioSink.audio.muted;
    }

    // Volume change → show OSD
    property real _lastVolume: -1
    onSysVolumeChanged: {
        if (_lastVolume >= 0 && Math.abs(sysVolume - _lastVolume) > 0.001) {
            if (shell.currentState === 0 || shell.currentState === 2) {
                osdType = "volume";
                setState(2);
                osdTimer.restart();
            }
        }
        _lastVolume = sysVolume;
    }

    // ── Brightness ───────────────────────────────────────────────────────
    property real sysBrightness: 0.5
    property real sysBrightnessMax: 1

    Process {
        id: brightnessReadProc
        command: ["brightnessctl", "info", "-m"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                // format: device,class,current,percentage,max
                var parts = data.split(",");
                if (parts.length >= 5) {
                    var cur = parseInt(parts[2]);
                    var max = parseInt(parts[4]);
                    if (max > 0) {
                        shell.sysBrightnessMax = max;
                        shell.sysBrightness = cur / max;
                    }
                }
            }
        }
    }

    Process {
        id: brightnessSetProc
        running: false
    }

    function refreshBrightness() { brightnessReadProc.running = true; }
    function setBrightness(v) {
        var pct = Math.round(Math.max(0, Math.min(1, v)) * 100);
        brightnessSetProc.command = ["brightnessctl", "set", pct + "%"];
        brightnessSetProc.running = true;
        sysBrightness = v;
    }

    Timer { interval: 5000; running: (shell.currentState === 1); repeat: true; onTriggered: shell.refreshBrightness() }
    Component.onCompleted: {
        refreshBrightness();
        wifiProc.running = true;
        if (Settings.data.wallpaper.directory === "") {
            Settings.data.wallpaper.directory = Quickshell.env("HOME") + "/Pictures/Wallpapers/";
        }
        ImageCacheService.init();
        WallpaperService.init();
        ClipboardService.checkCliphistAvailability();
        Qt.callLater(() => {
            if (typeof Settings !== undefined && Settings.cacheDir) {
                customPaletteFileView.path = Settings.cacheDir + "custom-palette.json";
            }
        });
    }
    Timer {
        interval: 3000; running: typeof Settings !== "undefined" && Settings.isDebug; repeat: false
        onTriggered: console.log("WALLPAPERS LIST:", JSON.stringify(WallpaperService.getWallpapersList(Quickshell.screens[0].name)))
    }

    // ── Battery (BatteryService) ─────────────────────────────────────────
    readonly property real batteryPercent: BatteryService.primaryDevice ? BatteryService.batteryPercentage : -1
    readonly property bool batteryCharging: BatteryService.primaryDevice ? (BatteryService.batteryCharging || BatteryService.batteryPluggedIn) : false

    // ── System Notifications ─────────────────────────────────────────────
    // Fires shell notifications when key system states change.

    // Helper: push a notification into history and show the popup
    function sysNotify(appName, summary, body) {
        if (shell.peaceMode) return;
        shell.notifHistory.insert(0, {
            appName:  appName,
            summary:  summary,
            body:     body,
            nId:      0
        });
        if (shell.notifHistory.count > 50)
            shell.notifHistory.remove(50, shell.notifHistory.count - 50);
        shell.setState(3);
        notifDismissTimer.restart();
    }

    // Charger connect / disconnect + battery level alerts
    QtObject {
        id: _batteryWatcher
        property bool _firstRun: true
        property bool _lastCharging: false
        property int  _lastPercent: -1
        property bool _notifiedLow: false
        property bool _notifiedCritical: false
        property bool _notifiedFull: false

        property var _watchCharging: Connections {
            target: shell
            function onBatteryChargingChanged() {
                if (_batteryWatcher._firstRun) return;
                if (shell.batteryCharging) {
                    _batteryWatcher._notifiedLow = false;
                    _batteryWatcher._notifiedCritical = false;
                    var pct = Math.round(shell.batteryPercent);
                    shell.sysNotify("Power", "Charger Connected", "Battery at " + pct + "%. Charging…");
                } else {
                    _batteryWatcher._notifiedFull = false;
                    var pct = Math.round(shell.batteryPercent);
                    shell.sysNotify("Power", "Charger Disconnected", "Battery at " + pct + "%. Running on battery.");
                }
            }
            function onBatteryPercentChanged() {
                if (_batteryWatcher._firstRun) return;
                var pct = Math.round(shell.batteryPercent);
                if (pct < 0) return;
                if (shell.batteryCharging) {
                    // Full battery alert (once per charge cycle)
                    if (pct >= 100 && !_batteryWatcher._notifiedFull) {
                        _batteryWatcher._notifiedFull = true;
                        shell.sysNotify("Power", "Battery Full", "Your battery is fully charged.");
                    }
                } else {
                    // Low battery alert
                    if (pct <= 20 && pct > 10 && !_batteryWatcher._notifiedLow) {
                        _batteryWatcher._notifiedLow = true;
                        shell.sysNotify("Power", "Low Battery — " + pct + "%", "Consider plugging in your charger.");
                    }
                    // Critical battery alert
                    if (pct <= 10 && !_batteryWatcher._notifiedCritical) {
                        _batteryWatcher._notifiedCritical = true;
                        shell.sysNotify("Power", "Critical Battery — " + pct + "%", "Plug in now to avoid data loss.");
                    }
                }
            }
        }

        // Settle after startup — skip initial state as "change"
        property var _initTimer: Timer {
            interval: 3000; running: true; repeat: false
            onTriggered: {
                _batteryWatcher._firstRun     = false;
                _batteryWatcher._lastCharging = shell.batteryCharging;
                _batteryWatcher._lastPercent  = Math.round(shell.batteryPercent);
            }
        }
    }

    // WiFi connect / disconnect
    QtObject {
        id: _wifiWatcher
        property bool _firstRun: true
        property bool _lastConnected: false
        property string _lastSSID: ""

        property var _watchWifi: Connections {
            target: shell
            function onWifiConnectedChanged() {
                if (_wifiWatcher._firstRun) return;
                if (shell.wifiConnected) {
                    shell.sysNotify("Network", "Wi-Fi Connected",
                                    shell.wifiSSID !== "" ? "Connected to '" + shell.wifiSSID + "'" : "Connected to Wi-Fi.");
                } else {
                    var old = _wifiWatcher._lastSSID;
                    shell.sysNotify("Network", "Wi-Fi Disconnected",
                                    old !== "" ? "Disconnected from '" + old + "'" : "Wi-Fi disconnected.");
                }
                _wifiWatcher._lastSSID = shell.wifiSSID;
            }
        }

        property var _initTimer: Timer {
            interval: 3500; running: true; repeat: false
            onTriggered: {
                _wifiWatcher._firstRun    = false;
                _wifiWatcher._lastConnected = shell.wifiConnected;
                _wifiWatcher._lastSSID      = shell.wifiSSID;
            }
        }
    }

    // Bluetooth connect / disconnect
    QtObject {
        id: _btWatcher
        property bool _firstRun: true

        property var _watchBt: Connections {
            target: shell
            function onBtConnectedChanged() {
                if (_btWatcher._firstRun) return;
                if (shell.btConnected) {
                    shell.sysNotify("Bluetooth", "Bluetooth Device Connected", "A Bluetooth device has been connected.");
                } else {
                    shell.sysNotify("Bluetooth", "Bluetooth Device Disconnected", "A Bluetooth device has been disconnected.");
                }
            }
        }

        property var _initTimer: Timer {
            interval: 4000; running: true; repeat: false
            onTriggered: { _btWatcher._firstRun = false; }
        }
    }


    // ── Media (MPRIS) ────────────────────────────────────────────────────
    readonly property var mediaPlayer: {
        if (!Mpris.players || !Mpris.players.values) return null;
        var players = Mpris.players.values;
        // Prefer a playing player
        for (var i = 0; i < players.length; i++) {
            if (players[i] && players[i].playbackState === MprisPlaybackState.Playing)
                return players[i];
        }
        return players.length > 0 ? players[0] : null;
    }
    readonly property bool mediaPlaying: mediaPlayer ? mediaPlayer.playbackState === MprisPlaybackState.Playing : false
    readonly property string mediaTitle: mediaPlayer ? (mediaPlayer.trackTitle || "") : ""
    readonly property string mediaArtist: mediaPlayer ? (mediaPlayer.trackArtist || "") : ""
    readonly property string mediaArtUrl: mediaPlayer ? (mediaPlayer.trackArtUrl || "") : ""
    readonly property real mediaLength: mediaPlayer ? mediaPlayer.length : 0
    property real mediaPosition: mediaPlayer ? mediaPlayer.position : 0

    Timer {
        interval: 1000; running: shell.mediaPlaying; repeat: true
        onTriggered: { if (shell.mediaPlayer) shell.mediaPosition = shell.mediaPlayer.position; }
    }

    // ── Notifications (Daemon) ───────────────────────────────────────────
    property ListModel notifHistory: ListModel {}
    property string osdType: "volume" // "volume" or "brightness"
    property bool peaceMode: false
    property bool nightMode: false

    NotificationServer {
        id: notifServer
        keepOnReload: false
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
            shell.notifHistory.insert(0, {
                appName: notification.appName || "Unknown",
                summary: notification.summary || "",
                body: notification.body || "",
                nId: notification.id
            });
            if (shell.notifHistory.count > 50) shell.notifHistory.remove(50, shell.notifHistory.count - 50);
            // Show notification popup if not in Peace mode
            if (!shell.peaceMode) {
                shell.setState(3);
                notifDismissTimer.restart();
            }
        }
    }

    Timer {
        id: notifDismissTimer
        interval: 4000
        onTriggered: { if (shell.currentState === 3) shell.setState(0); }
    }

    function clearNotifications() { notifHistory.clear(); }

    function pasteActive() {
        pasteTimer.restart();
    }

    Timer {
        id: pasteTimer
        interval: shell.animFast
        repeat: false
        onTriggered: {
            pasteProc.command = ["hyprctl", "dispatch", "sendshortcut", "CTRL, V, activewindow"];
            pasteProc.running = true;
        }
    }

    Process { id: pasteProc; running: false }

    // ── Network (nmcli) ──────────────────────────────────────────────────
    property string wifiSSID: ""
    property bool wifiConnected: false
    property bool wifiEnabled: false
    property bool ethConnected: false
    property string wifiDevice: ""
    property string wifiConnectionState: "Disconnected" // "Disconnected", "Connecting...", "Authenticating...", "Obtaining IP...", "Connected", "Failed"
    property string wifiLastError: ""
    property string wifiIPAddress: ""
    property string connectedWifiSignal: "100"
    property string connectedWifiSecurity: ""
    property var savedWifiProfiles: ({})

    function getSignalLabel(signal) {
        var s = parseInt(signal);
        if (isNaN(s)) return "Unknown";
        if (s >= 80) return "Excellent";
        if (s >= 60) return "Good";
        if (s >= 35) return "Fair";
        if (s >= 15) return "Poor";
        return "Weak";
    }

    Process {
        id: wifiIPProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var ip = text.trim();
                if (ip) {
                    var idx = ip.indexOf("/");
                    if (idx !== -1) {
                        ip = ip.substring(0, idx);
                    }
                    shell.wifiIPAddress = ip;
                } else {
                    shell.wifiIPAddress = "";
                }
            }
        }
    }

    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli radio wifi; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                if (lines.length === 0) return;
                
                var radioLine = lines[0].trim();
                var isRadioEnabled = (radioLine === "enabled");
                shell.wifiEnabled = isRadioEnabled;

                var wifi = false;
                var eth = false;
                var ssid = "";
                var dev = "";
                var rawState = "disconnected";
                for (var i = 1; i < lines.length; i++) {
                    var parts = lines[i].trim().split(":");
                    if (parts.length >= 4) {
                        var d = parts[0];
                        var type = parts[1];
                        var state = parts[2];
                        var conn = parts[3];
                        if (type === "wifi") {
                            dev = d;
                            rawState = state;
                            if (state === "connected" || state.indexOf("connected") === 0) {
                                wifi = true;
                                ssid = conn;
                            }
                        } else if (type === "ethernet") {
                            if (state === "connected" || state.indexOf("connected") === 0) {
                                eth = true;
                            }
                        }
                    }
                }
                shell.wifiDevice = dev;
                shell.wifiSSID = ssid;
                shell.wifiConnected = wifi;
                shell.ethConnected = eth;

                // Map rawState to human-readable wifiConnectionState
                var friendlyState = "Disconnected";
                if (rawState === "connected") {
                    friendlyState = "Connected";
                } else if (rawState.indexOf("need auth") !== -1) {
                    friendlyState = "Authenticating...";
                } else if (rawState.indexOf("getting IP") !== -1 || rawState.indexOf("checking IP") !== -1) {
                    friendlyState = "Obtaining IP...";
                } else if (rawState.indexOf("connecting") !== -1) {
                    friendlyState = "Connecting...";
                } else if (rawState === "disconnected") {
                    friendlyState = "Disconnected";
                } else if (rawState === "failed") {
                    friendlyState = "Failed";
                } else {
                    friendlyState = rawState;
                }
                
                if (wifiConnectProc.running) {
                    if (friendlyState === "Disconnected") {
                        friendlyState = "Connecting...";
                    }
                }
                
                if (shell.wifiConnectionState !== "Failed" || friendlyState === "Connected" || friendlyState === "Disconnected") {
                    shell.wifiConnectionState = friendlyState;
                }

                if (wifi && dev) {
                    if (shell.wifiIPAddress === "" && !wifiIPProc.running) {
                        wifiIPProc.command = ["nmcli", "-g", "IP4.ADDRESS", "device", "show", dev];
                        wifiIPProc.running = true;
                    }
                } else {
                    shell.wifiIPAddress = "";
                }
            }
        }
    }
    Timer {
        id: wifiPollTimer
        interval: (shell.currentState === 1 || shell.currentState === 8) ? 3000 : 30000
        running: true
        repeat: true
        onTriggered: {
            if (!wifiProc.running) {
                wifiProc.running = true;
            }
        }
    }

    Process {
        id: wifiToggleProc
        running: false
        onExited: {
            wifiProc.running = false;
            wifiProc.running = true;
            if (shell.wifiEnabled) {
                shell.wifiFirstScan = true;
                if (!wifiScanProc.running) {
                    wifiScanProc.running = true;
                }
            }
        }
    }
    function toggleWifi() {
        var nextState = wifiEnabled ? "off" : "on";
        wifiToggleProc.running = false;
        wifiToggleProc.command = ["nmcli", "radio", "wifi", nextState];
        wifiToggleProc.running = true;
        wifiEnabled = !wifiEnabled;
    }

    // ── Bluetooth (BluetoothService) ──────────────────────────────────────
    readonly property bool btConnected: BluetoothService.connectedDevices && BluetoothService.connectedDevices.length > 0
    readonly property bool btPowered: BluetoothService.enabled

    function toggleBluetooth() {
        BluetoothService.setBluetoothEnabled(!BluetoothService.enabled);
    }

    // WiFi Scanning
    property string wifiSelectedSsid: ""
    property bool wifiShowPasswordInput: false

    Process {
        id: wifiForgetProc
        running: false
    }

    Timer {
        id: wifiErrorClearTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (shell.wifiConnectionState === "Failed") {
                shell.wifiConnectionState = "Disconnected";
            }
            shell.wifiLastError = "";
        }
    }

    Process {
        id: wifiDisconnectProc
        running: false
        onExited: (code, status) => {
            wifiProc.running = false;
            wifiProc.running = true;
        }
    }

    Process {
        id: wifiConnectProc
        running: false
        property string errorText: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.indexOf("successfully") === -1) {
                    wifiConnectProc.errorText += text;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text) {
                    wifiConnectProc.errorText += text;
                }
            }
        }
        onExited: (code, status) => {
            console.log("[WiFi Connect] Finished with code: " + code + " error: " + wifiConnectProc.errorText);
            if (code === 0) {
                shell.wifiLastError = "";
                shell.wifiConnectionState = "Connected";
                shell.sysNotify("Network", "Wi-Fi Connected", "Successfully connected to '" + shell.wifiSelectedSsid + "'.");
                if (!wifiProfilesProc.running) {
                    wifiProfilesProc.running = true;
                }
            } else {
                var err = wifiConnectProc.errorText.trim();
                var friendlyError = "Connection failed";
                var lowerText = err.toLowerCase();
                if (lowerText.indexOf("secrets were required") !== -1 || 
                    lowerText.indexOf("no secrets provided") !== -1 || 
                    lowerText.indexOf("bad-secrets") !== -1) {
                    friendlyError = "Incorrect password";
                    wifiForgetProc.command = ["nmcli", "connection", "delete", "id", shell.wifiSelectedSsid];
                    wifiForgetProc.running = true;
                } else if (lowerText.indexOf("no network") !== -1 || 
                           lowerText.indexOf("not found") !== -1 || 
                           lowerText.indexOf("unavailable") !== -1) {
                    friendlyError = "Network unavailable";
                } else if (lowerText.indexOf("timeout") !== -1) {
                    friendlyError = "Connection timeout";
                } else if (lowerText.indexOf("authentication") !== -1 || 
                           lowerText.indexOf("auth") !== -1) {
                    friendlyError = "Authentication failed";
                }
                shell.wifiLastError = friendlyError;
                shell.wifiConnectionState = "Failed";
                shell.sysNotify("Network", "Connection Failed", friendlyError + " for '" + shell.wifiSelectedSsid + "'.");
                wifiErrorClearTimer.restart();
            }
            wifiConnectProc.errorText = "";
            wifiProc.running = false;
            wifiProc.running = true;
        }
    }

    Process {
        id: btConnectProc
        running: false
        property string targetMac: ""
        property string targetName: ""
        onExited: (code, status) => {
            console.log("[Bluetooth Connect] Finished with code: " + code);
            if (code === 0) {
                shell.sysNotify("Bluetooth", "Device Connected", "Successfully connected to '" + targetName + "'.");
            } else {
                shell.sysNotify("Bluetooth", "Connection Failed", "Could not connect to '" + targetName + "'.");
            }
        }
    }

    Process {
        id: hyprglassProc
        running: false
        onExited: (code, status) => {
            console.log("[Hyprglass] Plugin load/unload finished with code: " + code);
        }
    }

    property bool _lastCompositorRulesActive: false
    property bool _lastHyprglassLoaded: false

    function applyCompositorRules() {
        if (!Settings.isLoaded) return;
        var isHyprglass = Settings.data.colorSchemes.hyprglass;
        var blurActive = isHyprglass;

        if (isHyprglass === _lastHyprglassLoaded && blurActive === _lastCompositorRulesActive) {
            return;
        }

        _lastHyprglassLoaded = isHyprglass;
        _lastCompositorRulesActive = blurActive;

        hyprglassProc.running = false;
        var cmd = "";
        if (isHyprglass) {
            cmd = "hyprctl plugin load " + Quickshell.env("HOME") + "/hyprglass/hyprglass.so";
        } else {
            cmd = "hyprctl plugin unload " + Quickshell.env("HOME") + "/hyprglass/hyprglass.so";
        }

        if (blurActive) {
            cmd += " && hyprctl keyword layerrule 'blur, morphing-island' && hyprctl keyword layerrule 'ignorezero, morphing-island'";
        } else {
            cmd += " && hyprctl keyword layerrule 'unset, morphing-island'";
        }

        hyprglassProc.command = ["bash", "-c", cmd];
        hyprglassProc.running = true;
    }

    Connections {
        target: Settings
        function onIsLoadedChanged() {
            if (Settings.isLoaded) {
                shell.applyCompositorRules();
            }
        }
    }

    Connections {
        target: Settings.data.colorSchemes
        function onHyprglassChanged() {
            shell.applyCompositorRules();
        }
    }

    property bool wifiFirstScan: true
    ListModel { id: wifiListModel }

    Process {
        id: wifiProfilesProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var profiles = {};
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    var parts = line.split(":");
                    if (parts.length >= 2) {
                        var name = parts[0];
                        var type = parts[1];
                        if (type === "802-11-wireless") {
                            profiles[name] = true;
                        }
                    }
                }
                shell.savedWifiProfiles = profiles;
            }
        }
    }

    Process {
        id: wifiScanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", wifiFirstScan ? "no" : "yes"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                wifiListModel.clear();
                var lines = text.split("\n");
                var connectedFound = false;
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    var parts = line.split(":");
                    if (parts.length >= 4) {
                        var inUse = parts[0] === "*";
                        var ssid = parts[1];
                        var signal = parts[2];
                        var security = parts[3];
                        if (ssid) {
                            if (inUse || (shell.wifiConnected && ssid === shell.wifiSSID)) {
                                shell.connectedWifiSignal = signal;
                                shell.connectedWifiSecurity = security;
                                connectedFound = true;
                            } else {
                                wifiListModel.append({
                                    "inUse": false,
                                    "ssid": ssid,
                                    "signal": signal,
                                    "security": security
                                });
                            }
                        }
                    }
                }
                wifiFirstScan = true; // Default back to cached scans
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                wifiFirstScan = true;
            }
        }
    }
    Timer {
        id: wifiScanTimer
        interval: 12000 // 12 seconds instead of 4 seconds to reduce CPU overhead
        repeat: true
        running: shell.currentState === 8
        onTriggered: {
            if (!wifiScanProc.running) {
                wifiScanProc.running = true;
            }
        }
        onRunningChanged: {
            if (running) {
                wifiFirstScan = true; // Use cache instantly when menu is opened
                if (!wifiScanProc.running) {
                    wifiScanProc.running = true;
                }
                if (!wifiProfilesProc.running) {
                    wifiProfilesProc.running = true;
                }
            }
        }
    }

    Process {
        id: wifiMonitorProc
        command: ["nmcli", "-t", "monitor"]
        running: shell.currentState === 8
        stdout: SplitParser {
            onRead: function(line) {
                if (!wifiProc.running) {
                    wifiProc.running = true;
                }
                if (!wifiScanProc.running) {
                    wifiFirstScan = true;
                    wifiScanProc.running = true;
                }
            }
        }
    }

        // Bluetooth Discovery (Scan)
    Process {
        id: btDiscoveryProc
        command: ["bluetoothctl", "scan", "on"]
        running: shell.currentState === 9 && shell.btPowered
    }

    // Bluetooth Scanning
    ListModel { id: btListModel }
    Process {
        id: btScanProc
        command: ["bluetoothctl", "devices"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                btListModel.clear();
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    var parts = line.split(" ");
                    if (parts.length >= 3 && parts[0] === "Device") {
                        var mac = parts[1];
                        var name = parts.slice(2).join(" ");
                        btListModel.append({
                            "mac": mac,
                            "name": name
                        });
                    }
                }
            }
        }
    }
    Timer {
        id: btScanTimer
        interval: 4000
        repeat: true
        running: shell.currentState === 9
        onTriggered: {
            if (!btScanProc.running) {
                btScanProc.running = true;
            }
        }
        onRunningChanged: {
            if (running) {
                if (!btScanProc.running) {
                    btScanProc.running = true;
                }
            }
        }
    }

    // ── Power Actions ────────────────────────────────────────────────────
    Process { id: lockProc; running: false }
    Process { id: powerProc; running: false }
    Process { id: appLaunchProc; running: false }

    // ── Wallpaper Folder Picker ───────────────────────────────────────────
    property string _pickedFolderOutput: ""
    Process {
        id: folderPickerProc
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                var trimmed = line.trim();
                if (trimmed !== "") {
                    shell._pickedFolderOutput = trimmed;
                }
            }
        }
        onExited: function(code, status) {
            if (code === 0 && shell._pickedFolderOutput !== "") {
                var screenName = Quickshell.screens[0].name;
                var newDir = shell._pickedFolderOutput;

                // 1. Clear monitor wallpaper cache (lists, active wallpaper, used random list, and saves to file)
                WallpaperService.clearMonitorWallpaperCache(screenName);

                // 2. Change the directory (persists to settings)
                Settings.data.wallpaper.directory = newDir;
                WallpaperService.setMonitorDirectory(screenName, newDir);

                // 3. Force a fresh scan so the grid updates immediately
                WallpaperService.refreshWallpapersList();

                shell._pickedFolderOutput = "";
            }
        }
    }


    function doLock() { shell.locked = true; }
    function doSuspend() { powerProc.command = ["systemctl", "suspend"]; powerProc.running = true; }
    function doLogout() { powerProc.command = ["hyprctl", "dispatch", "exit"]; powerProc.running = true; }
    function doReboot() { powerProc.command = ["systemctl", "reboot"]; powerProc.running = true; }
    function doPoweroff() { powerProc.command = ["systemctl", "poweroff"]; powerProc.running = true; }

    // ── OSD auto-dismiss ─────────────────────────────────────────────────
    Timer {
        id: osdTimer; interval: 1500
        onTriggered: { if (shell.currentState === 2) shell.setState(0); }
    }

    // ── Settings & App Launcher Logic ────────────────────────────────────
    FileView {
        id: recentAppsFile
        path: Qt.resolvedUrl("recent_apps.txt")
        
        onLoaded: {
            if (text === "") {
                setText("firefox.desktop,kitty.desktop,nautilus.desktop");
            }
            shell.updateFilteredApps();
        }
        
        onLoadFailed: error => {
            setText("firefox.desktop,kitty.desktop,nautilus.desktop");
            shell.updateFilteredApps();
        }
    }

    property string searchQuery: ""
    property var filteredAppsList: []

    onCurrentStateChanged: {
        if (currentState === 4) {
            searchQuery = "";
            updateFilteredApps();
        }
        if (currentState === 1) {
            refreshBrightness();
        }
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
        function onValuesChanged() {
            shell.updateFilteredApps();
        }
    }

    function getAllApplications() {
        if (typeof DesktopEntries === 'undefined' || !DesktopEntries.applications) {
            return [];
        }
        var apps = [];
        var rawValues = DesktopEntries.applications.values;
        if (!rawValues) return [];
        
        var values = [];
        try {
            values = Array.from(rawValues);
        } catch (e) {
            values = rawValues;
        }
        
        for (var i = 0; i < values.length; i++) {
            var app = values[i];
            if (app && app.name && !app.noDisplay) {
                apps.push(app);
            }
        }
        return apps;
    }

    function getFilteredApps(query) {
        var allApps = getAllApplications();
        var recentIds = recentAppsFile.text().split(",").filter(function(x) { return x !== ""; });
        var queryLower = query.toLowerCase().trim();
        
        var filtered = allApps.filter(function(app) {
            if (!app || !app.name) return false;
            if (queryLower === "") return true;
            
            var nameMatch = app.name.toLowerCase().indexOf(queryLower) !== -1;
            var idMatch = app.id && app.id.toLowerCase().indexOf(queryLower) !== -1;
            var genericMatch = app.genericName && app.genericName.toLowerCase().indexOf(queryLower) !== -1;
            
            return nameMatch || idMatch || genericMatch;
        });
        
        // Normalize recentIds for robust extension-agnostic matching
        var normalizedRecent = recentIds.map(function(x) { 
            return x.toLowerCase().trim().replace(/\.desktop$/, ""); 
        });
        
        filtered.sort(function(a, b) {
            var idA = a.id ? a.id.toLowerCase().replace(/\.desktop$/, "") : "";
            var idB = b.id ? b.id.toLowerCase().replace(/\.desktop$/, "") : "";
            
            var idxA = normalizedRecent.indexOf(idA);
            var idxB = normalizedRecent.indexOf(idB);
            
            var hasA = idxA !== -1;
            var hasB = idxB !== -1;
            
            if (hasA && !hasB) return -1;
            if (!hasA && hasB) return 1;
            if (hasA && hasB) return idxA - idxB;
            
            return a.name.localeCompare(b.name);
        });
        
        return filtered;
    }

    function recordAppLaunch(appId) {
        if (!appId) return;
        var list = recentAppsFile.text().split(",").filter(function(x) { return x !== ""; });
        var index = list.indexOf(appId);
        if (index !== -1) {
            list.splice(index, 1);
        }
        list.unshift(appId);
        if (list.length > 12) {
            list = list.slice(0, 12);
        }
        recentAppsFile.setText(list.join(","));
        updateFilteredApps();
    }

    function updateFilteredApps() {
        filteredAppsList = getFilteredApps(searchQuery);
        console.log("[Launcher Debug] Query:", searchQuery, "Total apps found:", getAllApplications().length, "Filtered list size:", filteredAppsList.length);
    }



    // =========================================================================
    // THE ISLAND WINDOW
    // =========================================================================
    // Exclusion Zone Window to reserve space at the top of the screen (windows open below this)
    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            color: "transparent"
            mask: Region {}

            WlrLayershell.namespace: "morphing-island-exclusion"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Auto
            
            anchors { top: true; left: true; right: true }
            implicitHeight: 33
        }
    }

    // Night Light Overlay Window to apply a warm filter over the screen
    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            color: "transparent"
            mask: Region {} // Completely click-through

            WlrLayershell.namespace: "morphing-island-nightlight"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors { top: true; bottom: true; left: true; right: true }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.85, 0.48, 0.0, 0.12)
                opacity: shell.nightMode ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
            }
        }
    }

    // Main UI Window for the Morphing Pill / Control Center
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow
            property var modelData
            screen: modelData
            color: "transparent"
            property var shellRootObj: shell

            // Workspace tracking and indicator properties
            property int workspaceId: 1
            property bool isSystemReady: false
            property bool workspaceCircleActive: false

            Connections {
                target: Hyprland
                function onFocusedWorkspaceChanged() {
                    var monitor = panelWindow.screen ? Hyprland.monitorFor(panelWindow.screen) : null;
                    var newId = 1;
                    if (monitor && monitor.focusedWorkspace) {
                        newId = monitor.focusedWorkspace.id;
                    } else if (Hyprland.focusedWorkspace) {
                        newId = Hyprland.focusedWorkspace.id;
                    }
                    panelWindow.workspaceId = newId;
                }
            }

            Component.onCompleted: {
                var monitor = panelWindow.screen ? Hyprland.monitorFor(panelWindow.screen) : null;
                var initialId = 1;
                if (monitor && monitor.focusedWorkspace) {
                    initialId = monitor.focusedWorkspace.id;
                } else if (Hyprland.focusedWorkspace) {
                    initialId = Hyprland.focusedWorkspace.id;
                }
                panelWindow.workspaceId = initialId;
            }

            Timer {
                id: systemReadyTimer
                interval: 800
                running: true
                onTriggered: panelWindow.isSystemReady = true
            }

            onWorkspaceIdChanged: {
                if (isSystemReady && !mainHoverArea.containsMouse && shell.currentState === 0) {
                    workspaceTimer.stop();
                    workspaceCircleActive = true;
                    workspaceTimer.restart();
                }
            }

            Connections {
                target: mainHoverArea
                function onContainsMouseChanged() {
                    if (mainHoverArea.containsMouse) {
                        panelWindow.workspaceCircleActive = false;
                        workspaceTimer.stop();
                    }
                }
            }

            Connections {
                target: shell
                function onCurrentStateChanged() {
                    if (shell.currentState !== 0) {
                        panelWindow.workspaceCircleActive = false;
                        workspaceTimer.stop();
                    }
                }
            }

            Timer {
                id: workspaceTimer
                interval: 350
                onTriggered: {
                    panelWindow.workspaceCircleActive = false;
                }
            }

            // Animated actual values for the workspace circle
            property real wsCircleWidth: 30
            property real wsCircleSpacing: workspaceCircleActive ? 8 : -38
            property real wsCircleOpacity: 1.0
            property real wsCircleScale: 1.0

            Behavior on wsCircleSpacing { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }

            WlrLayershell.namespace: "morphing-island"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: (shell.currentState === 13) ? WlrKeyboardFocus.Exclusive : ((shell.currentState !== 0 && shell.currentState !== 1 && shell.currentState !== 2 && shell.currentState !== 3) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
            anchors { top: true; left: true; right: true }
            implicitHeight: 720

            property real targetMaskWidth: island ? (island.islandWidth + (workspaceCircleActive ? (30 + 8) : 0)) : 110
            property real targetMaskHeight: island ? Math.max(island.islandHeight, workspaceCircleActive ? 30 : 0) : 30

            property real maskWidth: 110
            property real maskHeight: 30

            Timer {
                id: maskDelayTimer
                interval: shell.animNormal + 20
                repeat: false
                onTriggered: {
                    panelWindow.maskWidth = panelWindow.targetMaskWidth;
                    panelWindow.maskHeight = panelWindow.targetMaskHeight;
                    if (typeof islandRegion !== "undefined") islandRegion.changed();
                }
            }

            onTargetMaskWidthChanged: panelWindow.updateMask()
            onTargetMaskHeightChanged: panelWindow.updateMask()

            function updateMask() {
                var tw = targetMaskWidth;
                var th = targetMaskHeight;
                if (tw > maskWidth || th > maskHeight) {
                    maskDelayTimer.stop();
                    maskWidth = tw;
                    maskHeight = th;
                    if (typeof islandRegion !== "undefined") islandRegion.changed();
                } else if (tw < maskWidth || th < maskHeight) {
                    maskDelayTimer.restart();
                } else {
                    maskDelayTimer.stop();
                }
            }

            // Non-animated mask item — snaps to target size instantly so the
            // compositor input-region doesn't update every animation frame.
            Item {
                id: islandMask
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 6
                width: panelWindow.maskWidth
                height: panelWindow.maskHeight
            }

            mask: Region {
                id: islandRegion
                item: islandMask
            }

            HyprlandFocusGrab {
                active: shell.currentState > 1 && shell.currentState !== 13
                windows: [ panelWindow ]
                onCleared: {
                    console.log("[Focus Grab Debug] Focus grab cleared. Current state: " + shell.currentState);
                    shell.setState(0);
                }
            }


            // Drop Shadow for the floating pill
            Rectangle {
                id: islandShadowSource
                width: island.width
                height: island.height
                anchors.horizontalCenter: island.horizontalCenter
                anchors.top: island.top
                radius: island.radius
                color: "black"
                visible: false
            }

            MultiEffect {
                source: islandShadowSource
                anchors.fill: islandShadowSource
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.4)
                shadowBlur: 0.65
                shadowVerticalOffset: shell.currentState === 0 ? 2 : 6
                shadowHorizontalOffset: 0
                opacity: shell.currentState === 0 ? 0.45 : 1.0
                visible: !Settings.data.colorSchemes.hyprglass
                Behavior on opacity { NumberAnimation { duration: shell.animFast } }
                Behavior on shadowVerticalOffset { NumberAnimation { duration: shell.animFast } }
            }

            Rectangle {
                id: island
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: -((panelWindow.wsCircleSpacing + panelWindow.wsCircleWidth) / 2)
                anchors.top: parent.top
                anchors.topMargin: 6
                color: "transparent"
                property real islandRadius: {
                    switch (shell.currentState) {
                        case 0: return 15;
                        case 1: return 22;
                        case 2: return 16;
                        default: return 24;
                    }
                }
                radius: islandRadius
                clip: true

                LiquidGlassBackground {
                    id: liquidGlassBg
                    anchors.fill: parent
                    radius: island.radius
                    surfaceColor: shell.surface
                    accentColor: shell.accent
                    borderColor: shell.surfaceBorder
                    active: Settings.isLoaded && Settings.data.colorSchemes.hyprglass
                }

                focus: true
                Component.onCompleted: {
                    shell.currentStateChanged.connect(function() {
                        if (shell.currentState > 1 && shell.currentState !== 4 && shell.currentState !== 15 && shell.currentState !== 16) {
                            island.forceActiveFocus();
                        }
                    });
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                        if (shell.currentState === 5) { shell.setState(4); event.accepted = true; }
                        else if (shell.currentState === 4) { shell.setState(6); event.accepted = true; }
                        else if (shell.currentState === 6) { shell.setState(5); event.accepted = true; }
                        else if (shell.currentState <= 1) { shell.setState(5); event.accepted = true; }
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                        if (shell.currentState === 5) { shell.setState(6); event.accepted = true; }
                        else if (shell.currentState === 6) { shell.setState(4); event.accepted = true; }
                        else if (shell.currentState === 4) { shell.setState(5); event.accepted = true; }
                        else if (shell.currentState <= 1) { shell.setState(6); event.accepted = true; }
                    } else if (event.key === Qt.Key_Escape) {
                        shell.setState(0);
                        event.accepted = true;
                    }
                }

                property real islandWidth: {
                    switch (shell.currentState) {
                        case 0: return 110;
                        case 1: return 380;
                        case 2: return 230;
                        case 3: return 400;
                        case 4: return 445;
                        case 5: return 440;
                        case 6: return 440;
                        case 7: return 340;
                        case 8: return shell.wifiShowPasswordInput ? 360 : 440;
                        case 9: return 440;
                        case 10: return 445;
                        case 11: return 445;
                        case 12: return 440;
                        case 13: return 440;
                        case 14: return 440;
                        case 15: return 440;
                        case 16: return 440;
                        default: return 110;
                    }
                }
                property real islandHeight: {
                    switch (shell.currentState) {
                        case 0: return 30;
                        case 1: return 44;
                        case 2: return 32;
                        case 3: return 76;
                        case 4: return 440;
                        case 5: return Math.min(680, (typeof ccColumn !== "undefined" ? ccColumn.height + 28 : 590));
                        case 6: return 90;
                        case 7: return 200;
                        case 8: return shell.wifiShowPasswordInput ? 92 : Math.min(680, (typeof wifiCol !== "undefined" ? wifiCol.height + 28 : 350));
                        case 9: return Math.min(680, (typeof btCol !== "undefined" ? btCol.height + 28 : 350));
                        case 10: return 330;
                        case 11: return Math.min(680, (typeof customPaletteCol !== "undefined" ? customPaletteCol.height + 28 : 530));
                        case 12: return Math.min(680, (typeof personalizationCol !== "undefined" ? personalizationCol.height + 28 : 350));
                        case 13: return Math.min(680, (typeof clipboardCol !== "undefined" ? clipboardCol.height + 28 : 350));
                        case 14: return Math.min(680, (typeof screenToolkitCol !== "undefined" ? screenToolkitCol.height + 28 : 450));
                        case 15: return Math.min(680, (typeof emojiCol !== "undefined" ? emojiCol.height + 28 : 350));
                        case 16: return Math.min(680, (typeof keybindCol !== "undefined" ? keybindCol.height + 28 : 220));
                        default: return 30;
                    }
                }

                width: islandWidth; height: islandHeight
                Behavior on width  { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutQuart } }
                Behavior on height { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutQuart } }
                Behavior on radius { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutQuart } }

                // =============================================================
                // STATE 0: IDLE
                // =============================================================
                Item {
                    anchors.fill: parent
                    opacity: shell.currentState === 0 ? 1 : 0; scale: shell.currentState === 0 ? 1 : 0.92; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 0

                        // EQ Visualizer Container that slides out / collapses
                        Item {
                            id: eqVisualizerContainer
                            height: 12
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true
                            width: shell.mediaPlaying ? 18.5 : 0
                            opacity: shell.mediaPlaying ? 1 : 0

                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                            Row {
                                id: eqVisualizer
                                spacing: 1.5
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter

                                Repeater {
                                    model: [
                                        { h1: 10, h2: 3, d1: 340, d2: 400 },
                                        { h1: 6,  h2: 8,  d1: 420, d2: 320 },
                                        { h1: 12, h2: 2,  d1: 280, d2: 440 },
                                        { h1: 8,  h2: 5,  d1: 380, d2: 360 }
                                    ]
                                    Item {
                                        width: 2; height: 12
                                        Rectangle {
                                            width: 2; radius: 1; color: shell.accent
                                            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                            height: shell.mediaPlaying ? 5 : 2
                                            SequentialAnimation on height {
                                                loops: Animation.Infinite; running: shell.mediaPlaying
                                                NumberAnimation { to: modelData.h1; duration: modelData.d1; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: modelData.h2; duration: modelData.d2; easing.type: Easing.InOutSine }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            id: idleClock; text: shell.currentTime12h
                            color: shell.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 0.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // =============================================================
                // STATE 1: EXPANDED
                // =============================================================
                Item {
                    anchors.fill: parent
                    opacity: shell.currentState === 1 ? 1 : 0; scale: shell.currentState === 1 ? 1 : 0.92; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16

                        // LEFT — Media info
                        Item {
                            width: parent.width * 0.3; height: parent.height
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                height: 12
                                Row {
                                    id: innerEqVisualizer
                                    spacing: 1.5
                                    anchors.bottom: parent.bottom

                                    Repeater {
                                        model: [
                                            { h1: 10, h2: 3, d1: 340, d2: 400 },
                                            { h1: 6,  h2: 8,  d1: 420, d2: 320 },
                                            { h1: 12, h2: 2,  d1: 280, d2: 440 },
                                            { h1: 8,  h2: 5,  d1: 380, d2: 360 }
                                        ]
                                        Item {
                                            width: 2; height: 12
                                            Rectangle {
                                                width: 2; radius: 1; color: shell.accent
                                                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                                height: shell.mediaPlaying ? 5 : 2
                                                SequentialAnimation on height {
                                                    loops: Animation.Infinite; running: shell.mediaPlaying
                                                    NumberAnimation { to: modelData.h1; duration: modelData.d1; easing.type: Easing.InOutSine }
                                                    NumberAnimation { to: modelData.h2; duration: modelData.d2; easing.type: Easing.InOutSine }
                                                }
                                            }
                                        }
                                    }
                                }
                                Text {
                                    text: shell.mediaPlaying ? "Playing" : "Paused"
                                    color: shell.textMuted; font.pixelSize: 10; font.weight: Font.Medium
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -2
                                }
                            }
                        }

                        // CENTER — Clock
                        Item {
                            width: parent.width * 0.4; height: parent.height
                            Text {
                                id: heroClock; anchors.centerIn: parent
                                text: shell.currentTime12h
                                color: shell.textPrimary; font.pixelSize: 16; font.weight: Font.Bold; font.letterSpacing: 1.5
                            }
                        }

                        // RIGHT — Status
                        Item {
                            width: parent.width * 0.3; height: parent.height
                            Row {
                                anchors.centerIn: parent; spacing: 10

                                // Network connection type indicator (Wi-Fi or Ethernet)
                                Image {
                                    width: shell.ethConnected ? 18 : 14
                                    height: shell.ethConnected ? 18 : 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: shell.ethConnected ? "icons/ethernet.png" : "icons/wifi.png"
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        brightness: 1.0
                                        colorization: 1.0
                                        colorizationColor: (shell.ethConnected || shell.wifiConnected) ? shell.accent : shell.textMuted
                                    }
                                }

                                // Battery
                                Item {
                                    width: 26; height: 12; anchors.verticalCenter: parent.verticalCenter
                                    visible: shell.batteryPercent >= 0

                                    Rectangle {
                                        width: 24; height: 12; radius: 3; color: "transparent"
                                        border.width: 1.5; border.color: shell.textMuted
                                        Rectangle {
                                            x: 2.5; y: 2.5
                                            width: (parent.width - 5) * Math.max(0, Math.min(1, shell.batteryPercent / 100))
                                            height: parent.height - 5; radius: 1.5
                                            color: shell.batteryPercent < 20 ? shell.red : (shell.batteryCharging ? shell.green : shell.accent)
                                        }
                                    }
                                    Rectangle { x: 24; y: 3; width: 2; height: 6; radius: 1; color: shell.textMuted }
                                }

                                Text {
                                    text: shell.batteryPercent >= 0 ? Math.round(shell.batteryPercent) + "%" : ""
                                    color: shell.textMuted; font.pixelSize: 10; font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STATE 2: OSD
                // =============================================================
                Item {
                    anchors.fill: parent
                    opacity: shell.currentState === 2 ? 1 : 0; scale: shell.currentState === 2 ? 1 : 0.92; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.centerIn: parent; spacing: 12

                        // Icon
                        Image {
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            source: "icons/volume.png"
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                brightness: 1.0
                                colorization: 1.0
                                colorizationColor: shell.sysMuted ? shell.textMuted : shell.accent
                            }
                        }

                        // Level bar
                        Rectangle {
                            width: 150; height: 5; radius: 2.5; color: shell.surfaceBright
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: parent.width * (shell.sysMuted ? 0 : shell.sysVolume)
                                height: parent.height; radius: parent.radius; color: shell.accent
                                Behavior on width { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }
                            }
                        }


                    }
                }

                // =============================================================
                // STATE 3: NOTIFICATION (shows latest)
                // =============================================================
                Item {
                    anchors.fill: parent
                    height: 76
                    opacity: shell.currentState === 3 ? 1 : 0; scale: shell.currentState === 3 ? 1 : 0.92; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.setState(0)
                    }

                    Row {
                        anchors.fill: parent; anchors.margins: 12; spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 11; anchors.verticalCenter: parent.verticalCenter
                            color: shell.accentDim

                            Image {
                                anchors.centerIn: parent
                                width: 20; height: 20
                                source: "icons/notification.png"
                                fillMode: Image.PreserveAspectFit
                                visible: {
                                    if (shell.notifHistory.count === 0) return true;
                                    var item = shell.notifHistory.get(0);
                                    return item ? item.appName.toLowerCase() !== "power" : true;
                                }
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    brightness: 1.0
                                    colorization: 1.0
                                    colorizationColor: shell.accent
                                }
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 20; height: 20
                                source: "icons/power.png"
                                fillMode: Image.PreserveAspectFit
                                visible: {
                                    if (shell.notifHistory.count === 0) return false;
                                    var item = shell.notifHistory.get(0);
                                    return item ? item.appName.toLowerCase() === "power" : false;
                                }
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    brightness: 1.0
                                    colorization: 1.0
                                    colorizationColor: shell.accent
                                }
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            width: parent.width - 48

                            Text {
                                text: shell.notifHistory.count > 0 ? shell.notifHistory.get(0).appName : ""
                                color: shell.textMuted; font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 0.3
                            }
                            Text {
                                text: shell.notifHistory.count > 0 ? shell.notifHistory.get(0).summary : ""
                                color: shell.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold
                                elide: Text.ElideRight; width: parent.width
                            }
                            Text {
                                text: shell.notifHistory.count > 0 ? shell.notifHistory.get(0).body : ""
                                color: shell.textSecondary; font.pixelSize: 11
                                elide: Text.ElideRight; width: parent.width
                            }
                        }
                    }
                }

                // =============================================================
                // STATE 4: APP LAUNCHER
                // =============================================================
                Item {
                    id: launcherView; anchors.fill: parent
                    opacity: shell.currentState === 4 ? 1 : 0; scale: shell.currentState === 4 ? 1 : 0.96; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }

                    property int selectedAppIndex: 0
                    property bool hasQuery: (typeof searchInput !== "undefined" && searchInput) ? (searchInput.text.length > 0) : false

                    onVisibleChanged: {
                        if (visible) {
                            searchInput.text = "";
                            selectedAppIndex = 0;
                            Qt.callLater(() => searchInput.forceActiveFocus());
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.setState(0)
                    }

                    // Hidden search input with local geometry to ensure focus support in QML scene graph
                    TextInput {
                        id: searchInput
                        x: 0; y: 0
                        width: 10; height: 10
                        opacity: 0; visible: true
                        focus: true
                        
                        Keys.onEscapePressed: {
                            searchInput.text = "";
                            panelWindow.shellRootObj.setState(0);
                        }
                        
                        onTextChanged: {
                            panelWindow.shellRootObj.searchQuery = text;
                            panelWindow.shellRootObj.updateFilteredApps();
                            launcherView.selectedAppIndex = 0;
                        }
                        
                         onAccepted: {
                            var list = panelWindow.shellRootObj.filteredAppsList;
                            var idx = launcherView.selectedAppIndex;
                            if (list.length > 0 && idx >= 0 && idx < list.length) {
                                var app = list[idx];
                                panelWindow.shellRootObj.recordAppLaunch(app.id);
                                if (typeof app.execute === 'function') {
                                    app.execute();
                                } else if (app.command && app.command.length > 0) {
                                    var cleanCmd = app.command.filter(function(arg) { return arg && arg.indexOf("%") !== 0; });
                                    Quickshell.execDetached(cleanCmd);
                                }
                                panelWindow.shellRootObj.setState(0);
                            }
                        }
                        
                        Keys.onReturnPressed: {
                            var list = panelWindow.shellRootObj.filteredAppsList;
                            var idx = launcherView.selectedAppIndex;
                            if (list.length > 0 && idx >= 0 && idx < list.length) {
                                var app = list[idx];
                                panelWindow.shellRootObj.recordAppLaunch(app.id);
                                if (typeof app.execute === 'function') {
                                    app.execute();
                                } else if (app.command && app.command.length > 0) {
                                    var cleanCmd = app.command.filter(function(arg) { return arg && arg.indexOf("%") !== 0; });
                                    Quickshell.execDetached(cleanCmd);
                                }
                                panelWindow.shellRootObj.setState(0);
                            }
                        }

                        Keys.onPressed: event => {
                            if (searchInput.text.length === 0) {
                                if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                                    panelWindow.shellRootObj.setState(6);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                                    panelWindow.shellRootObj.setState(5);
                                    event.accepted = true;
                                }
                            } else {
                                var listLen = panelWindow.shellRootObj.filteredAppsList.length;
                                if (listLen > 0) {
                                    if (event.key === Qt.Key_Right) {
                                        launcherView.selectedAppIndex = Math.min(launcherView.selectedAppIndex + 1, listLen - 1);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Left) {
                                        launcherView.selectedAppIndex = Math.max(launcherView.selectedAppIndex - 1, 0);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Down) {
                                        launcherView.selectedAppIndex = Math.min(launcherView.selectedAppIndex + 5, listLen - 1);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Up) {
                                        launcherView.selectedAppIndex = Math.max(launcherView.selectedAppIndex - 5, 0);
                                        event.accepted = true;
                                    }
                                }
                            }
                        }
                    }

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 12
                        contentHeight: appsGrid.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Grid {
                            id: appsGrid
                            columns: 5; spacing: 8; width: parent.width

                            Repeater {
                                model: shell.filteredAppsList

                                 Rectangle {
                                     id: appCard
                                     property var appData: modelData
                                     width: (parent.width - 32) / 5
                                     height: width; radius: 16
                                     color: (lma.containsMouse || (launcherView.hasQuery && index === launcherView.selectedAppIndex)) ? shell.surfaceBright : shell.surfaceAlt
                                     Behavior on color { ColorAnimation { duration: shell.animFast } }
                                      
                                      

                                     Item {
                                         anchors.fill: parent
                                         anchors.margins: 8

                                         Image {
                                             id: appIcon
                                             width: 36; height: 36
                                             anchors.horizontalCenter: parent.horizontalCenter
                                             y: (lma.containsMouse || (launcherView.hasQuery && index === launcherView.selectedAppIndex)) ? 6 : (parent.height - height) / 2
                                             Behavior on y {
                                                  enabled: launcherView.opacity > 0.99
                                                  NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic }
                                              }
                                             fillMode: Image.PreserveAspectFit
                                             layer.enabled: shell.currentState === 4 && Settings.data.colorSchemes.themedIcons
                                             layer.effect: MultiEffect {
                                                 colorization: 1.0; colorizationColor: shell.accent
                                             }
                                             source: {
                                                 var path = "";
                                                 if (appCard.appData && appCard.appData.icon) {
                                                     if (typeof Quickshell !== 'undefined' && Quickshell.iconPath) {
                                                         path = Quickshell.iconPath(appCard.appData.icon, "application-x-executable");
                                                     }
                                                 }
                                                 if (path && path !== "") {
                                                     if (path.startsWith("file://") || path.startsWith("image://")) {
                                                         return path;
                                                     }
                                                     return "file://" + path;
                                                 }
                                                 return "";
                                             }
                                         }

                                         Text {
                                             id: appName
                                             text: appCard.appData ? appCard.appData.name : ""
                                             color: (lma.containsMouse || (launcherView.hasQuery && index === launcherView.selectedAppIndex)) ? shell.textPrimary : shell.textSecondary
                                             opacity: (lma.containsMouse || (launcherView.hasQuery && index === launcherView.selectedAppIndex)) ? 1.0 : 0.0
                                             scale: (lma.containsMouse || (launcherView.hasQuery && index === launcherView.selectedAppIndex)) ? 1.0 : 0.8
                                             Behavior on opacity { NumberAnimation { duration: shell.animFast } }
                                             Behavior on scale { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }

                                             font.pixelSize: 9
                                             font.weight: Font.Bold
                                             anchors.bottom: parent.bottom
                                             anchors.horizontalCenter: parent.horizontalCenter
                                             elide: Text.ElideRight
                                             width: parent.width
                                             horizontalAlignment: Text.AlignHCenter
                                         }
                                     }

                                     MouseArea {
                                         id: lma
                                          anchors.fill: parent
                                          hoverEnabled: true
                                          cursorShape: Qt.PointingHandCursor
                                           onEntered: launcherView.selectedAppIndex = index
                                          onClicked: {
                                              if (appCard.appData) {
                                                  panelWindow.shellRootObj.recordAppLaunch(appCard.appData.id);
                                                  if (typeof appCard.appData.execute === 'function') {
                                                      appCard.appData.execute();
                                                  } else if (appCard.appData.command && appCard.appData.command.length > 0) {
                                                      var cleanCmd = appCard.appData.command.filter(function(arg) { return arg && arg.indexOf("%") !== 0; });
                                                      Quickshell.execDetached(cleanCmd);
                                                  }
                                              }
                                              shell.setState(0);
                                          }
                                     }
                                 }
                             }
                        }
                    }
                }

                // =============================================================
                // STATE 5: CONTROL CENTER
                // =============================================================
                Item {
                    id: ccView; anchors.fill: parent
                    readonly property bool ccActive: shell.currentState === 5
                    opacity: ccActive ? 1 : 0; scale: ccActive ? 1 : 0.96; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.setState(0)
                    }

                    Flickable {
                        id: ccFlickable
                        anchors.fill: parent; anchors.margins: 14
                        contentHeight: ccColumn.height
                        contentWidth: width
                        contentX: 0
                        flickableDirection: Flickable.VerticalFlick
                        clip: true; boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: ccColumn; width: parent.width; spacing: 10

                            // Header
                            Row {
                                width: parent.width; spacing: 10
                                Item {
                                    width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.centerIn: parent; width: 20; height: 20
                                        source: "icons/back.png"
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: ccView.ccActive
                                        layer.effect: MultiEffect {
                                            brightness: 1.0
                                            colorization: 1.0
                                            colorizationColor: shell.textPrimary
                                        }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(0) }
                                }
                                Text { text: "Control Center"; color: shell.textPrimary; font.pixelSize: 16; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }

                            // Row 1: Wi-Fi + Audio
                            Row {
                                width: parent.width; spacing: 8

                                Rectangle {
                                    width: 130; height: 45; radius: 22.5
                                    color: wma.containsMouse ? shell.surfaceBright : (shell.wifiEnabled ? shell.accentDim : shell.surfaceAlt)
                                    border.width: shell.wifiEnabled ? 1 : 0
                                    border.color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2)

                                    Row {
                                        anchors.fill: parent; anchors.margins: 8; spacing: 8
                                        Rectangle {
                                            width: 28; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                                            color: shell.wifiEnabled ? shell.accent : shell.surfaceBright
                                            Image {
                                                anchors.centerIn: parent; width: 16; height: 16
                                                source: "icons/wifi.png"
                                                fillMode: Image.PreserveAspectFit
                                                layer.enabled: ccView.ccActive
                                                layer.effect: MultiEffect {
                                                    brightness: 1.0
                                                    colorization: 1.0
                                                    colorizationColor: shell.wifiEnabled ? shell.surface : shell.textMuted
                                                }
                                            }
                                        }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { text: "Wi-Fi"; color: shell.textPrimary; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            Text { text: shell.wifiEnabled ? (shell.wifiConnected ? shell.wifiSSID : "Disconnected") : "Off"; color: shell.textSecondary; font.pixelSize: 9; elide: Text.ElideRight; width: 70 }
                                        }
                                    }

                                    MouseArea {
                                        id: wma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shell.setState(8)
                                    }
                                }

                                Rectangle {
                                    width: parent.width - 130 - parent.spacing; height: 45; radius: 22.5
                                    color: audma.containsMouse ? shell.surfaceBright : (!shell.sysMuted ? shell.accentDim : shell.surfaceAlt)
                                    border.width: !shell.sysMuted ? 1 : 0
                                    border.color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2)

                                    Row {
                                        anchors.fill: parent; anchors.margins: 8; spacing: 8
                                        Rectangle {
                                            width: 28; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                                            color: !shell.sysMuted ? shell.accent : shell.surfaceBright
                                            Image {
                                                anchors.centerIn: parent; width: 16; height: 16
                                                source: "icons/volume.png"
                                                fillMode: Image.PreserveAspectFit
                                                layer.enabled: ccView.ccActive
                                                layer.effect: MultiEffect {
                                                    brightness: 1.0
                                                    colorization: 1.0
                                                    colorizationColor: !shell.sysMuted ? shell.surface : shell.textMuted
                                                }
                                            }
                                        }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { text: "Audio"; color: shell.textPrimary; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            Text { text: shell.sysMuted ? "Muted" : Math.round(shell.sysVolume * 100) + "%"; color: shell.textSecondary; font.pixelSize: 9 }
                                        }
                                    }

                                    MouseArea {
                                        id: audma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shell.toggleMute()
                                    }
                                }
                            }

                            // Row 2: Bluetooth + Peace + Night Light
                            Row {
                                width: parent.width; spacing: 8

                                Rectangle {
                                    id: btBtn
                                    width: Math.floor((parent.width - (parent.spacing * 2)) / 3); height: 45; radius: 22.5
                                    color: bta.containsMouse ? shell.surfaceBright : (shell.btPowered ? shell.accentDim : shell.surfaceAlt)
                                    border.width: shell.btPowered ? 1 : 0
                                    border.color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2)

                                    Row {
                                        anchors.fill: parent; anchors.margins: 8; spacing: 6
                                        Rectangle {
                                            width: 26; height: 26; radius: 13; color: shell.btPowered ? shell.accent : shell.surfaceBright; anchors.verticalCenter: parent.verticalCenter
                                            Image {
                                                anchors.centerIn: parent; width: 14; height: 14
                                                source: "icons/bluetooth.png"
                                                fillMode: Image.PreserveAspectFit
                                                layer.enabled: ccView.ccActive
                                                layer.effect: MultiEffect {
                                                    brightness: 1.0
                                                    colorization: 1.0
                                                    colorizationColor: shell.btPowered ? shell.surface : shell.textMuted
                                                }
                                            }
                                        }
                                        Column { anchors.verticalCenter: parent.verticalCenter; Text { text: "Bluetooth"; color: shell.textPrimary; font.pixelSize: 10; font.weight: Font.DemiBold } Text { text: shell.btPowered ? "On" : "Off"; color: shell.textMuted; font.pixelSize: 8 } }
                                    }

                                    MouseArea {
                                        id: bta
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shell.setState(9)
                                    }
                                }
                                Rectangle {
                                    id: peaceBtn
                                    width: Math.floor((parent.width - (parent.spacing * 2)) / 3); height: 45; radius: 22.5
                                    color: pea.containsMouse ? shell.surfaceBright : (shell.peaceMode ? shell.accentDim : shell.surfaceAlt)
                                    border.width: shell.peaceMode ? 1 : 0
                                    border.color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2)

                                    Row {
                                        anchors.fill: parent; anchors.margins: 8; spacing: 6
                                        Rectangle {
                                            width: 26; height: 26; radius: 13; color: shell.peaceMode ? shell.accent : shell.surfaceBright; anchors.verticalCenter: parent.verticalCenter
                                            Image {
                                                anchors.centerIn: parent; width: 14; height: 14
                                                source: "icons/peace(dnd).png"
                                                fillMode: Image.PreserveAspectFit
                                                layer.enabled: ccView.ccActive
                                                layer.effect: MultiEffect {
                                                    brightness: 1.0
                                                    colorization: 1.0
                                                    colorizationColor: shell.peaceMode ? shell.surface : shell.textMuted
                                                }
                                            }
                                        }
                                        Column { anchors.verticalCenter: parent.verticalCenter; Text { text: "Peace"; color: shell.textPrimary; font.pixelSize: 10; font.weight: Font.DemiBold } Text { text: shell.peaceMode ? "On" : "Off"; color: shell.textMuted; font.pixelSize: 8 } }
                                    }

                                    MouseArea {
                                        id: pea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shell.peaceMode = !shell.peaceMode
                                    }
                                }
                                Rectangle {
                                    width: parent.width - btBtn.width - peaceBtn.width - (parent.spacing * 2); height: 45; radius: 22.5
                                    color: nia.containsMouse ? shell.surfaceBright : (shell.nightMode ? shell.accentDim : shell.surfaceAlt)
                                    border.width: shell.nightMode ? 1 : 0
                                    border.color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2)

                                    Row {
                                        anchors.fill: parent; anchors.margins: 8; spacing: 6
                                        Rectangle {
                                            width: 26; height: 26; radius: 13; color: shell.nightMode ? shell.accent : shell.surfaceBright; anchors.verticalCenter: parent.verticalCenter
                                            Image {
                                                anchors.centerIn: parent; width: 14; height: 14
                                                source: "icons/night.png"
                                                fillMode: Image.PreserveAspectFit
                                                layer.enabled: ccView.ccActive
                                                layer.effect: MultiEffect {
                                                    brightness: 1.0
                                                    colorization: 1.0
                                                    colorizationColor: shell.nightMode ? shell.surface : shell.textMuted
                                                }
                                            }
                                        }
                                        Column { anchors.verticalCenter: parent.verticalCenter; Text { text: "Night"; color: shell.textPrimary; font.pixelSize: 10; font.weight: Font.DemiBold } Text { text: shell.nightMode ? "On" : "Off"; color: shell.textMuted; font.pixelSize: 8 } }
                                    }

                                    MouseArea {
                                        id: nia
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shell.nightMode = !shell.nightMode
                                    }
                                }
                            }

                             // Personalization & Screen Toolkit Row
                             Row {
                                 width: parent.width; spacing: 8

                                 // Personalization (Left)
                                 Rectangle {
                                     width: (parent.width - 8) / 2; height: 45; radius: 22.5
                                     color: persBtnMa.containsMouse ? shell.surfaceBright : ((shell.currentState === 12 || shell.currentState === 11) ? shell.accentDim : shell.surfaceAlt)
                                     border.width: 1
                                     border.color: (shell.currentState === 12 || shell.currentState === 11) ? Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2) : shell.surfaceBorder
                                     Behavior on color { ColorAnimation { duration: shell.animFast } }

                                     Row {
                                         anchors.fill: parent; anchors.margins: 8; spacing: 6
                                         Rectangle {
                                             width: 28; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                                             color: (shell.currentState === 12 || shell.currentState === 11) ? shell.accent : shell.surfaceBright
                                             Image {
                                                 anchors.centerIn: parent; width: 16; height: 16
                                                 source: "icons/palette.png"
                                                 fillMode: Image.PreserveAspectFit
                                                 layer.enabled: ccView.ccActive
                                                 layer.effect: MultiEffect {
                                                     brightness: 1.0
                                                     colorization: 1.0
                                                     colorizationColor: (shell.currentState === 12 || shell.currentState === 11) ? shell.surface : shell.textMuted
                                                 }
                                             }
                                         }
                                         Column {
                                             anchors.verticalCenter: parent.verticalCenter
                                             Text { text: "Personalization"; color: shell.textPrimary; font.pixelSize: 10; font.weight: Font.DemiBold }
                                             Text { text: "Wallpaper, themes..."; color: shell.textSecondary; font.pixelSize: 8 }
                                         }
                                     }

                                     MouseArea {
                                         id: persBtnMa
                                         anchors.fill: parent
                                         hoverEnabled: true
                                         cursorShape: Qt.PointingHandCursor
                                         onClicked: shell.setState(12)
                                     }
                                 }

                                 // Screen Toolkit (Right)
                                 Rectangle {
                                     width: (parent.width - 8) / 2; height: 45; radius: 22.5
                                     color: screenToolkitBtnMa.containsMouse ? shell.surfaceBright : (shell.currentState === 14 ? shell.accentDim : shell.surfaceAlt)
                                     border.width: 1
                                     border.color: shell.currentState === 14 ? Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2) : shell.surfaceBorder
                                     Behavior on color { ColorAnimation { duration: shell.animFast } }

                                     Row {
                                         anchors.fill: parent; anchors.margins: 8; spacing: 6
                                         Rectangle {
                                             width: 28; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                                             color: shell.currentState === 14 ? shell.accent : shell.surfaceBright
                                              Image {
                                                  anchors.centerIn: parent; width: 16; height: 16
                                                  source: "icons/screentools.png"
                                                  fillMode: Image.PreserveAspectFit
                                                  layer.enabled: ccView.ccActive
                                                  layer.effect: MultiEffect {
                                                      brightness: 1.0
                                                      colorization: 1.0
                                                      colorizationColor: shell.currentState === 14 ? shell.surface : shell.textMuted
                                                  }
                                              }
                                         }
                                         Column {
                                             anchors.verticalCenter: parent.verticalCenter
                                             Text { text: "Screen Toolkit"; color: shell.textPrimary; font.pixelSize: 10; font.weight: Font.DemiBold }
                                             Text { text: "Capture, record, OCR..."; color: shell.textSecondary; font.pixelSize: 8 }
                                         }
                                     }

                                     MouseArea {
                                         id: screenToolkitBtnMa
                                         anchors.fill: parent
                                         hoverEnabled: true
                                         cursorShape: Qt.PointingHandCursor
                                         onClicked: shell.setState(14)
                                     }
                                 }
                             }

                            // Volume Slider (real)
                            Rectangle {
                                width: parent.width; height: 30; radius: 15; color: shell.surfaceBright; clip: true

                                // Fill
                                Rectangle {
                                    width: parent.width * shell.sysVolume
                                    height: parent.height
                                    radius: parent.radius
                                    color: shell.accent
                                    Behavior on width {
                                        enabled: !shell.volDragging
                                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                    }
                                }

                                // Icon (overlayed on left)
                                Image {
                                    width: 15; height: 15
                                    anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                    source: "icons/volume.png"
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: ccView.ccActive
                                    layer.effect: MultiEffect {
                                        brightness: 1.0
                                        colorization: 1.0
                                        colorizationColor: shell.sysMuted ? shell.textMuted : (shell.sysVolume > 0.08 ? shell.surface : shell.accent)
                                    }
                                }


                                MouseArea {
                                    id: volMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    onPressed: (mouse) => {
                                        shell.volDragging = true;
                                        mouse.accepted = true;
                                        shell.setVolume(mouse.x / width);
                                    }
                                    onReleased: (mouse) => {
                                        shell.volDragging = false;
                                    }
                                    onCanceled: {
                                        shell.volDragging = false;
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (pressed) {
                                            shell.setVolume(mouse.x / width);
                                        }
                                    }
                                    onWheel: (wheel) => {
                                        var step = 0.02;
                                        if (wheel.angleDelta.y > 0) {
                                            shell.setVolume(shell.sysVolume + step);
                                        } else if (wheel.angleDelta.y < 0) {
                                            shell.setVolume(shell.sysVolume - step);
                                        }
                                        wheel.accepted = true;
                                    }
                                }
                            }

                            // Brightness Slider (real)
                            Rectangle {
                                width: parent.width; height: 30; radius: 15; color: shell.surfaceBright; clip: true

                                // Fill
                                Rectangle {
                                    width: parent.width * shell.sysBrightness
                                    height: parent.height
                                    radius: parent.radius
                                    color: shell.peach
                                    Behavior on width {
                                        enabled: !brightMouseArea.pressed
                                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                    }
                                }

                                // Icon (overlayed on left)
                                Image {
                                    width: 15; height: 15
                                    anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                    source: "icons/brightness.png"
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: ccView.ccActive
                                    layer.effect: MultiEffect {
                                        brightness: 1.0
                                        colorization: 1.0
                                        colorizationColor: shell.sysBrightness > 0.08 ? shell.surface : shell.peach
                                    }
                                }


                                MouseArea {
                                    id: brightMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    onPressed: (mouse) => {
                                        mouse.accepted = true;
                                        shell.setBrightness(mouse.x / width);
                                    }
                                    onReleased: (mouse) => {
                                        // Released handler empty
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (pressed) {
                                            shell.setBrightness(mouse.x / width);
                                        }
                                    }
                                    onWheel: (wheel) => {
                                        var step = 0.02;
                                        if (wheel.angleDelta.y > 0) {
                                            shell.setBrightness(shell.sysBrightness + step);
                                        } else if (wheel.angleDelta.y < 0) {
                                            shell.setBrightness(shell.sysBrightness - step);
                                        }
                                        wheel.accepted = true;
                                    }
                                }
                            }

                            // Media Card (real)
                            Rectangle {
                                width: parent.width; height: 115; radius: 16; color: shell.surfaceAlt; clip: true
                                visible: shell.mediaTitle !== ""

                                Rectangle {
                                    anchors.fill: parent; radius: parent.radius
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.12) }
                                        GradientStop { position: 0.5; color: Qt.rgba(shell.red.r, shell.red.g, shell.red.b, 0.08) }
                                        GradientStop { position: 1.0; color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.05) }
                                    }
                                }

                                Row {
                                    anchors.fill: parent; anchors.margins: 15; spacing: 15

                                    // Album Art / Fallback
                                    Rectangle {
                                        id: albumArtContainer
                                        width: 85; height: 85; radius: 10; color: shell.surfaceBright
                                        anchors.verticalCenter: parent.verticalCenter

                                        layer.enabled: ccView.ccActive
                                        layer.smooth: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: ShaderEffectSource {
                                                sourceItem: Rectangle {
                                                    width: 85
                                                    height: 85
                                                    radius: 10
                                                    color: "white"
                                                }
                                            }
                                        }

                                        Image {
                                            id: albumArtImage
                                            anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                                            source: shell.mediaArtUrl !== "" ? shell.mediaArtUrl : ""
                                            visible: shell.mediaArtUrl !== ""
                                        }
                                        Image {
                                            width: 32; height: 32; anchors.centerIn: parent
                                            source: "icons/volume.png"
                                            fillMode: Image.PreserveAspectFit
                                            visible: shell.mediaArtUrl === ""
                                            layer.enabled: ccView.ccActive
                                            layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textMuted }
                                        }
                                    }

                                    // Right Content Column
                                    Column {
                                        width: parent.width - 85 - 15; spacing: 6; anchors.verticalCenter: parent.verticalCenter

                                        // Song info
                                        Column {
                                            width: parent.width; spacing: 1
                                            Text { text: shell.mediaTitle; color: shell.textPrimary; font.pixelSize: 13; font.weight: Font.Bold; elide: Text.ElideRight; width: parent.width }
                                            Text { text: shell.mediaArtist; color: shell.textSecondary; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width }
                                        }

                                        // Progress bar
                                        Item {
                                            width: parent.width; height: 4
                                            Rectangle {
                                                width: parent.width; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.1)
                                                Rectangle {
                                                    width: shell.mediaLength > 0 ? parent.width * (shell.mediaPosition / shell.mediaLength) : 0
                                                    height: parent.height; radius: parent.radius; color: shell.accent
                                                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.Linear } }
                                                }
                                            }
                                        }

                                        // Time labels
                                        Item {
                                            width: parent.width; height: 10
                                            Text {
                                                function fmt(s) { var m=Math.floor(s/60); var ss=Math.floor(s%60); return m+":"+(ss<10?"0":"")+ss; }
                                                text: fmt(shell.mediaPosition); color: shell.textMuted; font.pixelSize: 8; anchors.left: parent.left
                                            }
                                            Text {
                                                function fmt(s) { var m=Math.floor(s/60); var ss=Math.floor(s%60); return m+":"+(ss<10?"0":"")+ss; }
                                                text: fmt(shell.mediaLength); color: shell.textMuted; font.pixelSize: 8; anchors.right: parent.right
                                            }
                                        }

                                        Item { width: 1; height: 2 } // Spacer

                                        // Media Controls Row
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 24

                                            // Previous
                                            Item {
                                                width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
                                                Image {
                                                    anchors.fill: parent; source: "icons/previous.png"
                                                    fillMode: Image.PreserveAspectFit
                                                    layer.enabled: ccView.ccActive
                                                    layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textSecondary }
                                                }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (shell.mediaPlayer) shell.mediaPlayer.previous(); } }
                                            }

                                            // Play/Pause
                                            Rectangle {
                                                width: 26; height: 26; radius: 13; color: shell.textPrimary
                                                anchors.verticalCenter: parent.verticalCenter
                                                Image {
                                                    anchors.centerIn: parent
                                                    width: 12; height: 12
                                                    source: shell.mediaPlaying ? "icons/pause.png" : "icons/play-button.png"
                                                    fillMode: Image.PreserveAspectFit
                                                    layer.enabled: ccView.ccActive
                                                    layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.surface }
                                                }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (shell.mediaPlayer) { if (shell.mediaPlaying) shell.mediaPlayer.pause(); else shell.mediaPlayer.play(); } } }
                                            }

                                            // Next
                                            Item {
                                                width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
                                                Image {
                                                    anchors.fill: parent; source: "icons/next.png"
                                                    fillMode: Image.PreserveAspectFit
                                                    layer.enabled: ccView.ccActive
                                                    layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textSecondary }
                                                }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (shell.mediaPlayer) shell.mediaPlayer.next(); } }
                                            }
                                        }
                                    }
                                }
                            }

                            // No media placeholder
                            Rectangle {
                                width: parent.width; height: 48; radius: 14; color: shell.surfaceAlt
                                visible: false
                                Text { anchors.centerIn: parent; text: "No media playing"; color: shell.textMuted; font.pixelSize: 11 }
                            }

                            // Notifications
                            Column {
                                width: parent.width
                                spacing: 8
                                visible: shell.notifHistory.count > 0

                                Row {
                                    width: parent.width
                                    Text { text: "Notifications"; color: shell.textSecondary; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    Item { width: parent.width - 150; height: 1 }
                                    Text {
                                        text: "Clear all"; color: shell.accent; font.pixelSize: 11; font.weight: Font.Medium
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.clearNotifications() }
                                    }
                                }

                                // Notification cards from real history
                                Repeater {
                                    model: Math.min(shell.notifHistory.count, 5)

                                    Rectangle {
                                        width: ccColumn.width; height: nCol.height + 20; radius: 14; color: shell.surfaceAlt

                                        Column {
                                            id: nCol
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                            anchors.margins: 12; anchors.rightMargin: 32; spacing: 4

                                            Row {
                                                spacing: 8
                                                Rectangle {
                                                    width: 22; height: 22; radius: 11; anchors.verticalCenter: parent.verticalCenter
                                                    color: {
                                                        var palette = [shell.wpAccent, shell.wpBlue, shell.wpGreen, shell.wpPeach, shell.wpRed];
                                                        return palette[index % palette.length];
                                                    }

                                                    Image {
                                                        anchors.centerIn: parent
                                                        width: 12; height: 12
                                                        source: "icons/notification.png"
                                                        fillMode: Image.PreserveAspectFit
                                                        visible: {
                                                            var item = shell.notifHistory.get(index);
                                                            return item ? item.appName.toLowerCase() !== "power" : true;
                                                        }
                                                        layer.enabled: ccView.ccActive
                                                        layer.effect: MultiEffect {
                                                            brightness: 1.0
                                                            colorization: 1.0
                                                            colorizationColor: shell.surface
                                                        }
                                                    }

                                                    Image {
                                                        anchors.centerIn: parent
                                                        width: 12; height: 12
                                                        source: "icons/power.png"
                                                        fillMode: Image.PreserveAspectFit
                                                        visible: {
                                                            var item = shell.notifHistory.get(index);
                                                            return item ? item.appName.toLowerCase() === "power" : false;
                                                        }
                                                        layer.enabled: ccView.ccActive
                                                        layer.effect: MultiEffect {
                                                            brightness: 1.0
                                                            colorization: 1.0
                                                            colorizationColor: shell.surface
                                                        }
                                                    }
                                                }
                                                Text { text: shell.notifHistory.get(index).appName; color: shell.textPrimary; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            }
                                            Text { text: shell.notifHistory.get(index).summary; color: shell.textPrimary; font.pixelSize: 13; font.weight: Font.Bold; width: parent.width; elide: Text.ElideRight }
                                            Text { text: shell.notifHistory.get(index).body; color: shell.textSecondary; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
                                        }

                                        Text {
                                            anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: 12; anchors.topMargin: 12
                                            text: "×"; color: shell.textMuted; font.pixelSize: 16
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.notifHistory.remove(index) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STATE 6: POWER MENU
                // =============================================================
                Item {
                    anchors.fill: parent
                    opacity: shell.currentState === 6 ? 1 : 0; scale: shell.currentState === 6 ? 1 : 0.92; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.setState(0)
                    }

                    Row {
                        anchors.centerIn: parent; spacing: 6

                        Repeater {
                            model: [
                                { label: "Lock", danger: false, action: "lock", icon: "icons/lock.png" },
                                { label: "Suspend", danger: false, action: "suspend", icon: "icons/suspend.png" },
                                { label: "Logout", danger: false, action: "logout", icon: "icons/signout.png" },
                                { label: "Reboot", danger: true, action: "reboot", icon: "icons/restart.png" },
                                { label: "Off", danger: true, action: "poweroff", icon: "icons/poweroff.png" }
                            ]

                            Rectangle {
                                width: 80; height: 70; radius: 16
                                color: pma.containsMouse
                                    ? (modelData.danger ? Qt.rgba(shell.red.r, shell.red.g, shell.red.b, 0.2) : shell.surfaceBright)
                                    : (modelData.danger ? Qt.rgba(shell.red.r, shell.red.g, shell.red.b, 0.08) : shell.surfaceAlt)
                                Behavior on color { ColorAnimation { duration: shell.animFast } }
                                border.width: modelData.danger ? 1 : 0
                                border.color: Qt.rgba(shell.red.r, shell.red.g, shell.red.b, 0.2)

                                Column {
                                    anchors.centerIn: parent; spacing: 6
                                    Image {
                                        width: 24; height: 24; anchors.horizontalCenter: parent.horizontalCenter
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: shell.currentState === 6
                                        layer.effect: MultiEffect {
                                            brightness: 1.0
                                            colorization: 1.0
                                            colorizationColor: modelData.danger ? shell.red : (pma.containsMouse ? shell.accent : shell.textSecondary)
                                        }
                                    }
                                    Text { text: modelData.label; color: modelData.danger ? shell.red : (pma.containsMouse ? shell.textPrimary : shell.textSecondary); font.pixelSize: 10; font.weight: Font.Medium; anchors.horizontalCenter: parent.horizontalCenter }
                                }

                                MouseArea {
                                    id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.action === "lock") shell.doLock();
                                        else if (modelData.action === "suspend") shell.doSuspend();
                                        else if (modelData.action === "logout") shell.doLogout();
                                        else if (modelData.action === "reboot") shell.doReboot();
                                        else if (modelData.action === "poweroff") shell.doPoweroff();
                                        shell.setState(0);
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STATE 7: POLKIT
                // =============================================================
                Item {
                    anchors.fill: parent
                    opacity: shell.currentState === 7 ? 1 : 0; scale: shell.currentState === 7 ? 1 : 0.96; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }

                    Column {
                        anchors.centerIn: parent; spacing: 12; width: parent.width - 48

                        Rectangle {
                            width: 36; height: 36; radius: 18; color: shell.accentDim; anchors.horizontalCenter: parent.horizontalCenter
                            Rectangle { anchors.centerIn: parent; y: 2; width: 12; height: 10; radius: 2; color: shell.accent }
                        }

                        Text { text: "Authentication Required"; color: shell.textPrimary; font.pixelSize: 13; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "org.freedesktop.policykit"; color: shell.textMuted; font.pixelSize: 9; anchors.horizontalCenter: parent.horizontalCenter }

                        Rectangle {
                            width: parent.width; height: 34; radius: 10; color: shell.surfaceAlt
                            border.width: 1; border.color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.3)
                            Text { anchors.centerIn: parent; text: "• • • • • • • •"; color: shell.textMuted; font.pixelSize: 14; font.letterSpacing: 2 }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                            Rectangle {
                                width: 96; height: 30; radius: 10; color: cma.containsMouse ? shell.surfaceBright : shell.surfaceAlt
                                Behavior on color { ColorAnimation { duration: shell.animFast } }
                                Text { anchors.centerIn: parent; text: "Cancel"; color: shell.textSecondary; font.pixelSize: 11; font.weight: Font.Medium }
                                MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(0) }
                            }
                            Rectangle {
                                width: 96; height: 30; radius: 10; color: ama.containsMouse ? Qt.lighter(shell.accent, 1.1) : shell.accent
                                Behavior on color { ColorAnimation { duration: shell.animFast } }
                                Text { anchors.centerIn: parent; text: "Authenticate"; color: shell.surface; font.pixelSize: 11; font.weight: Font.Bold }
                                MouseArea { id: ama; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(0) }
                            }
                        }
                    }
                }

                // =============================================================
                // STATE 8: WIFI DETAILS PILL
                // =============================================================
                Item {
                    anchors.fill: parent
                    opacity: shell.currentState === 8 ? 1 : 0; scale: shell.currentState === 8 ? 1 : 0.96; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.setState(0)
                    }

                    Flickable {
                        visible: !shell.wifiShowPasswordInput
                        anchors.fill: parent; anchors.margins: 14
                        contentHeight: wifiCol.height
                        contentWidth: width
                        clip: true; boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: wifiCol; width: parent.width; spacing: 12

                            // Header
                            Row {
                                width: parent.width; spacing: 10
                                Item {
                                    width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.centerIn: parent; width: 20; height: 20
                                        source: "icons/back.png"
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: shell.currentState === 8
                                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textPrimary }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(5) }
                                }
                                Text { text: "Wi-Fi Networks"; color: shell.textPrimary; font.pixelSize: 16; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                
                                // Spacer
                                Item { width: parent.width - 32 - 120 - 32; height: 1 }

                                // Refresh Button
                                Item {
                                    width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.centerIn: parent; width: 14; height: 14
                                        source: "icons/restart.png"
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: shell.currentState === 8
                                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: (wifiScanProc.running && !wifiFirstScan) ? shell.textMuted : shell.textPrimary }
                                        RotationAnimator on rotation {
                                            loops: Animation.Infinite
                                            running: wifiScanProc.running && !wifiFirstScan
                                            from: 0
                                            to: 360
                                            duration: 1000
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!wifiScanProc.running) {
                                                wifiFirstScan = false;
                                                wifiScanProc.running = true;
                                            }
                                        }
                                    }
                                }
                            }

                            // Switch Card (WiFi Toggle)
                            Rectangle {
                                width: parent.width; height: 50; radius: 14; color: shell.surfaceAlt
                                border.width: 1; border.color: shell.surfaceBorder

                                Row {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 12

                                    Rectangle {
                                        width: 28; height: 28; radius: 14; color: shell.wifiEnabled ? shell.accent : shell.surfaceBright; anchors.verticalCenter: parent.verticalCenter
                                        Image {
                                            anchors.centerIn: parent; width: 14; height: 14
                                            source: "icons/wifi.png"
                                            layer.enabled: shell.currentState === 8
                                            layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.wifiEnabled ? shell.surface : shell.textMuted }
                                        }
                                    }

                                    Column {
                                        width: parent.width - 28 - 44 - 36
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: shell.wifiEnabled ? "Wi-Fi Enabled" : "Wi-Fi Disabled"; color: shell.textPrimary; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: shell.wifiConnected ? "Connected: " + shell.wifiSSID : "Disconnected"; color: shell.textSecondary; font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
                                    }

                                    Image {
                                        width: 44; height: 24
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "icons/on.png"
                                        mirror: !shell.wifiEnabled
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: shell.currentState === 8
                                        layer.effect: MultiEffect {
                                            brightness: 1.0
                                            colorization: 1.0
                                            colorizationColor: shell.wifiEnabled ? shell.accent : shell.textMuted
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.toggleWifi() }
                                    }
                                }
                            }

                            // Connected / Connecting Network Section
                            Column {
                                width: parent.width; spacing: 6
                                visible: shell.wifiConnected || (shell.wifiConnectionState !== "Disconnected" && shell.wifiConnectionState !== "")

                                Text {
                                    text: shell.wifiConnectionState === "Connected" ? "Connected" : (shell.wifiConnectionState === "Failed" ? "Connection Failed" : "Connecting")
                                    color: shell.textSecondary; font.pixelSize: 11; font.weight: Font.DemiBold; leftPadding: 4
                                }

                                Rectangle {
                                    width: wifiCol.width; height: shell.wifiIPAddress !== "" ? 75 : 60; radius: 12
                                    color: shell.wifiConnectionState === "Failed" ? Qt.rgba(shell.red.r, shell.red.g, shell.red.b, 0.1) : shell.surfaceAlt
                                    border.width: 1
                                    border.color: shell.wifiConnectionState === "Failed" ? shell.red : (shell.wifiConnectionState === "Connected" ? shell.accent : shell.surfaceBorder)

                                    Row {
                                        anchors.fill: parent; anchors.margins: 10; spacing: 12

                                        // Left Icon
                                        Rectangle {
                                            width: 32; height: 32; radius: 16
                                            color: shell.wifiConnectionState === "Failed" ? shell.red : (shell.wifiConnectionState === "Connected" ? shell.accent : shell.surfaceBright)
                                            anchors.verticalCenter: parent.verticalCenter
                                            Image {
                                                anchors.centerIn: parent; width: 16; height: 16
                                                source: "icons/wifi.png"
                                                layer.enabled: shell.currentState === 8
                                                layer.effect: MultiEffect {
                                                    brightness: 1.0
                                                    colorization: 1.0
                                                    colorizationColor: (shell.wifiConnectionState === "Connected" || shell.wifiConnectionState === "Failed") ? shell.surface : shell.textPrimary
                                                }
                                            }
                                        }

                                        // Details
                                        Column {
                                            width: parent.width - 32 - 70 - 24
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2

                                            Text {
                                                text: shell.wifiConnectionState === "Failed" ? shell.wifiSelectedSsid : (shell.wifiSSID || shell.wifiSelectedSsid)
                                                color: shell.textPrimary; font.pixelSize: 13; font.weight: Font.Bold; elide: Text.ElideRight; width: parent.width
                                            }

                                            Text {
                                                text: "Signal: " + shell.getSignalLabel(shell.connectedWifiSignal) + "  |  " + (shell.connectedWifiSecurity === "" || shell.connectedWifiSecurity === "--" ? "Open" : "Secured")
                                                color: shell.textSecondary; font.pixelSize: 9
                                            }

                                            Text {
                                                text: "Status: " + (shell.wifiConnectionState === "Failed" && shell.wifiLastError !== "" ? shell.wifiLastError : shell.wifiConnectionState)
                                                color: shell.wifiConnectionState === "Failed" ? shell.red : (shell.wifiConnectionState === "Connected" ? shell.green : shell.accent)
                                                font.pixelSize: 9; font.weight: Font.DemiBold
                                            }

                                            Text {
                                                visible: shell.wifiIPAddress !== "" && shell.wifiConnectionState === "Connected"
                                                text: "IP: " + shell.wifiIPAddress
                                                color: shell.textMuted; font.pixelSize: 9
                                            }
                                        }

                                        // Disconnect / Cancel Button
                                        Rectangle {
                                            width: 70; height: 28; radius: 6
                                            color: shell.wifiConnectionState === "Failed" ? shell.surfaceBright : (shell.wifiConnectionState === "Connected" ? shell.surfaceBright : shell.red)
                                            border.width: 1
                                            border.color: shell.wifiConnectionState === "Failed" ? shell.surfaceBorder : "transparent"
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                anchors.centerIn: parent
                                                text: shell.wifiConnectionState === "Failed" ? "Dismiss" : (shell.wifiConnectionState === "Connected" ? "Disconnect" : "Cancel")
                                                color: (shell.wifiConnectionState === "Failed" || shell.wifiConnectionState === "Connected") ? shell.textPrimary : shell.surface
                                                font.pixelSize: 10; font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (shell.wifiConnectionState === "Connected") {
                                                        shell.sysNotify("Network", "Disconnecting", "Disconnecting from '" + shell.wifiSSID + "'...");
                                                        wifiDisconnectProc.command = ["nmcli", "connection", "down", "id", shell.wifiSSID];
                                                        wifiDisconnectProc.running = true;
                                                    } else if (shell.wifiConnectionState === "Failed") {
                                                        shell.wifiConnectionState = "Disconnected";
                                                        shell.wifiLastError = "";
                                                    } else {
                                                        if (wifiConnectProc.running) {
                                                            wifiConnectProc.running = false;
                                                        }
                                                        shell.wifiConnectionState = "Disconnected";
                                                        shell.wifiLastError = "";
                                                        wifiProc.running = false;
                                                        wifiProc.running = true;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // List of WiFi Networks
                            Column {
                                width: parent.width; spacing: 6
                                visible: shell.wifiEnabled && wifiListModel.count > 0

                                Text { text: "Available Networks"; color: shell.textSecondary; font.pixelSize: 11; font.weight: Font.DemiBold; leftPadding: 4 }

                                Repeater {
                                    model: wifiListModel

                                    Rectangle {
                                        width: wifiCol.width; height: 40; radius: 10
                                        color: shell.surfaceAlt
                                        border.width: 0

                                        Image {
                                            id: wifiItemIcon
                                            width: 14; height: 14
                                            anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                            source: "icons/wifi.png"
                                            layer.enabled: shell.currentState === 8
                                            layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textSecondary }
                                        }

                                        Text {
                                            id: wifiItemSignal
                                            text: (shell.savedWifiProfiles[ssid] === true ? "Saved  |  " : "") + (security === "" || security === "--" ? "Open" : "Secured") + "  |  " + signal + "%"
                                            color: shell.textMuted; font.pixelSize: 9
                                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: ssid; color: shell.textPrimary
                                            font.pixelSize: 12; font.weight: Font.Normal
                                            elide: Text.ElideRight
                                            anchors.left: wifiItemIcon.right; anchors.leftMargin: 10
                                            anchors.right: wifiItemSignal.left; anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var isSaved = shell.savedWifiProfiles[ssid] === true;
                                                if (isSaved) {
                                                    shell.wifiSelectedSsid = ssid;
                                                    shell.wifiLastError = "";
                                                    shell.wifiConnectionState = "Connecting...";
                                                    shell.sysNotify("Network", "Connecting", "Connecting to saved network '" + ssid + "'...");
                                                    wifiConnectProc.command = ["sh", "-c", "nmcli connection modify \"" + ssid + "\" connection.interface-name \"\" 2>/dev/null || true; nmcli --wait 15 connection up id \"" + ssid + "\""];
                                                    wifiConnectProc.running = true;
                                                } else {
                                                    if (security === "" || security === "--") {
                                                        shell.wifiSelectedSsid = ssid;
                                                        shell.wifiLastError = "";
                                                        shell.wifiConnectionState = "Connecting...";
                                                        shell.sysNotify("Network", "Connecting", "Connecting to '" + ssid + "'...");
                                                        wifiConnectProc.command = ["nmcli", "--wait", "15", "device", "wifi", "connect", ssid];
                                                        wifiConnectProc.running = true;
                                                    } else {
                                                        shell.wifiSelectedSsid = ssid;
                                                        shell.wifiShowPasswordInput = true;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty list / Scanning placeholder
                            Rectangle {
                                width: parent.width; height: 60; radius: 14; color: shell.surfaceAlt
                                visible: shell.wifiEnabled && wifiListModel.count === 0
                                Column {
                                    anchors.centerIn: parent; spacing: 4
                                    Text { text: "Scanning for networks..."; color: shell.textMuted; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                            }
                        }
                    }

                    // Password Input Popup View
                    Item {
                        anchors.fill: parent
                        visible: shell.wifiShowPasswordInput

                        Column {
                            anchors.fill: parent; anchors.margins: 14; spacing: 8
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "Password for '" + shell.wifiSelectedSsid + "'"
                                color: shell.textPrimary
                                font.pixelSize: 13; font.weight: Font.DemiBold
                                elide: Text.ElideRight; width: parent.width
                            }

                            Row {
                                width: parent.width; height: 32; spacing: 8

                                // Input box
                                Rectangle {
                                    width: parent.width - 75 - 65 - 8; height: 32; radius: 8; color: shell.surfaceBright
                                    border.width: 0

                                    TextInput {
                                        id: wifiPasswordInput
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: shell.textPrimary; font.pixelSize: 12
                                        echoMode: TextInput.Password
                                        focus: shell.wifiShowPasswordInput
                                        Keys.onReturnPressed: connectWifiBtn.clickedAction()

                                        Connections {
                                            target: shell
                                            function onWifiShowPasswordInputChanged() {
                                                if (shell.wifiShowPasswordInput) {
                                                    Qt.callLater(() => wifiPasswordInput.forceActiveFocus());
                                                }
                                            }
                                        }
                                    }
                                }

                                // Connect button
                                Rectangle {
                                    id: connectWifiBtn
                                    width: 75; height: 32; radius: 8; color: shell.accent
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Connect"; color: shell.surface; font.pixelSize: 11; font.weight: Font.Bold
                                    }
                                    function clickedAction() {
                                        var pwd = wifiPasswordInput.text;
                                        shell.wifiLastError = "";
                                        shell.wifiConnectionState = "Connecting...";
                                        shell.sysNotify("Network", "Connecting", "Connecting to " + shell.wifiSelectedSsid + "...");
                                        wifiConnectProc.command = ["nmcli", "--wait", "15", "device", "wifi", "connect", shell.wifiSelectedSsid, "password", pwd];
                                        wifiConnectProc.running = true;
                                        shell.wifiShowPasswordInput = false;
                                        wifiPasswordInput.text = "";
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: connectWifiBtn.clickedAction()
                                    }
                                }

                                // Cancel button
                                Rectangle {
                                    width: 65; height: 32; radius: 8; color: shell.surfaceBright
                                    border.width: 1; border.color: shell.surfaceBorder
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Cancel"; color: shell.textSecondary; font.pixelSize: 11; font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            shell.wifiShowPasswordInput = false;
                                            shell.wifiSelectedSsid = "";
                                            wifiPasswordInput.text = "";
                                        }
                                    }
                                }
                            }
                        }
                    }
    
                }

                // =============================================================
                // STATE 9: BLUETOOTH DETAILS PILL
                // =============================================================
                Item {
                    anchors.fill: parent
                    opacity: shell.currentState === 9 ? 1 : 0; scale: shell.currentState === 9 ? 1 : 0.96; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.setState(0)
                    }

                    Flickable {
                        anchors.fill: parent; anchors.margins: 14
                        contentHeight: btCol.height
                        contentWidth: width
                        clip: true; boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: btCol; width: parent.width; spacing: 12

                            // Header
                            Row {
                                width: parent.width; spacing: 10
                                Item {
                                    width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.centerIn: parent; width: 20; height: 20
                                        source: "icons/back.png"
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: shell.currentState === 9
                                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textPrimary }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(5) }
                                }
                                Text { text: "Bluetooth Devices"; color: shell.textPrimary; font.pixelSize: 16; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }

                            // Switch Card (Bluetooth Toggle)
                            Rectangle {
                                width: parent.width; height: 50; radius: 14; color: shell.surfaceAlt
                                border.width: 1; border.color: shell.surfaceBorder

                                Row {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 12

                                    Rectangle {
                                        width: 28; height: 28; radius: 14; color: shell.btPowered ? shell.accent : shell.surfaceBright; anchors.verticalCenter: parent.verticalCenter
                                        Image {
                                            anchors.centerIn: parent; width: 14; height: 14
                                            source: "icons/bluetooth.png"
                                            layer.enabled: shell.currentState === 9
                                            layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.btPowered ? shell.surface : shell.textMuted }
                                        }
                                    }

                                    Column {
                                        width: parent.width - 28 - 44 - 36
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: shell.btPowered ? "Bluetooth Enabled" : "Bluetooth Disabled"; color: shell.textPrimary; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: shell.btPowered ? (shell.btConnected ? "Status: Connected" : "Status: On (No Devices)") : "Status: Off"; color: shell.textSecondary; font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
                                    }

                                    Image {
                                        width: 44; height: 24
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "icons/on.png"
                                        mirror: !shell.btPowered
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: shell.currentState === 9
                                        layer.effect: MultiEffect {
                                            brightness: 1.0
                                            colorization: 1.0
                                            colorizationColor: shell.btPowered ? shell.accent : shell.textMuted
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.toggleBluetooth() }
                                    }
                                }
                            }

                            // List of Devices
                            Column {
                                width: parent.width; spacing: 6
                                visible: shell.btPowered && btListModel.count > 0

                                Text { text: "Discovered Devices (Scanning...)"; color: shell.textSecondary; font.pixelSize: 11; font.weight: Font.DemiBold; leftPadding: 4 }

                                Repeater {
                                    model: btListModel

                                    Rectangle {
                                        width: btCol.width; height: 40; radius: 10; color: shell.surfaceAlt

                                        Image {
                                            id: btItemIcon
                                            width: 14; height: 14
                                            anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                            source: "icons/bluetooth.png"
                                            layer.enabled: shell.currentState === 9
                                            layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textSecondary }
                                        }

                                        Text {
                                            text: name; color: shell.textPrimary
                                            font.pixelSize: 12; elide: Text.ElideRight
                                            anchors.left: btItemIcon.right; anchors.leftMargin: 10
                                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                shell.sysNotify("Bluetooth", "Connecting", "Connecting to '" + name + "'...");
                                                btConnectProc.targetMac = mac;
                                                btConnectProc.targetName = name;
                                                btConnectProc.command = ["bluetoothctl", "connect", mac];
                                                btConnectProc.running = true;
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty list placeholder
                            Rectangle {
                                width: parent.width; height: 60; radius: 14; color: shell.surfaceAlt
                                visible: shell.btPowered && btListModel.count === 0
                                Column {
                                    anchors.centerIn: parent; spacing: 4
                                    Text { text: "Scanning for devices..."; color: shell.textMuted; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STATE 10: WALLPAPER DETAILS PILL
                // =============================================================
                Item {
                    id: wallpaperSelectorView
                    anchors.fill: parent
                    opacity: shell.currentState === 10 ? 1 : 0; scale: shell.currentState === 10 ? 1 : 0.96; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }

                    property var wallpapersList: []

                    function refreshList() {
                         if (panelWindow && panelWindow.modelData) {
                             wallpapersList = WallpaperService.getWallpapersList(panelWindow.modelData.name);
                         }
                    }

                    onVisibleChanged: {
                         if (visible) {
                             refreshList();
                         }
                    }

                    Connections {
                         target: WallpaperService
                         function onWallpaperListChanged(screenName, count) {
                             if (panelWindow && panelWindow.modelData && screenName === panelWindow.modelData.name) {
                                 wallpaperSelectorView.refreshList();
                             }
                         }
                         function onWallpaperChanged(screenName, path) {
                             if (panelWindow && panelWindow.modelData && screenName === panelWindow.modelData.name) {
                                 wallpaperSelectorView.refreshList();
                             }
                         }
                    }

                    MouseArea {
                         anchors.fill: parent
                         onClicked: shell.setState(0)
                    }

                    Column {
                         anchors.fill: parent
                         anchors.margins: 14
                         spacing: 12

                         // Header
                         Item {
                             width: parent.width; height: 32

                             // Left: Back button + title
                             Row {
                                 anchors.left: parent.left
                                 anchors.verticalCenter: parent.verticalCenter
                                 spacing: 10
                                 Item {
                                     width: 32; height: 32
                                     Image {
                                         anchors.centerIn: parent; width: 20; height: 20
                                         source: "icons/back.png"
                                         fillMode: Image.PreserveAspectFit
                                         layer.enabled: shell.currentState === 10
                                         layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textPrimary }
                                     }
                                     MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(12) }
                                 }
                                 Text { text: "Desktop Wallpaper"; color: shell.textPrimary; font.pixelSize: 16; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                             }

                             // Right: Select Folder pill button
                             Rectangle {
                                 id: selectFolderBtn
                                 anchors.right: parent.right
                                 anchors.verticalCenter: parent.verticalCenter
                                 width: folderBtnRow.implicitWidth + 20
                                 height: 26; radius: 13
                                 color: folderBtnMa.containsMouse ? shell.surfaceBright : shell.surfaceAlt
                                 Behavior on color { ColorAnimation { duration: shell.animFast } }
                                 border.width: 1
                                 border.color: shell.surfaceBorder

                                 Row {
                                     id: folderBtnRow
                                     anchors.centerIn: parent; spacing: 5
                                     Image {
                                         width: 12; height: 12
                                         anchors.verticalCenter: parent.verticalCenter
                                         source: (typeof Quickshell !== "undefined" && Quickshell.iconPath)
                                             ? Quickshell.iconPath("folder")
                                             : ""
                                         fillMode: Image.PreserveAspectFit
                                         layer.enabled: shell.currentState === 10
                                         layer.effect: MultiEffect {
                                             brightness: 1.0; colorization: 1.0
                                             colorizationColor: folderBtnMa.containsMouse ? shell.textPrimary : shell.textSecondary
                                         }
                                     }
                                     Text {
                                         text: "Select Folder"
                                         color: folderBtnMa.containsMouse ? shell.textPrimary : shell.textSecondary
                                         font.pixelSize: 10; font.weight: Font.Medium
                                         anchors.verticalCenter: parent.verticalCenter
                                         Behavior on color { ColorAnimation { duration: shell.animFast } }
                                     }
                                 }

                                 MouseArea {
                                     id: folderBtnMa
                                     anchors.fill: parent
                                     hoverEnabled: true
                                     cursorShape: Qt.PointingHandCursor
                                     onClicked: {
                                         folderPickerProc.command = [
                                             "python3",
                                             Qt.resolvedUrl("scripts/pick_folder.py").toString().replace("file://", "")
                                         ];
                                         folderPickerProc.running = true;
                                     }
                                 }
                             }
                         }



                         // Grid of Wallpapers
                         GridView {
                             id: wallpaperGridView
                             width: parent.width
                             height: 250
                             cellWidth: 138
                             cellHeight: 88
                             clip: true
                             boundsBehavior: Flickable.StopAtBounds
                             cacheBuffer: 88
                             model: wallpaperSelectorView.wallpapersList

                             delegate: Rectangle {
                                  id: card
                                  width: 128
                                  height: 78
                                  radius: 12
                                  color: wma.containsMouse ? "#3c3e56" : shell.surfaceBright
                                  Behavior on color { ColorAnimation { duration: 200 } }

                                  Rectangle {
                                      id: imgClip
                                      anchors.fill: parent
                                      radius: card.radius
                                      color: "transparent"

                                      layer.enabled: shell.currentState === 10
                                      layer.smooth: true
                                      layer.effect: MultiEffect {
                                          maskEnabled: true
                                          maskSource: ShaderEffectSource {
                                              sourceItem: Rectangle {
                                                  width: imgClip.width
                                                  height: imgClip.height
                                                  radius: imgClip.radius
                                                  color: "white"
                                              }
                                          }
                                      }

                                      Image {
                                          id: img
                                          anchors.fill: parent
                                          source: "file://" + modelData
                                          asynchronous: true
                                          cache: false
                                          sourceSize.width: imgClip.width
                                          sourceSize.height: imgClip.height
                                          fillMode: Image.PreserveAspectCrop
                                      }
                                  }

                                  // Outline border on top of the rounded image
                                  Rectangle {
                                      anchors.fill: parent
                                      radius: card.radius
                                      color: "transparent"
                                      border.width: (modelData === WallpaperService.getWallpaper(panelWindow.modelData.name)) ? 2 : (wma.containsMouse ? 1 : 0)
                                      border.color: (modelData === WallpaperService.getWallpaper(panelWindow.modelData.name)) ? shell.accent : "#585b70"
                                      Behavior on border.color { ColorAnimation { duration: 200 } }
                                  }

                                  MouseArea {
                                      id: wma
                                      anchors.fill: parent
                                      hoverEnabled: true
                                      cursorShape: Qt.PointingHandCursor
                                      onClicked: {
                                          WallpaperService.changeWallpaper(modelData, panelWindow.modelData.name);
                                      }
                                  }
                              }
                         }
                    }
                }

                // =============================================================
                // STATE 11: CUSTOM PALETTE DESIGNER
                // =============================================================
                Item {
                    id: customPaletteView
                    anchors.fill: parent
                    opacity: shell.currentState === 11 ? 1 : 0; scale: shell.currentState === 11 ? 1 : 0.96; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.setState(0)
                    }

                    Flickable {
                        id: cpFlickable
                        anchors.fill: parent; anchors.margins: 14
                        contentHeight: customPaletteCol.height
                        contentWidth: width
                        clip: true; boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: customPaletteCol
                            width: parent.width; spacing: 12

                            // Header
                            Row {
                                width: parent.width; spacing: 10
                                Item {
                                    width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.centerIn: parent; width: 20; height: 20
                                        source: "icons/back.png"
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: shell.currentState === 11
                                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textPrimary }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(12) }
                                }
                                Text { text: "Custom Palette Designer"; color: shell.textPrimary; font.pixelSize: 16; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }

                            // Swatch Grid Selector
                            Text {
                                text: "Select Color to Edit"; color: shell.textSecondary
                                font.pixelSize: 11; font.weight: Font.DemiBold; leftPadding: 4
                            }

                            Grid {
                                columns: 2; spacing: 8; width: parent.width

                                Repeater {
                                    model: [
                                        { name: "Accent", key: "customAccent" },
                                        { name: "Surface", key: "customSurface" },
                                        { name: "Surface Alt", key: "customSurfaceAlt" },
                                        { name: "Surface Bright", key: "customSurfaceBright" },
                                        { name: "Text Primary", key: "customTextPrimary" },
                                        { name: "Text Secondary", key: "customTextSecondary" },
                                        { name: "Text Muted", key: "customTextMuted" },
                                        { name: "Red", key: "customRed" },
                                        { name: "Green", key: "customGreen" },
                                        { name: "Peach", key: "customPeach" },
                                        { name: "Blue", key: "customBlue" }
                                    ]
                                    delegate: Rectangle {
                                        width: (customPaletteCol.width - 8) / 2; height: 38; radius: 8
                                        color: shell.activeColorKey === modelData.key ? shell.accentDim : shell.surfaceAlt
                                        border.width: shell.activeColorKey === modelData.key ? 1 : 0
                                        border.color: shell.accent

                                        Rectangle {
                                            id: colorCircle
                                            width: 14; height: 14; radius: 7; color: shell[modelData.key]
                                            anchors.left: parent.left; anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            border.width: 1; border.color: "#585b70"
                                        }

                                        Text {
                                            text: modelData.name; color: shell.textPrimary
                                            font.pixelSize: 10; font.weight: Font.Medium
                                            anchors.left: colorCircle.right; anchors.leftMargin: 6
                                            anchors.right: parent.right; anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                            onClicked: shell.selectColor(modelData.name, modelData.key)
                                        }
                                    }
                                }
                            }

                            // Active Editor Card
                            Rectangle {
                                width: parent.width; height: 110; radius: 12; color: shell.surfaceAlt
                                border.width: 1; border.color: shell.surfaceBorder

                                Column {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 8

                                    Item {
                                        width: parent.width; height: 18
                                        Text { text: "Edit Color: " + shell.activeColorName; color: shell.textPrimary; font.pixelSize: 12; font.weight: Font.Bold; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                                        
                                        Rectangle {
                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            width: 45; height: 18; radius: 4
                                            color: shell[shell.activeColorKey]
                                            border.width: 1; border.color: "#585b70"
                                        }
                                    }

                                    // Input row
                                    Row {
                                        width: parent.width; spacing: 8

                                        // Hex Input Field
                                        Rectangle {
                                            width: parent.width - 88; height: 32; radius: 8; color: shell.surfaceBright
                                            border.width: 1
                                            border.color: hexInput2.activeFocus ? shell.accent : shell.surfaceBorder

                                            TextInput {
                                                id: hexInput2
                                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                                verticalAlignment: Text.AlignVCenter
                                                color: shell.textPrimary; font.pixelSize: 11; font.family: "monospace"
                                                text: shell.activeColorHex
                                                onTextEdited: {
                                                    shell.updateActiveColor(text);
                                                }
                                                Connections {
                                                    target: shell
                                                    function onActiveColorHexChanged() {
                                                        hexInput2.text = shell.activeColorHex;
                                                    }
                                                }
                                            }
                                        }

                                        // Eyedropper Button
                                        Rectangle {
                                            width: 80; height: 32; radius: 8
                                            color: pickerMa2.containsMouse ? shell.accent : shell.surfaceBright
                                            Behavior on color { ColorAnimation { duration: shell.animFast } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: shell.pickerRunning ? "Picking..." : "Pick"
                                                color: pickerMa2.containsMouse ? shell.surface : shell.textPrimary
                                                font.pixelSize: 10; font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                id: pickerMa2
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                                enabled: !shell.pickerRunning
                                                onClicked: {
                                                    shell.pickerRunning = true;
                                                    pickerProc.running = true;
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: shell.pickerRunning ? "Click anywhere on screen to pick color" : "Enter hex starting with # or use screen picker."
                                        color: shell.pickerRunning ? shell.accent : shell.textMuted
                                        font.pixelSize: 9
                                    }
                                }
                            }

                            // Intelligence Palette Card
                            Rectangle {
                                width: parent.width; height: 68; radius: 12; color: shell.surfaceAlt
                                border.width: 1; border.color: shell.surfaceBorder

                                Column {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 8

                                    Text { text: "Intelligence Palette"; color: shell.textPrimary; font.pixelSize: 12; font.weight: Font.Bold }

                                    Rectangle {
                                        width: parent.width; height: 28; radius: 8
                                        color: aiGenMa2.containsMouse ? shell.accent : shell.surfaceBright
                                        Behavior on color { ColorAnimation { duration: shell.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Auto-Harmonize Theme from Accent"
                                            color: aiGenMa2.containsMouse ? shell.surface : shell.textPrimary
                                            font.pixelSize: 10; font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            id: aiGenMa2
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                            onClicked: {
                                                shell.generateFromAccent();
                                            }
                                        }
                                    }
                                }
                            }

                            // Preset Themes Card
                            Rectangle {
                                width: parent.width; height: 140; radius: 12; color: shell.surfaceAlt
                                border.width: 1; border.color: shell.surfaceBorder

                                Column {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 10

                                    Text { text: "Premium Presets"; color: shell.textPrimary; font.pixelSize: 12; font.weight: Font.Bold }

                                    Grid {
                                        columns: 2; spacing: 8; width: parent.width

                                        Repeater {
                                            model: shell.presets
                                            delegate: Rectangle {
                                                width: (customPaletteCol.width - 32) / 2; height: 32; radius: 8; color: presetMa2.containsMouse ? "#2c2c3e" : shell.surfaceBright
                                                border.width: 1; border.color: shell.surfaceBorder

                                                Row {
                                                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                                    
                                                    Rectangle {
                                                        width: 12; height: 12; radius: 6; color: modelData.accent
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        border.width: 1; border.color: "#585b70"
                                                    }

                                                    Text {
                                                        text: modelData.name; color: shell.textPrimary
                                                        font.pixelSize: 10; font.weight: Font.DemiBold
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        elide: Text.ElideRight; width: parent.width - 24
                                                    }
                                                }

                                                MouseArea {
                                                    id: presetMa2
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                                    onClicked: {
                                                        shell.applyPreset(modelData);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STATE 12: PERSONALIZATION MENU
                // =============================================================
                Item {
                    id: personalizationView
                    anchors.fill: parent
                    opacity: shell.currentState === 12 ? 1 : 0; scale: shell.currentState === 12 ? 1 : 0.96; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.setState(0)
                    }

                    Flickable {
                        anchors.fill: parent; anchors.margins: 14
                        contentHeight: personalizationCol.height
                        contentWidth: width
                        clip: true; boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: personalizationCol; width: parent.width; spacing: 12

                            // Header
                            Row {
                                width: parent.width; spacing: 10
                                Item {
                                    width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.centerIn: parent; width: 20; height: 20
                                        source: "icons/back.png"
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: shell.currentState === 12
                                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textPrimary }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(5) }
                                }
                                Text { text: "Personalization"; color: shell.textPrimary; font.pixelSize: 16; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }

                            // 1. Wallpaper Card
                            Rectangle {
                                width: parent.width; height: 64; radius: 14; color: wallpaperCardMa.containsMouse ? shell.surfaceBright : shell.surfaceAlt
                                border.width: 1; border.color: shell.surfaceBorder
                                Behavior on color { ColorAnimation { duration: shell.animFast } }

                                Row {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 12

                                    Rectangle {
                                         id: wpThumbCard
                                         width: 40; height: 40; radius: 8
                                         color: shell.surfaceBright

                                         Rectangle {
                                             id: wpThumbClip
                                             anchors.fill: parent
                                             radius: wpThumbCard.radius
                                             color: "transparent"

                                             layer.enabled: shell.currentState === 12
                                             layer.smooth: true
                                             layer.effect: MultiEffect {
                                                 maskEnabled: true
                                                 maskSource: ShaderEffectSource {
                                                     sourceItem: Rectangle {
                                                         width: wpThumbClip.width
                                                         height: wpThumbClip.height
                                                         radius: wpThumbClip.radius
                                                         color: "white"
                                                     }
                                                 }
                                             }

                                              Image {
                                                  id: personalizationWallpaperPreview
                                                  anchors.fill: parent
                                                  source: (panelWindow && panelWindow.modelData) ? "file://" + WallpaperService.getWallpaper(panelWindow.modelData.name) : ""
                                                  fillMode: Image.PreserveAspectCrop
                                                  visible: source.toString() !== ""

                                                  Connections {
                                                      target: WallpaperService
                                                      function onWallpaperChanged(screenName, path) {
                                                          if (panelWindow && panelWindow.modelData && screenName === panelWindow.modelData.name) {
                                                              personalizationWallpaperPreview.source = "file://" + path;
                                                          }
                                                      }
                                                  }
                                              }
                                         }

                                         Image {
                                             anchors.centerIn: parent; width: 18; height: 18
                                             source: "icons/palette.png"
                                             fillMode: Image.PreserveAspectFit
                                             visible: !wpThumbClip.children[0].visible
                                             layer.enabled: shell.currentState === 12
                                             layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.accent }
                                         }
                                    }

                                    Column {
                                        width: parent.width - 40 - 24 - 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: "Desktop Wallpaper"; color: shell.textPrimary; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: "Select a background image"; color: shell.textSecondary; font.pixelSize: 9 }
                                    }
                                }

                                MouseArea {
                                    id: wallpaperCardMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: shell.setState(10)
                                }
                            }

                            // 2. Color Theme Card
                            Rectangle {
                                width: parent.width; height: 105; radius: 14; color: shell.surfaceAlt
                                border.width: 1; border.color: shell.surfaceBorder

                                Column {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 10

                                    Column {
                                        spacing: 2
                                        Text { text: "Color Theme"; color: shell.textPrimary; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: "Choose theme mode or customize colors"; color: shell.textSecondary; font.pixelSize: 9 }
                                    }

                                    // Segmented control row
                                    Row {
                                        width: parent.width; height: 32; spacing: 8

                                        // Wallpaper Button
                                        Rectangle {
                                            width: (parent.width - 8) / 2; height: parent.height; radius: 8
                                            color: shell.themeMode === "wallpaper" ? shell.accent : shell.surfaceBright
                                            border.width: 1; border.color: shell.themeMode === "wallpaper" ? "transparent" : shell.surfaceBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Wallpaper Colors"
                                                color: shell.themeMode === "wallpaper" ? shell.surface : shell.textPrimary
                                                font.pixelSize: 10; font.weight: Font.DemiBold
                                            }

                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: shell.themeMode = "wallpaper"
                                            }
                                        }

                                        // Custom Button
                                        Rectangle {
                                            width: (parent.width - 8) / 2; height: parent.height; radius: 8
                                            color: shell.themeMode === "custom" ? shell.accent : shell.surfaceBright
                                            border.width: 1; border.color: shell.themeMode === "custom" ? "transparent" : shell.surfaceBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Custom Theme"
                                                color: shell.themeMode === "custom" ? shell.surface : shell.textPrimary
                                                font.pixelSize: 10; font.weight: Font.DemiBold
                                            }

                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (shell.themeMode !== "custom") {
                                                        // First copy wallpaper palette theme to custom colors
                                                        shell.customAccent = shell.wpAccent;
                                                        shell.customSurface = shell.wpSurface;
                                                        shell.customSurfaceAlt = shell.wpSurfaceAlt;
                                                        shell.customSurfaceBright = shell.wpSurfaceBright;
                                                        shell.customTextPrimary = shell.wpTextPrimary;
                                                        shell.customTextSecondary = shell.wpTextSecondary;
                                                        shell.customTextMuted = shell.wpTextMuted;
                                                        shell.customRed = shell.wpRed;
                                                        shell.customGreen = shell.wpGreen;
                                                        shell.customPeach = shell.wpPeach;
                                                        shell.customBlue = shell.wpBlue;
                                                        shell.activeColorHex = shell[shell.activeColorKey].toString();
                                                        shell.saveCustomPalette();
                                                        shell.themeMode = "custom";
                                                    }
                                                    // Go to State 11 to allow customization
                                                    shell.setState(11);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 3. Themed Icons Toggle Card
                            Rectangle {
                                width: parent.width; height: 50; radius: 14; color: shell.surfaceAlt
                                border.width: 1; border.color: shell.surfaceBorder

                                Row {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 12

                                    Rectangle {
                                        width: 28; height: 28; radius: 14
                                        color: Settings.data.colorSchemes.themedIcons ? shell.accent : shell.surfaceBright
                                        anchors.verticalCenter: parent.verticalCenter
                                        Image {
                                            anchors.centerIn: parent; width: 14; height: 14
                                            source: "icons/palette.png"
                                            layer.enabled: shell.currentState === 12
                                            layer.effect: MultiEffect {
                                                brightness: 1.0; colorization: 1.0
                                                colorizationColor: Settings.data.colorSchemes.themedIcons ? shell.surface : shell.textMuted
                                            }
                                        }
                                    }

                                    Column {
                                        width: parent.width - 28 - 44 - 36
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: "Themed Icons"; color: shell.textPrimary; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: "Tint desktop and launcher icons with accent"; color: shell.textSecondary; font.pixelSize: 9 }
                                    }

                                    Image {
                                        width: 44; height: 24
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "icons/on.png"
                                        mirror: !Settings.data.colorSchemes.themedIcons
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: shell.currentState === 12
                                        layer.effect: MultiEffect {
                                            brightness: 1.0
                                            colorization: 1.0
                                            colorizationColor: Settings.data.colorSchemes.themedIcons ? shell.accent : shell.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: Settings.data.colorSchemes.themedIcons = !Settings.data.colorSchemes.themedIcons
                                        }
                                    }
                                }
                            }

                            // 4. Liquid Glass (Hyprglass) Toggle Card
                            Rectangle {
                                width: parent.width; height: 50; radius: 14; color: shell.surfaceAlt
                                border.width: 1; border.color: shell.surfaceBorder

                                Row {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 12

                                    Rectangle {
                                        width: 28; height: 28; radius: 14
                                        color: Settings.data.colorSchemes.hyprglass ? shell.accent : shell.surfaceBright
                                        anchors.verticalCenter: parent.verticalCenter
                                        Image {
                                            anchors.centerIn: parent; width: 14; height: 14
                                            source: "icons/palette.png"
                                            layer.enabled: shell.currentState === 12
                                            layer.effect: MultiEffect {
                                                brightness: 1.0; colorization: 1.0
                                                colorizationColor: Settings.data.colorSchemes.hyprglass ? shell.surface : shell.textMuted
                                            }
                                        }
                                    }

                                    Column {
                                        width: parent.width - 28 - 44 - 36
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: "Liquid Glass (Hyprglass)"; color: shell.textPrimary; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: "Enable glass refraction and diffraction effects"; color: shell.textSecondary; font.pixelSize: 9 }
                                    }

                                    Image {
                                        width: 44; height: 24
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "icons/on.png"
                                        mirror: !Settings.data.colorSchemes.hyprglass
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: shell.currentState === 12
                                        layer.effect: MultiEffect {
                                            brightness: 1.0
                                            colorization: 1.0
                                            colorizationColor: Settings.data.colorSchemes.hyprglass ? shell.accent : shell.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: Settings.data.colorSchemes.hyprglass = !Settings.data.colorSchemes.hyprglass
                                        }
                                    }
                                }
                            }



                        }
                    }
                }

                // =============================================================
                // STATE 13: CLIPBOARD HISTORY POPUP
                // =============================================================
                Item {
                    id: clipboardHistoryView
                    anchors.fill: parent
                    opacity: shell.currentState === 13 ? 1 : 0; scale: shell.currentState === 13 ? 1 : 0.96; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }

                    onVisibleChanged: {
                        if (visible && ClipboardService.active) {
                            ClipboardService.list(100);
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.setState(0)
                    }

                    Flickable {
                        anchors.fill: parent; anchors.margins: 14
                        contentHeight: clipboardCol.height
                        contentWidth: width
                        clip: true; boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: clipboardCol; width: parent.width; spacing: 12

                            // Header
                            Row {
                                width: parent.width
                                spacing: 10

                                Item {
                                    width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.centerIn: parent; width: 20; height: 20
                                        source: "icons/back.png"
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: shell.currentState === 13
                                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textPrimary }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(5) }
                                }

                                Text {
                                    text: "Clipboard History"
                                    color: shell.textPrimary
                                    font.pixelSize: 16; font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 32 - 80 - 20
                                }

                                // Clear All button
                                Rectangle {
                                    width: 70; height: 26; radius: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: clearMa.containsMouse ? shell.accent : shell.surfaceBright
                                    border.width: 1; border.color: clearMa.containsMouse ? "transparent" : shell.surfaceBorder
                                    Behavior on color { ColorAnimation { duration: shell.animFast } }
                                    visible: ClipboardService.items && ClipboardService.items.length > 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Clear All"
                                        color: clearMa.containsMouse ? shell.surface : shell.textPrimary
                                        font.pixelSize: 10; font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        id: clearMa
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            ClipboardService.wipeAll();
                                        }
                                    }
                                }
                            }

                            // Items List
                            Column {
                                width: parent.width; spacing: 6
                                visible: ClipboardService.active && ClipboardService.items && ClipboardService.items.length > 1

                                Repeater {
                                    model: ClipboardService.items.slice(1)

                                    Rectangle {
                                        width: clipboardCol.width; height: 44; radius: 10
                                        color: itemMa.containsMouse ? shell.surfaceBright : shell.surfaceAlt
                                        border.width: 1; border.color: shell.surfaceBorder
                                        Behavior on color { ColorAnimation { duration: shell.animFast } }

                                        Row {
                                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10

                                            // Content Type Icon / Color Preview / Image Preview
                                            Rectangle {
                                                id: previewBox
                                                width: 24; height: 24; radius: 6
                                                color: modelData.contentType === "color" ? modelData.preview : shell.surfaceBright
                                                anchors.verticalCenter: parent.verticalCenter

                                                Rectangle {
                                                    id: previewClip
                                                    anchors.fill: parent
                                                    radius: previewBox.radius
                                                    color: "transparent"

                                                    layer.enabled: modelData.contentType === "image"
                                                    layer.smooth: true
                                                    layer.effect: MultiEffect {
                                                        maskEnabled: true
                                                        maskSource: ShaderEffectSource {
                                                            sourceItem: Rectangle {
                                                                width: previewClip.width; height: previewClip.height; radius: previewClip.radius
                                                                color: "white"
                                                            }
                                                        }
                                                    }

                                                    Image {
                                                        id: imgPreview
                                                        anchors.fill: parent
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        sourceSize.width: 24
                                                        sourceSize.height: 24
                                                        property int rev: ClipboardService.revision
                                                        source: {
                                                            if (modelData.contentType === "image") {
                                                                var data = ClipboardService.getImageData(modelData.id);
                                                                if (data) return data;
                                                                ClipboardService.decodeToDataUrl(modelData.id, modelData.mime, null);
                                                                return "";
                                                            }
                                                            return "";
                                                        }
                                                        visible: modelData.contentType === "image" && source !== ""
                                                    }
                                                }

                                                Image {
                                                    anchors.centerIn: parent; width: 14; height: 14
                                                    visible: modelData.contentType !== "image" && modelData.contentType !== "color"
                                                    source: {
                                                        if (modelData.contentType === "link") return "icons/wifi.png";
                                                        return "icons/palette.png";
                                                    }
                                                    layer.enabled: shell.currentState === 13
                                                    layer.effect: MultiEffect {
                                                        brightness: 1.0; colorization: 1.0
                                                        colorizationColor: shell.accent
                                                    }
                                                }
                                            }

                                            // Text Preview
                                            Column {
                                                width: parent.width - 24 - 20 - 10 - 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text {
                                                    text: {
                                                        var previewText = (modelData.preview || "").trim();
                                                        if (previewText.length > 50) return previewText.substring(0, 47) + "...";
                                                        return previewText;
                                                    }
                                                    color: shell.textPrimary
                                                    font.pixelSize: 11; font.weight: Font.DemiBold
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: modelData.contentType.charAt(0).toUpperCase() + modelData.contentType.slice(1)
                                                    color: shell.textSecondary
                                                    font.pixelSize: 8
                                                }
                                            }

                                            // Delete Button
                                            Item {
                                                width: 20; height: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "×"
                                                    color: delMa.containsMouse ? shell.red : shell.textMuted
                                                    font.pixelSize: 16; font.weight: Font.Bold
                                                    Behavior on color { ColorAnimation { duration: shell.animFast } }
                                                }
                                                MouseArea {
                                                    id: delMa
                                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        ClipboardService.deleteById(String(modelData.id));
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: itemMa
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                ClipboardService.copyToClipboard(modelData.id);
                                                shell.setState(0);
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty Placeholder
                            Rectangle {
                                width: parent.width; height: 60; radius: 14; color: shell.surfaceAlt
                                border.width: 1; border.color: shell.surfaceBorder
                                visible: !ClipboardService.active || !ClipboardService.items || ClipboardService.items.length <= 1

                                Column {
                                    anchors.centerIn: parent; spacing: 4
                                    Text {
                                        text: !ClipboardService.active ? "Clipboard service not active" : "Clipboard is empty"
                                        color: shell.textMuted
                                        font.pixelSize: 11; font.weight: Font.DemiBold
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STATE 14: SCREEN TOOLKIT PANEL
                // =============================================================
                Item {
                    id: screenToolkitView
                    anchors.fill: parent
                    opacity: shell.currentState === 14 ? 1 : 0; scale: shell.currentState === 14 ? 1 : 0.96; visible: shell.currentState === 14 || opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }

                    MouseArea {
                         anchors.fill: parent
                         onClicked: shell.setState(0)
                    }

                    Flickable {
                        anchors.fill: parent; anchors.margins: 14
                        contentHeight: screenToolkitCol.height
                        contentWidth: width
                        clip: true; boundsBehavior: Flickable.StopAtBounds

                        transform: Translate {
                            y: shell.currentState === 14 ? 0 : 20
                            Behavior on y { NumberAnimation { duration: shell.animNormal; easing.type: Easing.OutCubic } }
                        }

                        Column {
                            id: screenToolkitCol; width: parent.width; spacing: 12



                            // Panel loader
                            Loader {
                                id: screenToolkitLoader
                                width: parent.width
                                height: status === Loader.Ready ? implicitHeight : 0
                                source: "ScreenToolkit/Panel.qml"
                                focus: true
                                onLoaded: {
                                    item.pluginApi = screenToolkitApi;
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STATE 15: EMOJI BOARD POPUP
                // =============================================================
                Item {
                    id: emojiBoardView
                    anchors.fill: parent
                    opacity: shell.currentState === 15 ? 1 : 0; scale: shell.currentState === 15 ? 1 : 0.96; visible: shell.currentState === 15 || opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }

                    onVisibleChanged: {
                        if (visible) {
                            emojiSearchInput.text = "";
                            Qt.callLater(() => emojiSearchInput.forceActiveFocus());
                        }
                    }

                    property string activeCategory: "popular"
                    property string searchQuery: ""

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.setState(0)
                    }

                    Column {
                        id: emojiCol
                        x: 14
                        y: 14
                        width: parent.width - 28
                        spacing: 12

                        // Header
                        Row {
                            width: parent.width
                            spacing: 10

                            Item {
                                width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
                                Image {
                                    anchors.centerIn: parent; width: 20; height: 20
                                    source: "icons/back.png"
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: shell.currentState === 15
                                    layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textPrimary }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(5) }
                            }

                            Text {
                                text: "Emoji Board"
                                color: shell.textPrimary
                                font.pixelSize: 14; font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Search Input Field
                        Rectangle {
                            width: parent.width; height: 36; radius: 10
                            color: shell.surfaceAlt
                            border.width: 1; border.color: shell.surfaceBorder

                            Row {
                                anchors.fill: parent; anchors.margins: 8; spacing: 8
                                Image {
                                    width: 14; height: 14
                                    source: "icons/search.png"
                                    anchors.verticalCenter: parent.verticalCenter
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: shell.currentState === 15
                                    layer.effect: MultiEffect {
                                        brightness: 1.0
                                        colorization: 1.0
                                        colorizationColor: shell.textSecondary
                                    }
                                }
                                TextInput {
                                    id: emojiSearchInput
                                    width: parent.width - 30
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: shell.textPrimary
                                    font.pixelSize: 13
                                    selectByMouse: true
                                    focus: false

                                    onTextChanged: {
                                        emojiBoardView.searchQuery = text;
                                        if (text !== "") {
                                            emojiBoardView.activeCategory = "";
                                        } else {
                                            emojiBoardView.activeCategory = "popular";
                                        }
                                    }

                                    Keys.onEscapePressed: {
                                        emojiSearchInput.text = "";
                                        shell.setState(5);
                                    }
                                }
                            }
                        }

                        // Category Tabs
                        Flickable {
                            width: parent.width; height: visible ? 36 : 0
                            contentWidth: categoryRow.width
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            visible: emojiBoardView.searchQuery === ""

                            Row {
                                id: categoryRow
                                spacing: 8
                                Repeater {
                                    model: ["popular", "people", "nature", "food", "travel", "activities", "objects", "symbols", "flags"]
                                    delegate: Rectangle {
                                        width: 36; height: 30; radius: 8
                                        color: emojiBoardView.activeCategory === modelData ? shell.accent : shell.surfaceBright
                                        border.width: 1; border.color: emojiBoardView.activeCategory === modelData ? shell.accent : shell.surfaceBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: {
                                                switch (modelData) {
                                                    case "popular": return "🕒";
                                                    case "people": return "😀";
                                                    case "nature": return "🐱";
                                                    case "food": return "🍔";
                                                    case "travel": return "🚗";
                                                    case "activities": return "⚽";
                                                    case "objects": return "💡";
                                                    case "symbols": return "🔣";
                                                    case "flags": return "🏁";
                                                    default: return "❓";
                                                }
                                            }
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                emojiBoardView.activeCategory = modelData;
                                                emojiSearchInput.text = "";
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Grid of Emojis
                        GridView {
                            id: emojiGrid
                            width: parent.width
                            height: emojiBoardView.searchQuery === "" ? 180 : 216
                            clip: true
                            cellWidth: parent.width / 7
                            cellHeight: cellWidth

                            model: {
                                if (emojiBoardView.searchQuery !== "") {
                                    return EmojiService.search(emojiBoardView.searchQuery.toLowerCase());
                                } else {
                                    return EmojiService.getEmojisByCategory(emojiBoardView.activeCategory);
                                }
                            }

                            delegate: Rectangle {
                                width: emojiGrid.cellWidth - 4; height: width; radius: 8
                                color: emojiMa.containsMouse ? shell.surfaceBright : "transparent"
                                border.width: 1; border.color: emojiMa.containsMouse ? shell.accent : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.emoji
                                    font.pixelSize: 22
                                }

                                MouseArea {
                                    id: emojiMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        EmojiService.copy(modelData.emoji);
                                        shell.setState(0);
                                        shell.pasteActive();
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // STATE 16: KEYBINDINGS HELP POPUP
                // =============================================================
                Item {
                    id: keybindHelpView
                    anchors.fill: parent
                    opacity: shell.currentState === 16 ? 1 : 0; scale: shell.currentState === 16 ? 1 : 0.96; visible: shell.currentState === 16 || opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: shell.setState(0)
                    }

                    Column {
                        id: keybindCol
                        x: 14
                        y: 14
                        width: parent.width - 28
                        spacing: 12

                        // Header
                        Row {
                            width: parent.width
                            spacing: 10

                            Item {
                                width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
                                Image {
                                    anchors.centerIn: parent; width: 20; height: 20
                                    source: "icons/back.png"
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: shell.currentState === 16
                                    layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textPrimary }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(0) }
                            }

                            Text {
                                text: "Keyboard Shortcuts"
                                color: shell.textPrimary
                                font.pixelSize: 14; font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Grid of keybindings
                        Grid {
                            columns: 2
                            spacing: 8
                            width: parent.width

                            Repeater {
                                model: [
                                    { keys: "Super + A", desc: "Toggle App Launcher" },
                                    { keys: "Super + N", desc: "Toggle Control Center" },
                                    { keys: "Super + V", desc: "Toggle Clipboard" },
                                    { keys: "Super + .", desc: "Toggle Emoji Board" },
                                    { keys: "Super + /", desc: "Toggle Keybindings" },
                                    { keys: "Super + L", desc: "Lock Screen" },
                                    { keys: "Ctrl + Alt + Del", desc: "Logout / Power Menu" },
                                    { keys: "Swipe Left/Right", desc: "Switch CC/Launcher/Power" }
                                ]
                                delegate: Rectangle {
                                    width: (keybindCol.width - 8) / 2
                                    height: 38
                                    radius: 8
                                    color: shell.surfaceAlt
                                    border.width: 1
                                    border.color: shell.surfaceBorder

                                    Text {
                                        id: keyText
                                        text: modelData.keys
                                        color: shell.accent
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.desc
                                        color: shell.textPrimary
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                        anchors.left: keyText.right
                                        anchors.leftMargin: 6
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // INTERACTION LAYER
                // =============================================================
                MouseArea {
                    id: mainHoverArea
                    anchors.fill: parent; hoverEnabled: shell.currentState === 0 || shell.currentState === 1
                    acceptedButtons: (shell.currentState <= 1) ? Qt.LeftButton : Qt.NoButton
                    enabled: shell.currentState === 0 || shell.currentState === 1 || shell.currentState === 4 || shell.currentState === 5 || shell.currentState === 6

                    property bool swipeCooldown: false

                    Timer {
                        id: swipeCooldownTimer
                        interval: 200
                        onTriggered: mainHoverArea.swipeCooldown = false
                    }

                    onEntered: { if (shell.currentState === 0 && !shell.hoverCooldown) shell.setState(1); }
                    onExited:  {
                        var elapsed = Date.now() - shell.lastState1Time;
                        if (elapsed > 50) {
                            if (shell.currentState === 1) shell.setState(0);
                        }
                    }
                    onClicked: mouse => {
                        if (shell.currentState <= 1) { shell.setState(5); }
                    }

                    onWheel: (wheel) => {
                        var angleX = wheel.angleDelta.x;
                        var angleY = wheel.angleDelta.y;

                        // Check if it's primarily a horizontal scroll/swipe
                        var isHorizontal = Math.abs(angleX) > Math.abs(angleY);

                        if (isHorizontal) {
                            // Horizontal scroll: always handle state switching
                            var delta = angleX;
                            if (delta !== 0 && Math.abs(delta) >= 40 && !swipeCooldown) {
                                swipeCooldown = true;
                                swipeCooldownTimer.start();

                                var states = [5, 4, 6];
                                var curr = shell.currentState;
                                var idx = states.indexOf(curr);

                                if (delta > 0) { // Swipe left -> Move forward
                                    if (idx === -1) {
                                        shell.setState(5);
                                    } else if (idx < states.length - 1) {
                                        shell.setState(states[idx + 1]);
                                    }
                                } else if (delta < 0) { // Swipe right -> Move backward
                                    if (idx !== -1) {
                                        if (idx > 0) {
                                            shell.setState(states[idx - 1]);
                                        } else {
                                            shell.setState(0);
                                        }
                                    }
                                }
                                wheel.accepted = true;
                            }
                        } else {
                            // Vertical scroll:
                            // If we are in the App Launcher (4) or Control Center (5),
                            // we want to scroll the menus, so let the event pass through.
                            if (shell.currentState === 4 || shell.currentState === 5) {
                                wheel.accepted = false; // Propagate to Flickable underneath
                            } else {
                                // In other states (idle/hovered 0 or 1, or power menu 6), we can switch states
                                var delta = angleY;
                                if (delta !== 0 && Math.abs(delta) >= 40 && !swipeCooldown) {
                                    swipeCooldown = true;
                                    swipeCooldownTimer.start();

                                    var states = [5, 4, 6];
                                    var curr = shell.currentState;
                                    var idx = states.indexOf(curr);

                                    if (delta < 0) { // Scroll up (inverted delta) -> Move forward
                                        if (idx === -1) {
                                            shell.setState(5);
                                        } else if (idx < states.length - 1) {
                                            shell.setState(states[idx + 1]);
                                        }
                                    } else if (delta > 0) { // Scroll down (inverted delta) -> Move backward
                                        if (idx !== -1) {
                                            if (idx > 0) {
                                                shell.setState(states[idx - 1]);
                                            } else {
                                                shell.setState(0);
                                            }
                                        }
                                    }
                                    wheel.accepted = true;
                                }
                            }
                        }
                    }

                    Connections {
                        target: shell
                        function onHoverCooldownChanged() {
                            if (!shell.hoverCooldown && shell.currentState === 0 && mainHoverArea.containsMouse) {
                                shell.setState(1);
                            }
                        }
                    }
                }
            } // Close island Rectangle to prevent clipping workspaceCircle

            // =============================================================
            // WORKSPACE INDICATOR CIRCLE
            // =============================================================
                Rectangle {
                    id: workspaceCircle
                    z: -1
                    anchors.left: island.right
                    anchors.leftMargin: panelWindow.wsCircleSpacing
                    anchors.top: island.top

                    width: panelWindow.wsCircleWidth
                    height: panelWindow.wsCircleWidth
                    radius: width / 2

                    color: "transparent"
                    clip: true

                    opacity: panelWindow.wsCircleOpacity
                    scale: panelWindow.wsCircleScale

                    LiquidGlassBackground {
                        id: wsLiquidGlassBg
                        anchors.fill: parent
                        radius: parent.radius
                        surfaceColor: shell.surface
                        accentColor: shell.accent
                        borderColor: shell.surfaceBorder
                        active: Settings.isLoaded && Settings.data.colorSchemes.hyprglass
                    }

                    // Desktop number text
                    Text {
                        anchors.centerIn: parent
                        text: panelWindow.workspaceId
                        color: idleClock.color
                        font: idleClock.font
                    }
                }

                // Drop Shadow for the floating workspace circle
                Rectangle {
                    id: wsCircleShadowSource
                    width: workspaceCircle.width
                    height: workspaceCircle.height
                    anchors.horizontalCenter: workspaceCircle.horizontalCenter
                    anchors.top: workspaceCircle.top
                    radius: workspaceCircle.radius
                    color: "black"
                    visible: false
                }

                MultiEffect {
                    source: wsCircleShadowSource
                    anchors.fill: wsCircleShadowSource
                    z: -1
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.4)
                    shadowBlur: 0.65
                    shadowVerticalOffset: shell.currentState === 0 ? 2 : 6
                    shadowHorizontalOffset: 0
                    opacity: panelWindow.wsCircleOpacity * (shell.currentState === 0 ? 0.45 : 1.0)
                    visible: !Settings.data.colorSchemes.hyprglass
                    Behavior on opacity { NumberAnimation { duration: shell.animFast } }
                    Behavior on shadowVerticalOffset { NumberAnimation { duration: shell.animFast } }
                }
        }
    }

    LockScreen {
        id: lockScreen
        locked: shell.locked
        accentColor: shell.accent
        timeString: shell.currentTime12h
        onUnlocked: shell.locked = false
    }

}