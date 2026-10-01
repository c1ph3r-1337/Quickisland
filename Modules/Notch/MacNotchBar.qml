import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Modules.Bar.Widgets as BarWidgets
import "../../" as Root
import "../../Commons"
import qs.Services.UI
import Quickshell.Hyprland

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

    property string workspaceId: "1"
    property bool notchWorkspaceActive: false

    Timer {
        id: notchWorkspaceTimer
        interval: 1400
        onTriggered: notchWorkspaceActive = false
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            var monitor = screen ? Hyprland.monitorFor(screen) : null;
            var newId = 1;
            if (monitor && monitor.focusedWorkspace) {
                newId = monitor.focusedWorkspace.id;
            } else if (monitor && monitor.activeWorkspace) {
                newId = monitor.activeWorkspace.id;
            } else if (Hyprland.focusedWorkspace) {
                newId = Hyprland.focusedWorkspace.id;
            }
            workspaceId = newId;
            if (!isExpanded) {
                notchWorkspaceTimer.stop();
                notchWorkspaceActive = true;
                notchWorkspaceTimer.restart();
            }
        }
    }

// ── Layout configuration ─────────────────────────────────────────────
    property bool isHovered: false
    property bool keepExpanded: false
    readonly property bool isExpanded: isHovered || keepExpanded
    
    Timer {
        id: autoCollapseTimer
        interval: 1800
        repeat: false
        onTriggered: {
            if (!notchMouseArea.containsMouse && (!sr || sr.currentState === 0)) {
                keepExpanded = false;
            }
        }
    }

    Connections {
        target: sr
        function onCurrentStateChanged() {
            if (sr && sr.currentState > 0) {
                autoCollapseTimer.stop();
                keepExpanded = true;
            } else if (sr && sr.currentState === 0) {
                if (!notchMouseArea.containsMouse) {
                    autoCollapseTimer.restart();
                }
            }
        }
    }

    property real notchWidth: isExpanded ? 500 : 160
    property real notchHeight: isExpanded ? 110 : 28
    
    Behavior on notchWidth { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
    Behavior on notchHeight { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

    readonly property real notchRadius: 18 // slightly smaller radius for collapsed mode compatibility
    property real flareRadius: isExpanded ? ((typeof Settings !== "undefined" && Settings.isLoaded && Settings.data.islandConfig.notchFlare) ? Settings.data.islandConfig.notchFlare : 12) : 5
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

        // Background mask
        ShaderEffectSource {
            id: bgMask
            anchors.fill: parent
            visible: false
            hideSource: true
            live: true
            sourceItem: Item {
                width: bgMask.width
                height: bgMask.height
                
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
                        strokeWidth: 0
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
                        strokeWidth: 0
                        PathSvg { path: "M " + flareRadius + " 0 L 0 0 L 0 " + flareRadius + " A " + flareRadius + " " + flareRadius + " 0 0 1 " + flareRadius + " 0 Z" }
                    }
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
                borderColor: "transparent"
                active: typeof Settings !== "undefined" && Settings.isLoaded && Settings.data.colorSchemes.hyprglass
            }
        }

// =====================================================================
        // INNER CONTENT CONTAINER
        // =====================================================================
        Item {
            anchors.fill: parent
            clip: true // Prevent spillover during animation
            
            // Collapsed Clock & Now Playing EQ (Small Notch)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: (28 - height) / 2
                spacing: 0
                opacity: Math.max(0, 1.0 - (notchContainer.width - 160) / 100)
                visible: opacity > 0

                // EQ Visualizer Container that slides out / collapses
                Item {
                    id: collapsedEqVisualizerContainer
                    height: 12
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    width: sr.mediaPlaying ? 18.5 : 0
                    opacity: sr.mediaPlaying ? 1 : 0

                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                    Row {
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
                                    width: 2; radius: 1; color: sr.accent
                                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                    height: sr.mediaPlaying ? 5 : 2
                                    SequentialAnimation on height {
                                        loops: Animation.Infinite; running: sr.mediaPlaying
                                        NumberAnimation { to: modelData.h1; duration: modelData.d1; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: modelData.h2; duration: modelData.d2; easing.type: Easing.InOutSine }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: notchCenterInfo
                    width: notchWorkspaceActive ? notchWorkspaceLabel.implicitWidth : notchIdleClock.implicitWidth
                    height: Math.max(notchIdleClock.implicitHeight, notchWorkspaceLabel.implicitHeight)
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Text {
                        id: notchIdleClock
                        anchors.centerIn: parent
                        text: sr.currentTime12h
                        color: textColor
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        font.family: "Varela Round"
                        opacity: notchWorkspaceActive ? 0.0 : 1.0
                        scale: notchWorkspaceActive ? 0.8 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        id: notchWorkspaceLabel
                        anchors.centerIn: parent
                        text: workspaceId
                        color: textColor
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        font.family: "Varela Round"
                        opacity: notchWorkspaceActive ? 1.0 : 0.0
                        scale: notchWorkspaceActive ? 1.0 : 0.8
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                }
            }

            // =================================================================
            // 1. TOP-RIGHT: UNIFIED BATTERY & NETWORK STATUS COMPLICATION
            // =================================================================
            Item {
                id: statusArea
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.rightMargin: 16
                width: 32
                opacity: Math.max(0, (notchContainer.width - 250) / (500 - 250))
                visible: opacity > 0

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
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 24
                    height: 18
                    opacity: sr.mediaPlaying ? 1.0 : ((sr.mediaTitle && sr.mediaTitle !== "") ? 0.35 : 0.0)
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

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
                                width: 2.5; radius: 1.25
                                color: sr.accent || textColor
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: sr.mediaPlaying ? 5 : 2
                                SequentialAnimation on height {
                                    loops: Animation.Infinite
                                    running: sr.mediaPlaying
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

            // =================================================================
            // 2. LEFT SIDE: MEDIA
            // =================================================================
            Item {
                id: mediaArea
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: clockArea.left
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                opacity: Math.max(0, (notchContainer.width - 250) / (500 - 250))
                visible: opacity > 0

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
                            fillMode: Image.PreserveAspectCrop; layer.enabled: true
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

                    // Controls
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
                MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: sr.setState(5) }
            }

            // =================================================================
            // 3. RIGHT / CENTER-RIGHT: CLOCK & CALENDAR
            // =================================================================
            Item {
                id: clockArea
                anchors.right: statusArea.left
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 140
                opacity: Math.max(0, (notchContainer.width - 250) / (500 - 250))
                visible: opacity > 0

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    // Clock
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: sr.currentTime12h
                        color: textColor
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        font.family: "Varela Round"
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
    }

    Timer { interval: 60000; running: true; repeat: true; onTriggered: {} }

    MouseArea {
        id: notchMouseArea
        anchors.fill: notchContainer
        hoverEnabled: true
        propagateComposedEvents: true
        onEntered: {
            autoCollapseTimer.stop();
            isHovered = true;
            notchBar.forceActiveFocus();
        }
        onExited: {
            isHovered = false;
            if (!sr || sr.currentState === 0) {
                keepExpanded = false;
            }
        }
        onPressed: (mouse) => mouse.accepted = false
        onReleased: (mouse) => mouse.accepted = false
        onWheel: (wheel) => wheel.accepted = false
    }
}
