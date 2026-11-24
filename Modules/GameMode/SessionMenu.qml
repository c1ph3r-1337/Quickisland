import QtQuick
import QtQuick.Effects
import "GameModeMenuLayout.js" as GameModeMenuLayout

Item {
    id: root

    property var shellRoot

    width: GameModeMenuLayout.sessionPanelWidth()
    height: GameModeMenuLayout.sessionPanelHeight

    Rectangle {
        anchors.fill: parent
        color: root.shellRoot.surface
        radius: 0
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.shellRoot.setState(0)
    }

    Row {
        x: GameModeMenuLayout.sessionSidePadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: GameModeMenuLayout.sessionGap

        Repeater {
            model: [
                { label: "Lock", danger: false, action: "lock", icon: "../../icons/lock.png" },
                { label: "Suspend", danger: false, action: "suspend", icon: "../../icons/suspend.png" },
                { label: "Logout", danger: false, action: "logout", icon: "../../icons/signout.png" },
                { label: "Reboot", danger: true, action: "reboot", icon: "../../icons/restart.png" },
                { label: "Off", danger: true, action: "poweroff", icon: "../../icons/poweroff.png" }
            ]

            Rectangle {
                id: button
                width: GameModeMenuLayout.sessionButtonWidth
                height: width
                radius: 0

                readonly property color dangerColor: {
                    var r = root.shellRoot.red.r;
                    var g = root.shellRoot.red.g;
                    var b = root.shellRoot.red.b;
                    var luminance = 0.299 * r + 0.587 * g + 0.114 * b;
                    if (r > g * 1.15 && r > b * 1.15 && luminance >= 0.45)
                        return root.shellRoot.red;
                    return "#f38ba8";
                }

                color: modelData.danger
                    ? (buttonMouse.containsMouse
                        ? Qt.rgba(dangerColor.r, dangerColor.g, dangerColor.b, 0.22)
                        : Qt.rgba(dangerColor.r, dangerColor.g, dangerColor.b, 0.09))
                    : (buttonMouse.containsMouse ? root.shellRoot.surfaceBright : root.shellRoot.surfaceAlt)

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    Image {
                        width: 26
                        height: 26
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: modelData.icon
                        fillMode: Image.PreserveAspectFit
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            brightness: 1.0
                            colorization: 1.0
                            colorizationColor: modelData.danger
                                ? button.dangerColor
                                : (buttonMouse.containsMouse ? root.shellRoot.accent : root.shellRoot.textSecondary)
                        }
                    }

                    Text {
                        text: modelData.label
                        color: modelData.danger
                            ? (buttonMouse.containsMouse ? "#ffffff" : button.dangerColor)
                            : (buttonMouse.containsMouse ? root.shellRoot.textPrimary : root.shellRoot.textSecondary)
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    id: buttonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (modelData.action === "lock") root.shellRoot.doLock();
                        else if (modelData.action === "suspend") root.shellRoot.doSuspend();
                        else if (modelData.action === "logout") root.shellRoot.doLogout();
                        else if (modelData.action === "reboot") root.shellRoot.doReboot();
                        else if (modelData.action === "poweroff") root.shellRoot.doPoweroff();
                        root.shellRoot.setState(0);
                    }
                }
            }
        }
    }
}
