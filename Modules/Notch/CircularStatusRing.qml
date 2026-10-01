import QtQuick
import QtQuick.Effects

Item {
    id: root

    // Battery binds to outer ring arc
    property real batteryRatio: 1.0
    property bool isCharging: false
    property color activeColor: "#ffffff"
    property color trackColor: Qt.rgba(1, 1, 1, 0.22)
    property color batteryColor: (batteryRatio <= 0.15 && !isCharging) ? "#f38ba8" : activeColor

    // Network binds to center icon & bottom 4 dots
    property int signalDots: 4       // 0 to 4 dots
    property bool networkConnected: signalDots > 0
    property string networkIcon: ""

    // Battery text label below ring
    property string batteryLabel: ""

    // Click signals
    signal clicked()
    signal rightClicked()

    width: 26
    height: 34

    property real animatedBatteryRatio: batteryRatio
    Behavior on animatedBatteryRatio {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    onAnimatedBatteryRatioChanged: ringCanvas.requestPaint()
    onActiveColorChanged: ringCanvas.requestPaint()
    onBatteryColorChanged: ringCanvas.requestPaint()
    onSignalDotsChanged: ringCanvas.requestPaint()
    onTrackColorChanged: ringCanvas.requestPaint()

    scale: ringMouse.containsMouse ? 1.12 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    // Circular Ring Container
    Item {
        id: ringContainer
        width: 24
        height: 24
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        Canvas {
            id: ringCanvas
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            renderTarget: Canvas.FramebufferObject

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();

                var w = width;
                var h = height;
                var cx = w / 2;
                var cy = h / 2;
                var strokeWidth = 1.8;
                var r = (w - strokeWidth) / 2 - 0.8;

                // Arc angles: Clockwise from bottom-left (145° / 0.805*PI) across the top to bottom-right (35° / 2.195*PI)
                var startAngle = Math.PI * 0.805;
                var endAngle = Math.PI * 2.195;
                var totalSpan = endAngle - startAngle; // ~250 degrees

                ctx.lineWidth = strokeWidth;
                ctx.lineCap = "round";

                // 1. Inactive background track
                ctx.strokeStyle = root.trackColor;
                ctx.beginPath();
                ctx.arc(cx, cy, r, startAngle, endAngle, false);
                ctx.stroke();

                // 2. Active battery arc (0.0 to 1.0)
                var val = Math.max(0.0, Math.min(1.0, root.animatedBatteryRatio));
                if (val > 0.01) {
                    ctx.strokeStyle = root.batteryColor;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, startAngle, startAngle + totalSpan * val, false);
                    ctx.stroke();
                }

                // 3. Four discrete dots along the bottom opening with wide gap to arc ends
                // Centered at 90° (0.50*PI). Spaced 15° apart from 112.5° to 67.5°
                // Arc ends at 145° and 35°, leaving >32° (11px) gap so dots NEVER touch the circle
                var dotAngles = [
                    Math.PI * 0.625, // 112.5°
                    Math.PI * 0.542, // 97.5°
                    Math.PI * 0.458, // 82.5°
                    Math.PI * 0.375  // 67.5°
                ];
                var dotRadius = 0.9;

                for (var i = 0; i < 4; i++) {
                    var angle = dotAngles[i];
                    var dx = cx + r * Math.cos(angle);
                    var dy = cy + r * Math.sin(angle);

                    ctx.beginPath();
                    ctx.arc(dx, dy, dotRadius, 0, Math.PI * 2);
                    ctx.fillStyle = (i < root.signalDots) ? root.activeColor : root.trackColor;
                    ctx.fill();
                }
            }

            Component.onCompleted: requestPaint()
        }

        // Center Network Icon (Wi-Fi or Ethernet)
        Image {
            id: centerImg
            anchors.centerIn: parent
            width: 10
            height: 10
            source: root.networkIcon
            fillMode: Image.PreserveAspectFit
            visible: root.networkIcon !== ""
            layer.enabled: true
            layer.effect: MultiEffect {
                brightness: 1.0
                colorization: 1.0
                colorizationColor: root.networkConnected ? root.activeColor : root.trackColor
            }
        }
    }

    // Battery Percentage Label (Below Ring)
    Row {
        anchors.top: ringContainer.bottom
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1

        Text {
            text: "󰂄"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 7
            color: root.activeColor
            visible: root.isCharging
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.batteryLabel
            color: root.activeColor
            font.pixelSize: 8
            font.weight: Font.Bold
            font.letterSpacing: 0.1
            anchors.verticalCenter: parent.verticalCenter
            visible: root.batteryLabel !== ""
        }
    }

    MouseArea {
        id: ringMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked();
            } else {
                root.clicked();
            }
        }
    }
}
