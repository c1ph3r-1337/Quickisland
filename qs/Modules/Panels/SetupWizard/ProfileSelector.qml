import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(520 * Style.uiScaleRatio)
  preferredHeight: Math.round(240 * Style.uiScaleRatio)

  panelAnchorHorizontalCenter: true
  panelAnchorVerticalCenter: true

  closeWithEscape: true

  // Make SmartPanel background and border transparent
  panelBackgroundColor: "transparent"
  panelBorderColor: "transparent"
  blurEnabled: false // Disable blur behind the invisible panel

  signal quickislandSelected

  // Property to track current selection (0 = Quickisland Only, 1 = Quickisland)
  property int selectedIndex: 0

  // Input guard to prevent repeated Enter keypresses on startup
  property bool inputGuardActive: true
  property bool shouldLaunch: false

  onOpened: {
    root.inputGuardActive = true;
    inputGuardTimer.restart();
  }

  Timer {
    id: inputGuardTimer
    interval: 500
    running: false
    repeat: false
    onTriggered: {
      root.inputGuardActive = false;
    }
  }

  // Process to launch quickisland via systemd-run to escape the cgroup cleanup
  Process {
    id: launchQuickislandProcess
    command: root.shouldLaunch ? ["systemd-run", "--user", "--working-dir=" + Quickshell.env("HOME") + "/universal-hypr-shell", "python", "-m", "uhs.app", "switch", "hyde-default", "--apply", "--force"] : []
    running: root.shouldLaunch
    onExited: function (exitCode) {
      Logger.i("ProfileSelector", "Quickisland launch process exited with code " + exitCode);
      root.shouldLaunch = false;
    }
  }

  function launchQuickisland() {
    root.shouldLaunch = true;
    root.close();
  }

  panelContent: Item {
    id: panelContentInner
    implicitWidth: root.preferredWidth
    implicitHeight: root.preferredHeight
    focus: true

    Component.onCompleted: {
      forceActiveFocus();
    }

    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Left) {
        root.selectedIndex = 0;
        event.accepted = true;
      } else if (event.key === Qt.Key_Right) {
        root.selectedIndex = 1;
        event.accepted = true;
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (root.inputGuardActive) {
          event.accepted = true;
          return;
        }
        if (root.selectedIndex === 0) {
          root.close();
          root.quickislandSelected();
        } else if (root.selectedIndex === 1) {
          root.launchQuickisland();
        }
        event.accepted = true;
      }
    }

    RowLayout {
      anchors.fill: parent
      spacing: Style.marginL

      // Quickisland Only Card
      Rectangle {
        id: quickislandCard
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.radiusL * 1.2
        color: Color.mSurface
        scale: (root.selectedIndex === 0) ? 1.04 : 1.0

        Behavior on scale { NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutBack } }

        MouseArea {
          id: quickislandMA
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.selectedIndex = 0
          onClicked: {
            root.close();
            root.quickislandSelected();
          }
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginS
          Layout.alignment: Qt.AlignVCenter

          // Circular Icon
          Rectangle {
            width: 54
            height: 54
            radius: width / 2
            color: Color.mSurfaceVariant
            opacity: 0.8
            Layout.alignment: Qt.AlignHCenter

            NIcon {
              icon: "device-desktop"
              pointSize: Style.fontSizeXL
              color: Color.mOnSurfaceVariant
              anchors.centerIn: parent
            }
          }

          NText {
            text: "Quickisland Only"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.alignment: Qt.AlignHCenter
          }

          NText {
            text: "Full desktop overlay"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
          }
        }
      }

      // Quickisland Card
      Rectangle {
        id: quickislandCard
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.radiusL * 1.2
        color: Color.mSurface
        scale: (root.selectedIndex === 1) ? 1.04 : 1.0

        Behavior on scale { NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutBack } }

        MouseArea {
          id: quickislandMA
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.selectedIndex = 1
          onClicked: {
            root.launchQuickisland();
          }
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginS
          Layout.alignment: Qt.AlignVCenter

          // Circular Icon
          Rectangle {
            width: 54
            height: 54
            radius: width / 2
            color: Color.mSurfaceVariant
            opacity: 0.8
            Layout.alignment: Qt.AlignHCenter

            NIcon {
              icon: "feather"
              pointSize: Style.fontSizeXL
              color: Color.mOnSurfaceVariant
              anchors.centerIn: parent
            }
          }

          NText {
            text: "Quickisland"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.alignment: Qt.AlignHCenter
          }

          NText {
            text: "Minimal desktop"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
          }
        }
      }
    }
  }
}
