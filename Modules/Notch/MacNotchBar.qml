import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Modules.Bar.Widgets as BarWidgets
import "../../" as Root
import "../../Commons"
import qs.Services.UI

// =============================================================================
// MacNotchBar — A large, centered top notch containing media and calendar.
// =============================================================================
Item {
    id: notchBar

    focus: isHovered
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Right) {
            shellRoot.setState(5);
            event.accepted = true;
        }
    }


    required property var shellRoot
    property var screen
    readonly property var sr: shellRoot

// ── Layout configuration ─────────────────────────────────────────────
    property bool isHovered: false
    property bool isExpanded: isHovered
    
    property real notchWidth: isExpanded ? 500 : 160
    property real notchHeight: isExpanded ? 110 : 28
    
    Behavior on notchWidth { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
    Behavior on notchHeight { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

    readonly property real notchRadius: 18 // slightly smaller radius for collapsed mode compatibility
    property real flareRadius: isExpanded ? 12 : 5
    Behavior on flareRadius { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

    readonly property color bgColor: sr.surface
    readonly property color accentColor: sr.accent
    readonly property color textColor: sr.textPrimary
    readonly property color textDimColor: sr.textSecondary
    readonly property color textMutedColor: sr.textMuted

    anchors.fill: parent

// Container for the centered notch
    Item {
        id: notchContainer
        width: notchWidth
        height: notchHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        
        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
        }

        // Background mask
        Item {
            id: bgMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            
            // Main body
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: flareRadius
                anchors.rightMargin: flareRadius
                radius: notchRadius
                color: "black"
            }
            
            // Square off top of main body
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: flareRadius
                anchors.rightMargin: flareRadius
                height: notchHeight / 2
                color: "black"
            }
            
            // Left Flare (Reverse Round)
            Shape {
                anchors.top: parent.top
                anchors.left: parent.left
                width: flareRadius
                height: flareRadius
                
                ShapePath {
                    fillColor: "black"
                    strokeColor: "transparent"
                    PathSvg { path: "M 0 0 L " + flareRadius + " 0 L " + flareRadius + " " + flareRadius + " A " + flareRadius + " " + flareRadius + " 0 0 0 0 0 Z" }
                }
            }
            
            // Right Flare (Reverse Round)
            Shape {
                anchors.top: parent.top
                anchors.right: parent.right
                width: flareRadius
                height: flareRadius
                
                ShapePath {
                    fillColor: "black"
                    strokeColor: "transparent"
                    PathSvg { path: "M " + flareRadius + " 0 L 0 0 L 0 " + flareRadius + " A " + flareRadius + " " + flareRadius + " 0 0 1 " + flareRadius + " 0 Z" }
                }
            }
        }

        // The background
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: bgMask
            }
            
            Rectangle {
                anchors.fill: parent
                color: bgColor
            }
            Root.LiquidGlassBackground {
                anchors.fill: parent
                radius: 0
                surfaceColor: sr.surface
                accentColor: sr.accent
                borderColor: Qt.rgba(1, 1, 1, 0.05)
                active: typeof Settings !== "undefined" && Settings.isLoaded && Settings.data.colorSchemes.hyprglass
            }
            
            // Optional subtle border on the bottom
            Item {
                anchors.fill: parent
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    width: notchWidth - (flareRadius * 2); height: 1; color: Qt.rgba(1, 1, 1, 0.08)
                }
            }
        }

// =====================================================================
        // INNER CONTENT CONTAINER
        // =====================================================================
        Item {
            anchors.fill: parent
            clip: true // Prevent spillover during animation
            
            // Collapsed Clock (Small Notch)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: (28 - height) / 2
                text: sr.currentTime12h // or just 12h depending on pref
                color: textColor
                font.pixelSize: 13
                font.weight: Font.Bold
                opacity: Math.max(0, 1.0 - (notchContainer.width - 160) / 100)
                visible: opacity > 0
            }

            // --- LEFT SIDE: MEDIA ---
            Item {
                id: mediaArea
                anchors.right: parent.horizontalCenter
                anchors.rightMargin: 30
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 210
                opacity: Math.max(0, (notchContainer.width - 250) / (500 - 250))
                visible: opacity > 0


                // Album Art (Exactly 70x70, 24px padding from left)
                Item {
                    id: albumArtContainer
                    width: 70; height: 70
                    anchors.left: parent.left
                    anchors.leftMargin: 24 // 24 + 16(mediaArea) = 40px from edge (24px from black edge)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: albumMask; layer.enabled: true
                        anchors.fill: parent
                        radius: 16
                        visible: false
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: sr.mediaArtUrl ? "transparent" : Qt.rgba(1, 1, 1, 0.08)
                        radius: 16

                        Image {
                            anchors.fill: parent
                            source: sr.mediaArtUrl || ""
                            fillMode: Image.PreserveAspectCrop; layer.enabled: true
                            visible: sr.mediaArtUrl !== ""
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: albumMask }
                        }
                        Text {
                            anchors.centerIn: parent; text: "♫"
                            color: textMutedColor; font.pixelSize: 24
                            visible: sr.mediaArtUrl === ""
                        }
                    }
                }

                // Text and Controls (16px gap from Album Art)
                // Text and Controls (16px gap from Album Art)
                Column {
                    anchors.left: albumArtContainer.right
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: sr.mediaTitle || "No media"
                        color: textColor
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    
                    Text {
                        width: parent.width
                        text: sr.mediaArtist || "—"
                        color: textDimColor
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    
                    // Spacer before controls
                    Item { width: 1; height: 6 }

                    // Controls
                    Row {
                        spacing: 16
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

// --- RIGHT SIDE: CLOCK & CALENDAR ---
            Item {
                id: clockArea
                anchors.left: parent.horizontalCenter
                anchors.leftMargin: 30
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 210
                opacity: Math.max(0, (notchContainer.width - 250) / (500 - 250))
                visible: opacity > 0

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    spacing: 4

                    // Clock
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: sr.currentTime12h
                        color: textColor
                        font.pixelSize: 32
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        font.family: "Varela Round"
                    }

                    // Mini Calendar Row
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

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
                                width: 16; height: 32

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.weekday
                                        color: modelData.isToday ? textColor : Qt.rgba(1, 1, 1, 0.4)
                                        font.pixelSize: modelData.isToday ? 10 : 8
                                        font.weight: modelData.isToday ? Font.Bold : Font.Medium
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.day
                                        color: modelData.isToday ? textColor : Qt.rgba(1, 1, 1, 0.4)
                                        font.pixelSize: modelData.isToday ? 14 : 10
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
    }

    Timer { interval: 60000; running: true; repeat: true; onTriggered: {} }

    MouseArea {
        anchors.fill: notchContainer
        hoverEnabled: true
        propagateComposedEvents: true
        onEntered: { isHovered = true; notchBar.forceActiveFocus(); }
        onExited: isHovered = false
        onPressed: (mouse) => mouse.accepted = false
        onReleased: (mouse) => mouse.accepted = false
        onWheel: (wheel) => wheel.accepted = false
    }
}
