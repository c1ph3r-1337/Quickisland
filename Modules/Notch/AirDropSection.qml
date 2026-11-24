import QtQuick
import qs.Services.Power
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

// =============================================================================
// AirDropSection — Apple AirDrop section for Quickisland Notch / Bar.
// Provides radar scanning, peer device listing, and drag-and-drop file transfers.
// =============================================================================
Item {
    id: airDropRoot

    required property var shellRoot
    readonly property var sr: shellRoot

    readonly property color textColor: sr ? sr.textPrimary : "#FFFFFF"
    readonly property color textDimColor: sr ? sr.textSecondary : "#A0A0A0"
    readonly property color textMutedColor: sr ? sr.textMuted : "#707070"
    readonly property color appleBlue: "#0A84FF"

    signal backRequested()

    property bool airDropActive: false
    property string airDropMode: "off"
    property string remainingTime: ""
    property string computerName: "c1ph3r"
    property var devices: []
    property bool isScanning: false
    property string statusMessage: ""
    property bool isDragOverSection: false
    property string activeSendingTarget: ""
    property string activeAdapter: "wlan0"

    Process {
        id: adapterCheckProc
        command: ["bash", "-c", "ip link show wlan1 >/dev/null 2>&1 && echo 'wlan1' || echo 'wlan0'"]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                var v = data.trim();
                if (v === "wlan1" || v === "wlan0") airDropRoot.activeAdapter = v;
            }
        }
    }

    // ── Status Query Process ─────────────────────────────────────────────────
    Process {
        id: statusQueryProc
        command: ["omdrop", "status", "--json"]
        property string accumulated: ""

        stdout: SplitParser {
            onRead: function(data) {
                statusQueryProc.accumulated += data;
            }
        }

        onExited: function(exitCode) {
            if (exitCode === 0 && accumulated.trim().length > 0) {
                try {
                    var json = JSON.parse(accumulated);
                    airDropRoot.airDropActive = !!(json.receiving || json.visible);
                    airDropRoot.airDropMode = json.mode || (airDropRoot.airDropActive ? "everyone" : "off");
                    airDropRoot.computerName = json.name || "c1ph3r";
                    if (json.remaining && json.remaining > 0) {
                        var mins = Math.ceil(json.remaining / 60);
                        airDropRoot.remainingTime = mins + "m";
                    } else {
                        airDropRoot.remainingTime = "";
                    }
                } catch (e) {}
            }
            statusQueryProc.accumulated = "";
            if (airDropRoot.airDropActive && !peersQueryProc.running) {
                peersQueryProc.running = true;
            } else if (!airDropRoot.airDropActive) {
                airDropRoot.devices = [];
            }
        }
    }

    property var deviceNameCache: ({
        "a2:02:c8:64:8b:ae": "Jaskaran’s iPhone"
    })

    // ── Peers Query Process (Fast 50ms hardware peer table query) ────────────
    Process {
        id: peersQueryProc
        command: ["omdrop", "peers", "--json"]
        property string accumulated: ""

        stdout: SplitParser {
            onRead: function(data) {
                peersQueryProc.accumulated += data;
            }
        }

        onExited: function(exitCode) {
            if (exitCode === 0 && accumulated.trim().length > 0) {
                try {
                    var list = JSON.parse(accumulated);
                    var parsed = [];
                    for (var i = 0; i < list.length; i++) {
                        var item = list[i];
                        if (!item || !item.mac) continue;
                        if (item.name) {
                            airDropRoot.deviceNameCache[item.mac] = item.name;
                        }
                        var cachedName = airDropRoot.deviceNameCache[item.mac];
                        var devName = item.name || cachedName || (item.mac.toLowerCase() === "a2:02:c8:64:8b:ae" ? "Jaskaran’s iPhone" : ("Apple Device (" + item.mac.slice(-5) + ")"));
                        var lower = devName.toLowerCase();
                        var isPhone = lower.indexOf("iphone") !== -1 || lower.indexOf("phone") !== -1 || (!item.name);
                        var isMac = lower.indexOf("mac") !== -1 || lower.indexOf("book") !== -1;
                        var isPad = lower.indexOf("ipad") !== -1 || lower.indexOf("pad") !== -1;
                        parsed.push({
                            mac: item.mac,
                            name: devName,
                            rssi: item.rssi,
                            isPhone: isPhone,
                            isMac: isMac,
                            isPad: isPad
                        });
                    }
                    airDropRoot.devices = parsed;
                } catch (e) {}
            }
            peersQueryProc.accumulated = "";
            airDropRoot.isScanning = false;
        }
    }

    // ── Send File Process ────────────────────────────────────────────────────
    Process {
        id: sendProcess
        property string accumulated: ""

        stdout: SplitParser {
            onRead: function(data) { sendProcess.accumulated += data; }
        }
        stderr: SplitParser {
            onRead: function(data) { sendProcess.accumulated += data; }
        }

        onExited: function(exitCode) {
            if (exitCode === 0) {
                airDropRoot.statusMessage = "Sent successfully!";
                Quickshell.execDetached(["notify-send", "-a", "AirDrop", "AirDrop Complete", "Files sent to " + airDropRoot.activeSendingTarget]);
            } else {
                airDropRoot.statusMessage = "Transfer failed";
                Quickshell.execDetached(["notify-send", "-a", "AirDrop", "-u", "critical", "AirDrop Failed", sendProcess.accumulated || "Check peer connection"]);
            }
            airDropRoot.activeSendingTarget = "";
            clearStatusTimer.restart();
        }
    }

    Timer {
        id: clearStatusTimer
        interval: 4000
        onTriggered: airDropRoot.statusMessage = ""
    }

    // ── Periodic Refresh Timer ───────────────────────────────────────────────
    Timer {
        id: refreshTimer
        interval: airDropRoot.airDropActive ? 3500 : 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statusQueryProc.running) {
                statusQueryProc.running = true;
            }
            if (!adapterCheckProc.running) {
                adapterCheckProc.running = true;
            }
        }
    }

    function toggleAirDrop() {
        if (airDropActive) {
            Quickshell.execDetached(["omdrop", "off"]);
            airDropActive = false;
            devices = [];
        } else {
            Quickshell.execDetached(["omdrop", "on", "10m"]);
            airDropActive = true;
        }
        statusQueryProc.running = true;
    }

    function sendFiles(targetName, urls, targetMac) {
        if ((!targetName && !targetMac) || !urls || urls.length === 0) return;
        var args = ["send"];
        if (targetMac) {
            args.push("--to", targetMac);
        } else if (targetName) {
            args.push(targetName);
        }
        args.push("--wait", "60");
        for (var i = 0; i < urls.length; i++) {
            var raw = urls[i].toString();
            var cleanPath = decodeURIComponent(raw.replace(/^file:\/\//, "")).trim();
            if (cleanPath.length > 0) {
                args.push(cleanPath);
            }
        }
        activeSendingTarget = targetName || targetMac;
        statusMessage = "Sending to " + activeSendingTarget + "...";
        sendProcess.running = false;
        sendProcess.accumulated = "";
        sendProcess.command = ["omdrop"].concat(args);
        sendProcess.running = true;
    }

    // ── Layout ───────────────────────────────────────────────────────────────
    anchors.fill: parent
    clip: true

    // Top Control Header
    Item {
        id: headerRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        height: 28

        // Back to Media Button
        Rectangle {
            id: backBtn
            width: 76
            height: 22
            radius: PowerProfileService.quickislandGameMode ? 0 : 11
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: backArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)

            Row {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: "←"
                    color: textColor
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
                Text {
                    text: "Media"
                    color: textDimColor
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: airDropRoot.backRequested()
            }
        }

        // Title and Status
        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: "AirDrop"
                color: textColor
                font.pixelSize: 13
                font.weight: Font.Bold
                font.letterSpacing: 0.3
            }

            Rectangle {
                width: 6; height: 6; radius: PowerProfileService.quickislandGameMode ? 0 : 3
                anchors.verticalCenter: parent.verticalCenter
                color: airDropActive ? "#34C759" : textMutedColor
            }

            Text {
                text: airDropActive ? (remainingTime ? ("Everyone (" + remainingTime + ")") : "Everyone") : "Off"
                color: airDropActive ? appleBlue : textMutedColor
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        // Apple-style On/Off Switch
        Rectangle {
            id: toggleBtn
            width: 58
            height: 22
            radius: PowerProfileService.quickislandGameMode ? 0 : 11
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: airDropActive ? appleBlue : Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: PowerProfileService.quickislandGameMode ? 0 : 200 } }

            Text {
                anchors.centerIn: parent
                text: airDropActive ? "Turn Off" : "Turn On"
                color: airDropActive ? "#FFFFFF" : textColor
                font.pixelSize: 10
                font.weight: Font.Bold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: airDropRoot.toggleAirDrop()
            }
        }
    }

    // ── Main Content Body ────────────────────────────────────────────────────
    Item {
        id: contentBody
        anchors.top: headerRow.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 8

        // Fallback DropArea (only active when no specific devices are listed)
        DropArea {
            id: generalDropArea
            anchors.fill: parent
            z: -1
            enabled: airDropRoot.devices.length === 0
            onEntered: function(drag) {
                if (drag.hasUrls) {
                    drag.accept();
                    airDropRoot.isDragOverSection = true;
                }
            }
            onExited: function() {
                airDropRoot.isDragOverSection = false;
            }
            onDropped: function(drop) {
                airDropRoot.isDragOverSection = false;
            }
        }

        // Drag-over Glow Overlay (only shown when no devices found)
        Rectangle {
            anchors.fill: parent
            radius: PowerProfileService.quickislandGameMode ? 0 : 14
            color: Qt.rgba(0.04, 0.52, 1.0, 0.18)
            border.color: appleBlue
            border.width: 1.5
            visible: airDropRoot.isDragOverSection && airDropRoot.devices.length === 0
            z: 2

            Column {
                anchors.centerIn: parent
                spacing: 3
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰀝"
                    font.family: "SF Pro Rounded"
                    font.pixelSize: 22
                    color: appleBlue
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (airDropRoot.devices.length > 0)
                          ? ("Drop files to send to " + airDropRoot.devices[0].name)
                          : "Drop files onto any device"
                    color: textColor
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        // View A: AirDrop is OFF
        Item {
            anchors.fill: parent
            visible: !airDropRoot.airDropActive && !airDropRoot.isDragOverSection

            Row {
                anchors.centerIn: parent
                spacing: 16

                // Radar Icon Circle
                Rectangle {
                    width: 44; height: 44; radius: PowerProfileService.quickislandGameMode ? 0 : 22
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰄡"
                        font.family: "SF Pro Rounded"
                        font.pixelSize: 20
                        color: textMutedColor
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: "AirDrop is turned off"
                        color: textColor
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: "Turn on to share with nearby Apple devices"
                        color: textDimColor
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    width: 82; height: 28; radius: PowerProfileService.quickislandGameMode ? 0 : 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: appleBlue

                    Text {
                        anchors.centerIn: parent
                        text: "Turn On"
                        color: "#FFFFFF"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: airDropRoot.toggleAirDrop()
                    }
                }
            }
        }

        // View B: AirDrop is ON, Searching (No devices yet)
        Item {
            anchors.fill: parent
            visible: airDropRoot.airDropActive && airDropRoot.devices.length === 0 && !airDropRoot.isDragOverSection

            Row {
                anchors.centerIn: parent
                spacing: 14

                // Concentric Apple Radar Waves
                Item {
                    width: 50; height: 50
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: wave1
                        anchors.centerIn: parent
                        width: 46; height: 46; radius: PowerProfileService.quickislandGameMode ? 0 : 23
                        color: "transparent"
                        border.color: appleBlue
                        border.width: 1.5
                        opacity: 0.4
                        NumberAnimation on scale {
                            from: 0.4; to: 1.1; duration: PowerProfileService.quickislandGameMode ? 0 : 1800; loops: Animation.Infinite; running: !PowerProfileService.quickislandGameMode; easing.type: Easing.OutQuad
                        }
                        NumberAnimation on opacity {
                            from: 0.7; to: 0.0; duration: PowerProfileService.quickislandGameMode ? 0 : 1800; loops: Animation.Infinite; running: !PowerProfileService.quickislandGameMode; easing.type: Easing.OutQuad
                        }
                    }

                    Rectangle {
                        id: wave2
                        anchors.centerIn: parent
                        width: 46; height: 46; radius: PowerProfileService.quickislandGameMode ? 0 : 23
                        color: "transparent"
                        border.color: appleBlue
                        border.width: 1.5
                        opacity: 0.4
                        NumberAnimation on scale {
                            from: 0.4; to: 1.1; duration: PowerProfileService.quickislandGameMode ? 0 : 1800; loops: Animation.Infinite; running: !PowerProfileService.quickislandGameMode; easing.type: Easing.OutQuad
                        }
                        NumberAnimation on opacity {
                            from: 0.7; to: 0.0; duration: PowerProfileService.quickislandGameMode ? 0 : 1800; loops: Animation.Infinite; running: !PowerProfileService.quickislandGameMode; easing.type: Easing.OutQuad
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30; height: 30; radius: PowerProfileService.quickislandGameMode ? 0 : 15
                        color: Qt.rgba(0.04, 0.52, 1.0, 0.25)
                        border.color: appleBlue
                        border.width: 1.5

                        Text {
                            anchors.centerIn: parent
                            text: "󰄡"
                            font.family: "SF Pro Rounded"
                            font.pixelSize: 14
                            color: "#FFFFFF"
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: airDropRoot.statusMessage ? airDropRoot.statusMessage : "Searching for Apple devices..."
                        color: textColor
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: "Open Share Sheet on nearby iPhone or Mac"
                        color: textDimColor
                        font.pixelSize: 10
                    }
                }

                // File chooser button
                Rectangle {
                    width: 72; height: 26; radius: PowerProfileService.quickislandGameMode ? 0 : 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: "Pick File"
                        color: textColor
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["omdrop", "send", "--pick"])
                    }
                }
            }
        }

        // View C: AirDrop is ON, Devices Found!
        ListView {
            id: devicesListView
            anchors.fill: parent
            visible: airDropRoot.airDropActive && airDropRoot.devices.length > 0
            orientation: ListView.Horizontal
            spacing: 16
            model: airDropRoot.devices
            clip: false
            z: 5

            delegate: Item {
                id: deviceDelegate
                required property var modelData
                required property int index

                width: 96
                height: 72
                z: (isDeviceDragOver || isTargetActive) ? 30 : 1

                readonly property bool isDeviceDragOver: deviceDropArea.containsDrag
                readonly property bool isTargetActive: airDropRoot.activeSendingTarget === (modelData.name || modelData.mac)

                // Apple-style spring scale on selection / drag-over
                scale: isTargetActive ? 1.20 : (isDeviceDragOver ? 1.18 : (devMouseArea.containsMouse ? 1.05 : 1.0))
                Behavior on scale { NumberAnimation { duration: PowerProfileService.quickislandGameMode ? 0 : 220; easing.type: Easing.OutBack } }

                // Individual Device DropArea
                DropArea {
                    id: deviceDropArea
                    anchors.fill: parent
                    z: 10
                    onEntered: function(drag) {
                        if (drag.hasUrls || drag.hasText) drag.accept();
                    }
                    onPositionChanged: function(drag) {
                        if (drag.hasUrls || drag.hasText) drag.accept();
                    }
                    onDropped: function(drop) {
                        var paths = [];
                        if (drop.hasUrls && drop.urls.length > 0) {
                            for (var i = 0; i < drop.urls.length; i++) {
                                paths.push(drop.urls[i]);
                            }
                        } else if (drop.hasText && drop.text.length > 0) {
                            paths.push(drop.text.trim());
                        }
                        if (paths.length > 0) {
                            drop.accept();
                            airDropRoot.sendFiles(modelData.name, paths, modelData.mac);
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    // Apple Circular Contact Bubble with Badge
                    Item {
                        width: 48
                        height: 48
                        anchors.horizontalCenter: parent.horizontalCenter

                        // Pulsing Halo Glow when Active or Dragged Over
                        Rectangle {
                            anchors.centerIn: parent
                            width: 56
                            height: 56
                            radius: PowerProfileService.quickislandGameMode ? 0 : 28
                            color: "transparent"
                            border.color: appleBlue
                            border.width: deviceDelegate.isDeviceDragOver ? 2.0 : 1.5
                            opacity: deviceDelegate.isTargetActive ? 0.9 : (deviceDelegate.isDeviceDragOver ? 0.75 : 0.0)
                            scale: deviceDelegate.isTargetActive ? 1.2 : (deviceDelegate.isDeviceDragOver ? 1.14 : 0.95)
                            Behavior on opacity { NumberAnimation { duration: PowerProfileService.quickislandGameMode ? 0 : 180 } }
                            Behavior on scale { NumberAnimation { duration: PowerProfileService.quickislandGameMode ? 0 : 180; easing.type: Easing.OutCubic } }
                        }

                        // Main Circular Avatar with Person Silhouette
                        Rectangle {
                            id: avatarCircle
                            anchors.centerIn: parent
                            width: 44
                            height: 44
                            radius: PowerProfileService.quickislandGameMode ? 0 : 22
                            color: (deviceDelegate.isDeviceDragOver || deviceDelegate.isTargetActive)
                                   ? Qt.rgba(0.04, 0.52, 1.0, 0.35)
                                   : (devMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.10))
                            border.color: (deviceDelegate.isDeviceDragOver || deviceDelegate.isTargetActive)
                                          ? appleBlue
                                          : (devMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15))
                            border.width: (deviceDelegate.isDeviceDragOver || deviceDelegate.isTargetActive) ? 2.5 : 1.0
                            Behavior on color { ColorAnimation { duration: PowerProfileService.quickislandGameMode ? 0 : 150 } }

                            // Person Silhouette in Center
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family: "SF Pro Rounded"
                                font.pixelSize: 22
                                color: (deviceDelegate.isDeviceDragOver || deviceDelegate.isTargetActive || devMouseArea.containsMouse) ? "#FFFFFF" : textColor
                            }
                        }

                        // Bottom-Right Corner Device Badge (iPhone, Mac, iPad)
                        Rectangle {
                            width: 18
                            height: 18
                            radius: PowerProfileService.quickislandGameMode ? 0 : 9
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            color: (deviceDelegate.isDeviceDragOver || deviceDelegate.isTargetActive) ? appleBlue : Qt.rgba(0.12, 0.12, 0.14, 0.95)
                            border.color: (deviceDelegate.isDeviceDragOver || deviceDelegate.isTargetActive) ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.25)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.isPhone ? "" : (modelData.isMac ? "󰌢" : (modelData.isPad ? "" : "󰄡"))
                                font.family: "SF Pro Rounded"
                                font.pixelSize: 10
                                color: (deviceDelegate.isDeviceDragOver || deviceDelegate.isTargetActive) ? "#FFFFFF" : textColor
                            }
                        }
                    }

                    // Device Name (Apple typography)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 90
                        text: modelData.name
                        color: textColor
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    // Subtitle / Status
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 90
                        text: deviceDelegate.isTargetActive
                              ? "Sending..."
                              : (deviceDelegate.isDeviceDragOver ? "Drop to Send" : "AirDrop")
                        color: (deviceDelegate.isTargetActive || deviceDelegate.isDeviceDragOver)
                               ? appleBlue
                               : textDimColor
                        font.pixelSize: 8
                        font.weight: (deviceDelegate.isTargetActive || deviceDelegate.isDeviceDragOver) ? Font.Bold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }
                }

                MouseArea {
                    id: devMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["omdrop", "send", "--pick", "--to", modelData.mac, "--wait", "60"]);
                    }
                }
            }
        }
    }
}
