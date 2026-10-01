import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../Commons"

Item {
    id: notchContent
    required property var shellRoot
    readonly property var sr: shellRoot

    readonly property color textColor: sr.textPrimary
    readonly property color textDimColor: sr.textSecondary
    readonly property color textMutedColor: sr.textMuted

    anchors.fill: parent
    clip: true

    // =========================================================================
    // 1. CENTER: CIRCULAR STATUS COMPLICATIONS (ETHERNET/WIFI & BATTERY)
    // =========================================================================
    Item {
        id: statusCenterArea
        anchors.centerIn: parent
        width: sr.batteryPercent >= 0 ? 100 : 50
        height: parent.height

        Row {
            anchors.centerIn: parent
            spacing: 8

            // Network Status Ring (Ethernet or Wi-Fi)
            CircularStatusRing {
                id: netRing
                value: {
                    if (sr.ethConnected) return 1.0;
                    if (sr.wifiConnected) {
                        var sig = parseInt(sr.connectedWifiSignal || "100");
                        return isNaN(sig) ? 0.75 : Math.max(0.1, sig / 100);
                    }
                    return 0.0;
                }
                activeDots: {
                    if (sr.ethConnected) return 4;
                    if (sr.wifiConnected) {
                        var sig = parseInt(sr.connectedWifiSignal || "100");
                        if (isNaN(sig)) return 3;
                        return Math.max(1, Math.min(4, Math.round((sig / 100) * 4)));
                    }
                    return 0;
                }
                strokeColor: (sr.ethConnected || sr.wifiConnected) ? sr.accent : textMutedColor
                trackColor: Qt.rgba(1, 1, 1, 0.12)
                iconSource: sr.ethConnected ? "../../icons/ethernet.png" : "../../icons/wifi.png"
                iconColor: (sr.ethConnected || sr.wifiConnected) ? textColor : textMutedColor
                labelText: sr.ethConnected ? "ETH" : (sr.wifiConnected ? (sr.connectedWifiSignal + "%") : "OFF")
                labelColor: (sr.ethConnected || sr.wifiConnected) ? textColor : textMutedColor
                tooltipText: sr.ethConnected ? "Ethernet: Connected" : (sr.wifiConnected ? ("Wi-Fi: " + sr.wifiSSID) : "Disconnected")
                onClicked: sr.setState(8)
            }

            // Battery Status Ring
            CircularStatusRing {
                id: battRing
                visible: sr.batteryPercent >= 0
                value: Math.max(0.0, Math.min(1.0, sr.batteryPercent / 100))
                activeDots: Math.min(4, Math.floor((sr.batteryPercent / 100) * 4 + 0.05))
                strokeColor: sr.batteryPercent < 20 ? (sr.red || "#f38ba8") : (sr.batteryCharging ? (sr.green || "#a6e3a1") : sr.accent)
                trackColor: Qt.rgba(1, 1, 1, 0.12)
                iconGlyph: sr.batteryCharging ? "󰂄" : (sr.batteryPercent < 20 ? "󰂎" : (sr.batteryPercent < 50 ? "󰁾" : (sr.batteryPercent < 80 ? "󰂀" : "󰁹")))
                iconColor: strokeColor
                labelText: Math.round(sr.batteryPercent) + "%"
                labelColor: strokeColor
                tooltipText: Math.round(sr.batteryPercent) + "%" + (sr.batteryCharging ? " (Charging)" : "")
                onClicked: sr.setState(5)
            }
        }
    }

    // =========================================================================
    // 2. LEFT SIDE: MEDIA PLAYER
    // =========================================================================
    Item {
        id: mediaArea
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: statusCenterArea.left
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // Album Art
        Item {
            id: albumArtContainer
            width: 64; height: 64
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: albumMask; layer.enabled: true
                anchors.fill: parent
                radius: 14
                visible: false
            }

            Rectangle {
                anchors.fill: parent
                color: sr.mediaArtUrl ? "transparent" : Qt.rgba(1, 1, 1, 0.08)
                radius: 14

                Image {
                    anchors.fill: parent
                    source: sr.mediaArtUrl || ""
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    visible: sr.mediaArtUrl !== ""
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: albumMask }
                }
                Text {
                    anchors.centerIn: parent; text: "♫"
                    color: textMutedColor; font.pixelSize: 22
                    visible: sr.mediaArtUrl === ""
                }
            }
        }

        // Text and Controls
        Column {
            anchors.left: albumArtContainer.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: sr.mediaTitle || "No media"
                color: textColor
                font.pixelSize: 14
                font.weight: Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: sr.mediaArtist || "—"
                color: textDimColor
                font.pixelSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Item { width: 1; height: 4 }

            Row {
                spacing: 12
                Rectangle {
                    width: 24; height: 24; radius: 12; color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Image {
                        anchors.centerIn: parent; width: 12; height: 12
                        source: "../../icons/previous.png"; layer.enabled: true
                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: textColor }
                    }
                    MouseArea { id: prevArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (sr.mediaPlayer) sr.mediaPlayer.previous(); } }
                }
                Rectangle {
                    width: 24; height: 24; radius: 12; color: playArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Image {
                        anchors.centerIn: parent; width: 12; height: 12
                        source: sr.mediaPlaying ? "../../icons/pause.png" : "../../icons/play-button.png"; layer.enabled: true
                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: textColor }
                    }
                    MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (sr.mediaPlayer) { if (sr.mediaPlaying) sr.mediaPlayer.pause(); else sr.mediaPlayer.play(); } } }
                }
                Rectangle {
                    width: 24; height: 24; radius: 12; color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Image {
                        anchors.centerIn: parent; width: 12; height: 12
                        source: "../../icons/next.png"; layer.enabled: true
                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: textColor }
                    }
                    MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (sr.mediaPlayer) sr.mediaPlayer.next(); } }
                }
            }
        }
        MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: sr.setState(10) }
    }

    // =========================================================================
    // 3. RIGHT SIDE: CLOCK & CALENDAR
    // =========================================================================
    Item {
        id: clockArea
        anchors.left: statusCenterArea.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: sr.currentTime12h
                color: textColor
                font.pixelSize: 28
                font.weight: Font.Bold
                font.letterSpacing: 0.5
                font.family: "Varela Round"
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Repeater {
                    model: {
                        var today = new Date();
                        var dates = [];
                        for (var i = -3; i <= 3; i++) {
                            var d = new Date(today);
                            d.setDate(today.getDate() + i);
                            dates.push({ day: d.getDate(), weekday: ["S", "M", "T", "W", "T", "F", "S"][d.getDay()], isToday: i === 0 });
                        }
                        return dates;
                    }

                    Item {
                        width: 14; height: 30

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.weekday
                                color: modelData.isToday ? sr.accent : textMutedColor
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.day
                                color: modelData.isToday ? textColor : Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: modelData.isToday ? 13 : 9
                                font.weight: modelData.isToday ? Font.Bold : Font.Medium
                            }
                        }
                    }
                }
            }
        }
        MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: sr.setState(5) }
    }
}
