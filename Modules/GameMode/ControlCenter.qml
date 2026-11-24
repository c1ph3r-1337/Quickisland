import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property var shellRoot
    readonly property var sr: shellRoot

    anchors.fill: parent

    function isActive(action) {
        switch (action) {
        case "wifi": return sr.wifiEnabled;
        case "audio": return !sr.sysMuted;
        case "bluetooth": return sr.btPowered;
        case "peace": return sr.peaceMode;
        case "night": return sr.nightMode;
        default: return false;
        }
    }

    function statusFor(action) {
        switch (action) {
        case "wifi": return !sr.wifiEnabled ? "Off" : (sr.wifiConnected ? sr.wifiSSID : "Disconnected");
        case "audio": return sr.sysMuted ? "Muted" : Math.round(sr.sysVolume * 100) + "%";
        case "bluetooth": return sr.btPowered ? "On" : "Off";
        case "peace": return sr.peaceMode ? "On" : "Off";
        case "night": return sr.nightMode ? "On" : "Off";
        default: return "";
        }
    }

    function activate(action) {
        switch (action) {
        case "wifi": sr.setState(8); break;
        case "audio": sr.toggleMute(); break;
        case "bluetooth": sr.setState(9); break;
        case "peace": sr.peaceMode = !sr.peaceMode; break;
        case "night": sr.nightMode = !sr.nightMode; break;
        case "personalization": sr.setState(12); break;
        case "toolkit": sr.setState(14); break;
        case "settings": sr.setState(19); break;
        }
    }

    Row {
        id: gameModeContent
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Flickable {
            id: actionsFlickable
            width: Math.min(actionsRow.implicitWidth, gameModeContent.width * 0.58)
            height: gameModeContent.height
            contentWidth: Math.max(width, actionsRow.implicitWidth)
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                target: actionsFlickable.contentItem
                acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
                enabled: actionsFlickable.contentWidth > actionsFlickable.width
                onWheel: event => {
                    var delta = event.pixelDelta.x !== 0 ? event.pixelDelta.x
                        : (event.pixelDelta.y !== 0 ? event.pixelDelta.y
                        : (event.angleDelta.x !== 0 ? event.angleDelta.x / 8.0 : event.angleDelta.y / 8.0));
                    var maxX = Math.max(0, actionsFlickable.contentWidth - actionsFlickable.width);
                    actionsFlickable.contentX = Math.max(0, Math.min(maxX, actionsFlickable.contentX - delta));
                    event.accepted = true;
                }
            }

            Row {
                id: actionsRow
                width: implicitWidth
                height: gameModeContent.height
                x: Math.max(0, (actionsFlickable.width - width) / 2)
                y: (actionsFlickable.height - height) / 2
                spacing: 8

                Repeater {
                    model: [
                        { action: "wifi", label: "Wi-Fi", icon: "../../icons/wifi.png" },
                        { action: "audio", label: "Audio", icon: "../../icons/volume.png" },
                        { action: "bluetooth", label: "Bluetooth", icon: "../../icons/bluetooth.png" },
                        { action: "peace", label: "Peace", icon: "../../icons/peace(dnd).png" },
                        { action: "night", label: "Night", icon: "../../icons/night.png" },
                        { action: "personalization", label: "Personalization", icon: "../../icons/personalization.png" },
                        { action: "toolkit", label: "Screen tools", icon: "../../icons/screentools.png" },
                        { action: "settings", label: "Settings", icon: "../../icons/settings.svg" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: gameModeContent.height
                        height: actionsRow.height
                        radius: 0
                        color: actionMouse.containsMouse
                            ? root.sr.surfaceBright
                            : (root.isActive(modelData.action) ? root.sr.accentDim : root.sr.surfaceAlt)

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 20
                            spacing: 4
                            Image {
                                width: 20
                                height: 20
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: modelData.icon
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    brightness: 1.0
                                    colorization: 1.0
                                    colorizationColor: "#ffffff"
                                }
                            }

                            Text {
                                width: parent.width
                                height: 14
                                text: modelData.label
                                color: root.sr.textPrimary
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                height: 12
                                text: root.statusFor(modelData.action)
                                color: root.sr.textSecondary
                                font.pixelSize: 8
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activate(modelData.action)
                        }
                    }
                }

            }
        }

        Column {
            id: slidersColumn
            width: Math.max(0, gameModeContent.width - actionsFlickable.width - gameModeContent.spacing)
            height: gameModeContent.height
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Row {
                id: volumeControlRow
                width: slidersColumn.width
                height: (slidersColumn.height - slidersColumn.spacing) / 2
                spacing: 8

                Rectangle {
                    id: volumeTrack
                    width: Math.max(0, parent.width - 52)
                    height: parent.height
                    color: root.sr.surfaceAlt
                    clip: true

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.sr.sysVolume))
                        height: parent.height
                        color: root.sr.sysMuted ? root.sr.surfaceBright : root.sr.accent
                    }

                    Item {
                        width: 38
                        height: parent.height
                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: "../../icons/volume.png"
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                brightness: 1.0
                                colorization: 1.0
                                colorizationColor: "#000000"
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor

                        function setFromX(x) {
                            root.sr.setVolume(width > 0 ? Math.max(0, Math.min(1, x / width)) : 0);
                        }

                        onPressed: mouse => setFromX(mouse.x)
                        onPositionChanged: mouse => { if (pressed) setFromX(mouse.x); }
                        onWheel: wheel => {
                            var step = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
                            root.sr.setVolume(Math.max(0, Math.min(1, root.sr.sysVolume + step)));
                            wheel.accepted = true;
                        }
                    }
                }

                Text {
                    width: 44
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: root.sr.sysMuted ? "Muted" : Math.round(root.sr.sysVolume * 100) + "%"
                    color: root.sr.textPrimary
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
            }

            Row {
                id: brightnessControlRow
                width: slidersColumn.width
                height: (slidersColumn.height - slidersColumn.spacing) / 2
                spacing: 8

                Rectangle {
                    id: brightnessTrack
                    width: Math.max(0, parent.width - 52)
                    height: parent.height
                    color: root.sr.surfaceAlt
                    clip: true

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.sr.sysBrightness))
                        height: parent.height
                        color: root.sr.accent
                    }

                    Item {
                        width: 38
                        height: parent.height
                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: "../../icons/brightness.png"
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                brightness: 1.0
                                colorization: 1.0
                                colorizationColor: "#000000"
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor

                        function setFromX(x) {
                            root.sr.setBrightness(width > 0 ? Math.max(0, Math.min(1, x / width)) : 0);
                        }

                        onPressed: mouse => setFromX(mouse.x)
                        onPositionChanged: mouse => { if (pressed) setFromX(mouse.x); }
                        onWheel: wheel => {
                            var step = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
                            root.sr.setBrightness(Math.max(0, Math.min(1, root.sr.sysBrightness + step)));
                            wheel.accepted = true;
                        }
                    }
                }

                Text {
                    width: 44
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: Math.round(root.sr.sysBrightness * 100) + "%"
                    color: root.sr.textPrimary
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }
        }
    }
}
