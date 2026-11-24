import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  spacing: Style.marginL
  Layout.fillWidth: true

  function scheduleHyprlandSync() {
    systemSyncTimer.restart();
  }

  function commitKeybind(action, newKeybinds) {
    if (!newKeybinds || newKeybinds.length === 0)
      return;

    const key = String(newKeybinds[0]).trim();
    const requiresSuper = action !== "sessionMenuKeybind";
    const hasExpectedModifiers = requiresSuper
      ? /^(Super|Meta)\+(?:(?:Ctrl|Alt|Shift)\+)*[^+]+$/i.test(key)
      : /^(?:(?:Ctrl|Alt|Shift|Super|Meta)\+)+[^+]+$/i.test(key);
    if (!hasExpectedModifiers) {
      ToastService.showWarning(requiresSuper ? "Super modifier required" : "Shortcut modifier required", "Choose a modified shortcut for this action.");
      return;
    }
    const actions = [
      "settingsKeybind", "launcherKeybind", "gameModeKeybind", "sessionMenuKeybind",
      "keybinds.airdrop", "keybinds.controlCenter", "keybinds.clipboard", "keybinds.emoji",
      "keybinds.keyboardShortcuts", "keybinds.lockScreen", "keybinds.fullscreen", "keybinds.screenTools",
      "keybinds.monitorSettings", "keybinds.wallpaper", "keybinds.themePicker", "keybinds.virtualOverview",
      "keybinds.overviewAlternate", "keybinds.workspaceOverview", "keybinds.windowFocusLeft", "keybinds.windowFocusRight",
      "keybinds.moveWindowLeft", "keybinds.moveWindowRight"
    ];
    for (let i = 0; i < actions.length; i++) {
      if (actions[i] !== action && root.keybindValue(actions[i]).toLowerCase() === key.toLowerCase()) {
        ToastService.showWarning("Shortcut already in use", "Choose a different shortcut for each QuickIsland action.");
        return;
      }
    }

    root.setKeybindValue(action, key);
    scheduleHyprlandSync();
  }

  function keybindValue(path) {
    const parts = path.split(".");
    return String(parts.length === 2 ? Settings.data.quickisland[parts[0]][parts[1]] : Settings.data.quickisland[path]);
  }

  function setKeybindValue(path, value) {
    const parts = path.split(".");
    if (parts.length === 2)
      Settings.data.quickisland[parts[0]][parts[1]] = value;
    else
      Settings.data.quickisland[path] = value;
  }

  function resetToDefaults() {
    const islandFields = ["notchMode", "notchFlare", "barHeight", "collapsedWidth", "expandedHeight", "minExpandedWidth"];
    for (let i = 0; i < islandFields.length; i++) {
      const field = islandFields[i];
      Settings.data.islandConfig[field] = Settings.getDefaultValue("islandConfig." + field);
    }

    const quickFields = [
      "animationsEnabled", "animationSpeed", "mediaVisualizerEnabled", "workspaceIndicatorDuration",
      "gameModeWorkspaceIndicatorDuration", "gameModeBarEnabled", "gameModeBarHeight",
      "settingsKeybind", "launcherKeybind", "gameModeKeybind", "sessionMenuKeybind"
    ];
    for (let j = 0; j < quickFields.length; j++) {
      const field = quickFields[j];
      Settings.data.quickisland[field] = Settings.getDefaultValue("quickisland." + field);
    }

    const keybindFields = [
      "airdrop", "controlCenter", "clipboard", "emoji", "keyboardShortcuts", "lockScreen", "fullscreen",
      "screenTools", "monitorSettings", "wallpaper", "themePicker", "virtualOverview", "overviewAlternate", "workspaceOverview",
      "windowFocusLeft", "windowFocusRight", "moveWindowLeft", "moveWindowRight"
    ];
    for (let n = 0; n < keybindFields.length; n++) {
      const field = keybindFields[n];
      Settings.data.quickisland.keybinds[field] = Settings.getDefaultValue("quickisland.keybinds." + field);
    }

    const windowFields = [
      "gapsIn", "gapsOut", "borderSize", "rounding", "activeOpacity", "inactiveOpacity",
      "fullscreenOpacity", "shadowEnabled", "blurEnabled", "animationsEnabled"
    ];
    for (let k = 0; k < windowFields.length; k++) {
      const field = windowFields[k];
      Settings.data.quickisland.windows[field] = Settings.getDefaultValue("quickisland.windows." + field);
    }

    Settings.data.ui.fontDefault = Settings.getDefaultValue("ui.fontDefault");
    Settings.data.ui.fontDefaultScale = Settings.getDefaultValue("ui.fontDefaultScale");
    Settings.data.ui.fontFixed = Settings.getDefaultValue("ui.fontFixed");
    Settings.data.ui.fontFixedScale = Settings.getDefaultValue("ui.fontFixedScale");
    Settings.saveImmediate();
    scheduleHyprlandSync();
  }

  Timer {
    id: systemSyncTimer
    interval: 800
    repeat: false
    onTriggered: {
      Settings.saveImmediate();
      syncHyprlandProcess.command = [
        "python3",
        Qt.resolvedUrl("../../../../../scripts/sync_settings.py").toString().replace("file://", ""),
        "--settings", Settings.settingsFile,
        "--shell-dir", Quickshell.shellDir
      ];
      syncHyprlandProcess.running = false;
      syncHyprlandProcess.running = true;
    }
  }

  Process {
    id: syncHyprlandProcess
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const output = text.trim();
        if (output)
          console.log("[Settings]", output);
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        const output = text.trim();
        if (output)
          console.warn("[Settings]", output);
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginL

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXXS
      NText {
        text: "QuickIsland"
        pointSize: Style.fontSizeXXL
        font.weight: Style.fontWeightBold
        color: QuickIslandPalette.mOnSurface
      }
      NText {
        Layout.fillWidth: true
        text: "Tune the pill, notch, Game Mode bar, fonts, motion, and system window behavior. Changes save automatically."
        pointSize: Style.fontSizeS
        color: QuickIslandPalette.mOnSurfaceVariant
        wrapMode: Text.WordWrap
      }
    }

    NButton {
      text: "Reset QuickIsland defaults"
      icon: "restore"
      outlined: true
      onClicked: root.resetToDefaults()
    }
  }

  NDivider { Layout.fillWidth: true }

  NLabel {
    Layout.fillWidth: true
    label: "Notch and pill"
    description: "These values control the collapsed pill, expanded panel, and notch layout."
  }

  NToggle {
    label: "Use notch layout"
    description: "Use the notched island shape while idle; off keeps the standard pill shape."
    checked: Settings.data.islandConfig.notchMode
    defaultValue: Settings.getDefaultValue("islandConfig.notchMode")
    onToggled: checked => Settings.data.islandConfig.notchMode = checked
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Notch flare"
    from: 0
    to: 40
    stepSize: 1
    value: Settings.data.islandConfig.notchFlare
    defaultValue: Settings.getDefaultValue("islandConfig.notchFlare")
    showReset: true
    text: Math.round(value) + " px"
    onMoved: value => Settings.data.islandConfig.notchFlare = value
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Bar and notch height"
    from: 20
    to: 60
    stepSize: 1
    value: Settings.data.islandConfig.barHeight
    defaultValue: Settings.getDefaultValue("islandConfig.barHeight")
    showReset: true
    text: Math.round(value) + " px"
    onMoved: value => Settings.data.islandConfig.barHeight = value
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Collapsed pill width"
    from: 60
    to: 280
    stepSize: 1
    value: Settings.data.islandConfig.collapsedWidth
    defaultValue: Settings.getDefaultValue("islandConfig.collapsedWidth")
    showReset: true
    text: Math.round(value) + " px"
    onMoved: value => Settings.data.islandConfig.collapsedWidth = value
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Expanded notch height"
    from: 80
    to: 500
    stepSize: 1
    value: Settings.data.islandConfig.expandedHeight
    defaultValue: Settings.getDefaultValue("islandConfig.expandedHeight")
    showReset: true
    text: Math.round(value) + " px"
    onMoved: value => Settings.data.islandConfig.expandedHeight = value
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Minimum expanded width"
    from: 250
    to: 1000
    stepSize: 5
    value: Settings.data.islandConfig.minExpandedWidth
    defaultValue: Settings.getDefaultValue("islandConfig.minExpandedWidth")
    showReset: true
    text: Math.round(value) + " px"
    onMoved: value => Settings.data.islandConfig.minExpandedWidth = value
  }

  NDivider { Layout.fillWidth: true }

  NLabel {
    Layout.fillWidth: true
    label: "Game Mode bar"
    description: "Keep the lightweight full-width bar configurable without changing the regular pill or notch."
  }

  NToggle {
    label: "Show Game Mode bar"
    description: "When off, Game Mode keeps its compact island instead of expanding to the top bar."
    checked: Settings.data.quickisland.gameModeBarEnabled
    defaultValue: Settings.getDefaultValue("quickisland.gameModeBarEnabled")
    onToggled: checked => Settings.data.quickisland.gameModeBarEnabled = checked
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Game Mode bar height"
    from: 20
    to: 60
    stepSize: 1
    value: Settings.data.quickisland.gameModeBarHeight
    defaultValue: Settings.getDefaultValue("quickisland.gameModeBarHeight")
    showReset: true
    text: Math.round(value) + " px"
    onMoved: value => Settings.data.quickisland.gameModeBarHeight = Math.round(value)
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Game Mode workspace number duration"
    from: 250
    to: 1500
    stepSize: 50
    value: Settings.data.quickisland.gameModeWorkspaceIndicatorDuration
    defaultValue: Settings.getDefaultValue("quickisland.gameModeWorkspaceIndicatorDuration")
    showReset: true
    text: Math.round(value) + " ms"
    onMoved: value => Settings.data.quickisland.gameModeWorkspaceIndicatorDuration = Math.round(value)
  }

  NToggle {
    label: "Show playback visualizer"
    description: "Animate the small playback bars while media is playing."
    checked: Settings.data.quickisland.mediaVisualizerEnabled
    defaultValue: Settings.getDefaultValue("quickisland.mediaVisualizerEnabled")
    onToggled: checked => Settings.data.quickisland.mediaVisualizerEnabled = checked
  }

  NDivider { Layout.fillWidth: true }

  NLabel {
    Layout.fillWidth: true
    label: "Typography"
    description: "The default font and scale update QuickIsland text live. Monospace font remains available for system tools."
  }

  NSearchableComboBox {
    Layout.fillWidth: true
    label: "QuickIsland and system font"
    description: "Choose from installed fonts."
    model: FontService.availableFonts
    currentKey: Settings.data.ui.fontDefault
    defaultValue: Settings.getDefaultValue("ui.fontDefault")
    settingsPath: "ui.fontDefault"
    placeholder: "Choose a font"
    searchPlaceholder: "Search fonts"
    popupHeight: 420
    onSelected: key => Settings.data.ui.fontDefault = key
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Default font scale"
    from: 0.75
    to: 1.5
    stepSize: 0.01
    value: Settings.data.ui.fontDefaultScale
    defaultValue: Settings.getDefaultValue("ui.fontDefaultScale")
    showReset: true
    text: Math.round(value * 100) + "%"
    onMoved: value => Settings.data.ui.fontDefaultScale = value
  }

  NSearchableComboBox {
    Layout.fillWidth: true
    label: "Monospace font"
    model: FontService.monospaceFonts
    currentKey: Settings.data.ui.fontFixed
    defaultValue: Settings.getDefaultValue("ui.fontFixed")
    settingsPath: "ui.fontFixed"
    placeholder: "Choose a monospace font"
    searchPlaceholder: "Search fonts"
    popupHeight: 320
    onSelected: key => Settings.data.ui.fontFixed = key
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Monospace font scale"
    from: 0.75
    to: 1.5
    stepSize: 0.01
    value: Settings.data.ui.fontFixedScale
    defaultValue: Settings.getDefaultValue("ui.fontFixedScale")
    showReset: true
    text: Math.round(value * 100) + "%"
    onMoved: value => Settings.data.ui.fontFixedScale = value
  }

  NDivider { Layout.fillWidth: true }

  NLabel {
    Layout.fillWidth: true
    label: "QuickIsland motion"
    description: "A zero animation speed keeps all QuickIsland panels immediate. Game Mode continues to suppress decorative motion."
  }

  NToggle {
    label: "Animate QuickIsland panels"
    checked: Settings.data.quickisland.animationsEnabled
    defaultValue: Settings.getDefaultValue("quickisland.animationsEnabled")
    onToggled: checked => Settings.data.quickisland.animationsEnabled = checked
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "QuickIsland animation speed"
    from: 0.25
    to: 2
    stepSize: 0.05
    value: Settings.data.quickisland.animationSpeed
    defaultValue: Settings.getDefaultValue("quickisland.animationSpeed")
    showReset: true
    text: Math.round(value * 100) + "%"
    enabled: Settings.data.quickisland.animationsEnabled
    onMoved: value => Settings.data.quickisland.animationSpeed = value
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Workspace number duration"
    from: 200
    to: 1200
    stepSize: 50
    value: Settings.data.quickisland.workspaceIndicatorDuration
    defaultValue: Settings.getDefaultValue("quickisland.workspaceIndicatorDuration")
    showReset: true
    text: Math.round(value) + " ms"
    onMoved: value => Settings.data.quickisland.workspaceIndicatorDuration = Math.round(value)
  }

  NDivider { Layout.fillWidth: true }

  NLabel {
    Layout.fillWidth: true
    label: "Window layout and appearance"
    description: "These settings update Hyprland and are restored after Game Mode exits."
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Inner window gap"
    from: 0
    to: 30
    stepSize: 1
    value: Settings.data.quickisland.windows.gapsIn
    defaultValue: Settings.getDefaultValue("quickisland.windows.gapsIn")
    showReset: true
    text: Math.round(value) + " px"
    onMoved: value => { Settings.data.quickisland.windows.gapsIn = Math.round(value); root.scheduleHyprlandSync(); }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Outer window gap"
    from: 0
    to: 50
    stepSize: 1
    value: Settings.data.quickisland.windows.gapsOut
    defaultValue: Settings.getDefaultValue("quickisland.windows.gapsOut")
    showReset: true
    text: Math.round(value) + " px"
    onMoved: value => { Settings.data.quickisland.windows.gapsOut = Math.round(value); root.scheduleHyprlandSync(); }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Window border width"
    from: 0
    to: 8
    stepSize: 1
    value: Settings.data.quickisland.windows.borderSize
    defaultValue: Settings.getDefaultValue("quickisland.windows.borderSize")
    showReset: true
    text: Math.round(value) + " px"
    onMoved: value => { Settings.data.quickisland.windows.borderSize = Math.round(value); root.scheduleHyprlandSync(); }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Window corner radius"
    from: 0
    to: 40
    stepSize: 1
    value: Settings.data.quickisland.windows.rounding
    defaultValue: Settings.getDefaultValue("quickisland.windows.rounding")
    showReset: true
    text: Math.round(value) + " px"
    onMoved: value => { Settings.data.quickisland.windows.rounding = Math.round(value); root.scheduleHyprlandSync(); }
  }

  NToggle {
    label: "Window shadows"
    checked: Settings.data.quickisland.windows.shadowEnabled
    defaultValue: Settings.getDefaultValue("quickisland.windows.shadowEnabled")
    onToggled: checked => { Settings.data.quickisland.windows.shadowEnabled = checked; root.scheduleHyprlandSync(); }
  }

  NToggle {
    label: "Window blur"
    checked: Settings.data.quickisland.windows.blurEnabled
    defaultValue: Settings.getDefaultValue("quickisland.windows.blurEnabled")
    onToggled: checked => { Settings.data.quickisland.windows.blurEnabled = checked; root.scheduleHyprlandSync(); }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Active window opacity"
    from: 0.5
    to: 1
    stepSize: 0.01
    value: Settings.data.quickisland.windows.activeOpacity
    defaultValue: Settings.getDefaultValue("quickisland.windows.activeOpacity")
    showReset: true
    text: Math.round(value * 100) + "%"
    onMoved: value => { Settings.data.quickisland.windows.activeOpacity = value; root.scheduleHyprlandSync(); }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Inactive window opacity"
    from: 0.5
    to: 1
    stepSize: 0.01
    value: Settings.data.quickisland.windows.inactiveOpacity
    defaultValue: Settings.getDefaultValue("quickisland.windows.inactiveOpacity")
    showReset: true
    text: Math.round(value * 100) + "%"
    onMoved: value => { Settings.data.quickisland.windows.inactiveOpacity = value; root.scheduleHyprlandSync(); }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Fullscreen window opacity"
    from: 0.5
    to: 1
    stepSize: 0.01
    value: Settings.data.quickisland.windows.fullscreenOpacity
    defaultValue: Settings.getDefaultValue("quickisland.windows.fullscreenOpacity")
    showReset: true
    text: Math.round(value * 100) + "%"
    onMoved: value => { Settings.data.quickisland.windows.fullscreenOpacity = value; root.scheduleHyprlandSync(); }
  }

  NToggle {
    label: "Hyprland window animations"
    description: "Leave the selected Hyprland animation profile intact and control its global enabled state."
    checked: Settings.data.quickisland.windows.animationsEnabled
    defaultValue: Settings.getDefaultValue("quickisland.windows.animationsEnabled")
    onToggled: checked => { Settings.data.quickisland.windows.animationsEnabled = checked; root.scheduleHyprlandSync(); }
  }

  NDivider { Layout.fillWidth: true }

  NLabel {
    Layout.fillWidth: true
    label: "QuickIsland shortcuts"
    description: "Edit the existing QuickIsland shortcuts for its panels, launcher, workspaces, Game Mode, and session menu. Changes apply after Hyprland reloads its keybindings."
  }

  Repeater {
    model: [
      { path: "settingsKeybind", label: "Open QuickIsland settings" },
      { path: "launcherKeybind", label: "Open app launcher" },
      { path: "gameModeKeybind", label: "Toggle Game Mode" },
      { path: "sessionMenuKeybind", label: "Open session menu" },
      { path: "keybinds.airdrop", label: "Open AirDrop" },
      { path: "keybinds.controlCenter", label: "Open Control Center" },
      { path: "keybinds.clipboard", label: "Open clipboard history" },
      { path: "keybinds.emoji", label: "Open emoji picker" },
      { path: "keybinds.keyboardShortcuts", label: "Open shortcut list" },
      { path: "keybinds.lockScreen", label: "Lock screen" },
      { path: "keybinds.fullscreen", label: "Toggle fullscreen mode" },
      { path: "keybinds.screenTools", label: "Open screen tools" },
      { path: "keybinds.monitorSettings", label: "Open monitor settings" },
      { path: "keybinds.wallpaper", label: "Open wallpaper chooser" },
      { path: "keybinds.themePicker", label: "Open theme picker" },
      { path: "keybinds.virtualOverview", label: "Open virtual workspace overview" },
      { path: "keybinds.overviewAlternate", label: "Alternate virtual overview shortcut" },
      { path: "keybinds.workspaceOverview", label: "Open workspace overview" },
      { path: "keybinds.windowFocusLeft", label: "Focus window to the left" },
      { path: "keybinds.windowFocusRight", label: "Focus window to the right" },
      { path: "keybinds.moveWindowLeft", label: "Move window left" },
      { path: "keybinds.moveWindowRight", label: "Move window right" }
    ]
    delegate: NKeybindRecorder {
      required property var modelData
      Layout.fillWidth: true
      label: modelData.label
      currentKeybinds: [root.keybindValue(modelData.path)]
      defaultKeybind: Settings.getDefaultValue("quickisland." + modelData.path)
      settingsPath: "quickisland." + modelData.path
      maxKeybinds: 1
      requireModifierForNormalKeys: modelData.path === "sessionMenuKeybind"
      onKeybindsChanged: keys => root.commitKeybind(modelData.path, keys)
    }
  }

  NLabel {
    Layout.fillWidth: true
    label: "More settings"
    description: "The sidebar tabs also include the full media, launcher, notification, lock screen, wallpaper, control center, and system settings. Their existing controls and per-setting reset buttons remain available."
  }
}
