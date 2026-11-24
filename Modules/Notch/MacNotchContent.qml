import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../Commons"
import qs.Services.Power
import "../GameMode" as GameMode

Item {
    id: notchContent
    required property var shellRoot
    readonly property var sr: shellRoot

    readonly property color textColor: sr.textPrimary
    readonly property color textDimColor: sr.textSecondary
    readonly property color textMutedColor: sr.textMuted

    anchors.fill: parent
    clip: true

    property int currentTab: (sr && sr.notchTab !== undefined) ? sr.notchTab : 0
    onCurrentTabChanged: {
        if (sr && sr.notchTab !== undefined && sr.notchTab !== currentTab) {
            sr.notchTab = currentTab;
        }
    }
    Connections {
        target: sr
        function onNotchTabChanged() {
            if (notchContent.currentTab !== sr.notchTab) {
                notchContent.currentTab = sr.notchTab;
            }
        }
    }

    // Global drag & drop catcher for AirDrop
    DropArea {
        anchors.fill: parent
        enabled: notchContent.currentTab !== 1
        onEntered: function(drag) {
            if (drag.hasUrls) {
                notchContent.currentTab = 1;
                if (sr && sr.notchTab !== undefined) sr.notchTab = 1;
            }
        }
    }

    // =========================================================================
    // 1. TOP-RIGHT: UNIFIED BATTERY & NETWORK STATUS COMPLICATION
    // =========================================================================
    Item {
        id: statusArea
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: 14
        width: 38
        visible: notchContent.currentTab === 0

        CircularStatusRing {
            id: unifiedRing
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter

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

        // Media Now Playing Visualizer under Circular Complication
        Item {
            id: mediaVisualizerContainer
            anchors.top: unifiedRing.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: unifiedRing.horizontalCenter
            width: 24
            height: 18
            opacity: sr.mediaPlaying ? 1.0 : ((sr.mediaTitle && sr.mediaTitle !== "") ? 0.35 : 0.0)
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: PowerProfileService.quickislandGameMode ? 0 : 250; easing.type: Easing.InOutQuad } }

            Row {
                anchors.centerIn: parent
                spacing: 2

                Repeater {
                    model: [
                        { h1: 14, h2: 3,  d1: 340, d2: 400 },
                        { h1: 7,  h2: 12, d1: 420, d2: 320 },
                        { h1: 16, h2: 2,  d1: 280, d2: 440 },
                        { h1: 10, h2: 5,  d1: 380, d2: 360 }
                    ]
                    Item {
                        width: 2.5; height: 16
                        Rectangle {
                            width: 2.5; radius: PowerProfileService.quickislandGameMode ? 0 : 1.25
                            color: sr.accent || textColor
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: sr.mediaPlaying ? 5 : 2
                            SequentialAnimation on height {
                                loops: Animation.Infinite
                                running: sr.mediaPlaying && !PowerProfileService.quickislandGameMode
                                NumberAnimation { to: modelData.h1; duration: modelData.d1; easing.type: Easing.InOutSine }
                                NumberAnimation { to: modelData.h2; duration: modelData.d2; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    if (sr.mediaPlayer) {
                        if (sr.mediaPlaying) sr.mediaPlayer.pause();
                        else sr.mediaPlayer.play();
                    }
                }
            }
        }
    }

    // =========================================================================
    // 2. MEDIA & CLOCK COMBINED VIEW (Tab 0)
    // =========================================================================
    Item {
        id: mediaAndClockArea
        anchors.left: parent.left
        anchors.right: statusArea.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: notchContent.currentTab === 0
        opacity: notchContent.currentTab === 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: PowerProfileService.quickislandGameMode ? 0 : 200 } }

        Item {
            id: mediaArea
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: clockArea.left
            anchors.rightMargin: 12
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
                radius: PowerProfileService.quickislandGameMode ? 0 : 14
                visible: false
            }

            Rectangle {
                anchors.fill: parent
                color: sr.mediaArtUrl ? "transparent" : Qt.rgba(1, 1, 1, 0.08)
                radius: PowerProfileService.quickislandGameMode ? 0 : 14

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
                    width: 24; height: 24; radius: PowerProfileService.quickislandGameMode ? 0 : 12; color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Image {
                        anchors.centerIn: parent; width: 12; height: 12
                        source: "../../icons/previous.png"; layer.enabled: true
                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: textColor }
                    }
                    MouseArea { id: prevArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (sr.mediaPlayer) sr.mediaPlayer.previous(); } }
                }
                Rectangle {
                    width: 24; height: 24; radius: PowerProfileService.quickislandGameMode ? 0 : 12; color: playArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Image {
                        anchors.centerIn: parent; width: 12; height: 12
                        source: sr.mediaPlaying ? "../../icons/pause.png" : "../../icons/play-button.png"; layer.enabled: true
                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: textColor }
                    }
                    MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (sr.mediaPlayer) { if (sr.mediaPlaying) sr.mediaPlayer.pause(); else sr.mediaPlayer.play(); } } }
                }
                Rectangle {
                    width: 24; height: 24; radius: PowerProfileService.quickislandGameMode ? 0 : 12; color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Image {
                        anchors.centerIn: parent; width: 12; height: 12
                        source: "../../icons/next.png"; layer.enabled: true
                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: textColor }
                    }
                    MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (sr.mediaPlayer) sr.mediaPlayer.next(); } }
                }
            }
        }
        MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: sr.setState(5) }
    }

    // =========================================================================
    // 3. RIGHT / CENTER-RIGHT: CLOCK & CALENDAR
    // =========================================================================
        Item {
            id: clockArea
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 140

            Column {
                anchors.centerIn: parent
                spacing: 4

                GameMode.AdaptiveTime {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: sr.currentTime12h
                    rollingEnabled: PowerProfileService.quickislandGameMode
                    color: textColor
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                    font.family: "SF Pro Rounded"
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
    } // End mediaAndClockArea

    // =========================================================================
    // 4. AIRDROP SECTION
    // =========================================================================
    AirDropSection {
        id: airDropSection
        anchors.fill: parent
        shellRoot: sr
        visible: notchContent.currentTab === 1
        opacity: notchContent.currentTab === 1 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: PowerProfileService.quickislandGameMode ? 0 : 200 } }
        onBackRequested: notchContent.currentTab = 0
    }
}
