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
    // 1. LEFT SIDE: MEDIA PLAYER
    // =========================================================================
    Item {
        id: mediaArea
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: clockArea.left
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // Album Art
        Item {
            id: albumArtContainer
            width: 66; height: 66
            anchors.left: parent.left
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
    // 2. RIGHT SIDE: CLOCK, STATUS COMPLICATION & CALENDAR
    // =========================================================================
    Item {
        id: clockArea
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 175

        Column {
            anchors.centerIn: parent
            spacing: 4

            // Header Row: Time & Status Complication Side by Side
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sr.currentTime12h
                    color: textColor
                    font.pixelSize: 26
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                    font.family: "Varela Round"
                }

                CircularStatusRing {
                    id: unifiedRing
                    anchors.verticalCenter: parent.verticalCenter

                    // Battery (Outer Ring Arc & Label)
                    batteryRatio: sr.batteryPercent >= 0 ? Math.max(0.0, Math.min(1.0, sr.batteryPercent / 100)) : 1.0
                    isCharging: sr.batteryCharging
                    activeColor: textColor
                    trackColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.22)
                    batteryLabel: sr.batteryPercent >= 0 ? (Math.round(sr.batteryPercent) + "%") : ""

                    // Network (Center Icon & Bottom Strength Dots)
                    signalDots: {
                        if (sr.ethConnected) return 4;
                        if (sr.wifiConnected) {
                            var sig = parseInt(sr.connectedWifiSignal || "100");
                            if (isNaN(sig)) return 3;
                            return Math.max(1, Math.min(4, Math.round((sig / 100) * 4)));
                        }
                        return 0;
                    }
                    networkConnected: sr.ethConnected || sr.wifiConnected
                    networkIcon: sr.ethConnected ? "../../icons/ethernet.png" : "../../icons/wifi.png"

                    // Left-click opens Wi-Fi, Right-click opens Control Center
                    onClicked: sr.setState(8)
                    onRightClicked: sr.setState(5)
                }
            }

            // Mini Calendar Row
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
