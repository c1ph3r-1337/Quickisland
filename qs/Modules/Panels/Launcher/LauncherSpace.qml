import QtQuick
import QtQuick.Controls
import Quickshell

import qs.Commons
import qs.Modules.MainScreen
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  // Reference to core (set after panelContent loads)
  property var launcherCoreRef: null

  // Expose core launcher for external access (e.g., IPC)
  readonly property string searchText: launcherCoreRef ? launcherCoreRef.searchText : ""
  readonly property int selectedIndex: launcherCoreRef ? launcherCoreRef.selectedIndex : 0
  readonly property var results: launcherCoreRef ? launcherCoreRef.results : []
  readonly property var activeProvider: launcherCoreRef ? launcherCoreRef.activeProvider : null
  readonly property var currentProvider: launcherCoreRef ? launcherCoreRef.currentProvider : null
  readonly property bool isGridView: launcherCoreRef ? (launcherCoreRef.isGridView ?? false) : false
  readonly property int gridColumns: launcherCoreRef ? (launcherCoreRef.gridColumns ?? 5) : 5

  function setSearchText(text) {
    if (launcherCoreRef)
      launcherCoreRef.setSearchText(text);
  }

  // Preview panel support
  readonly property bool previewActive: {
    if (!launcherCoreRef)
      return false;
    var provider = launcherCoreRef.activeProvider;
    if (!provider || !provider.hasPreview)
      return false;
    if (!Settings.data.appLauncher.enableClipPreview)
      return false;
    return selectedIndex >= 0 && results && !!results[selectedIndex];
  }
  readonly property int previewPanelWidth: Math.round(400 * Style.uiScaleRatio)

  // Panel sizing
  readonly property int listPanelWidth: Math.round(500 * Style.uiScaleRatio)
  readonly property int totalBaseWidth: listPanelWidth + Style.margin2L

  preferredWidth: Math.round(450 * Style.uiScaleRatio)
  preferredHeight: preferredWidth
  preferredWidthRatio: 0.5
  preferredHeightRatio: 0.8
  
  panelBackgroundColor: "transparent"
  panelBorderColor: "transparent"
  blurEnabled: false

  // Always center for Disk Launcher
  panelAnchorHorizontalCenter: true
  panelAnchorVerticalCenter: true
  panelAnchorLeft: false
  panelAnchorRight: false
  panelAnchorBottom: false
  panelAnchorTop: false

  panelContent: Rectangle {
    id: ui
    color: "transparent"
    opacity: root.isPanelOpen ? 1.0 : 0.0
    scale: root.isPanelOpen ? 1.0 : 0.8

    Component.onCompleted: root.launcherCoreRef = launcherCore

    Behavior on opacity {
      NumberAnimation {
        duration: 300
        easing.type: Easing.OutCubic
      }
    }

    Behavior on scale {
      NumberAnimation {
        duration: 300
        easing.type: Easing.OutCubic
      }
    }

    // Core launcher (state, providers, UI)
    LauncherSpaceCore {
      id: launcherCore
      anchors.fill: parent
      screen: root.screen
      isOpen: root.isPanelOpen
      onRequestClose: root.close()
      // Defer so the signal emission completes before SmartPanel
      // sets isPanelOpen=false and the contentLoader destroys us.
      onRequestCloseImmediately: Qt.callLater(root.closeImmediately)
    }
  }
}
