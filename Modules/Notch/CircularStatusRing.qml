import QtQuick
import QtQuick.Effects

Item {
    id: root

    // Battery binds to outer ring arc
    property real batteryRatio: 1.0
    property bool isCharging: false
    property color batteryColor: "#5F9C74"
    property color trackColor: Qt.rgba(1, 1, 1, 0.14)

    // Network binds to center icon & bottom 4 dots
    property int signalDots: 4       // 0 to 4 dots
    property color dotsActiveColor: "#ffffff"
    property string networkIcon: ""
    property color networkIconColor: "#ffffff"

    // Battery text label below ring
    property string batteryLabel: ""

    // Click signals
    signal clicked()
    signal rightClicked()

    width: 52
    height: 68

    property real animatedBatteryRatio: batteryRatio
    Behavior on animatedBatteryRatio {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    onAnimatedBatteryRatioChanged: ringCanvas.requestPaint()
    onBatteryColorChanged: ringCanvas.requestPaint()
    onSignalDotsChanged: ringCanvas.requestPaint()
    onDotsActiveColorChanged: ringCanvas.requestPaint()
    onTrackColorChanged: ringCanvas.requestPaint()

    scale: ringMouse.containsMouse ? 1.08 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    // Circular Ring Container
    Item {
        id: ringContainer
        width: 46
        height: 46
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
                var strokeWidth = 3.5;
                var r = (w - strokeWidth) / 2 - 2;

                // Arc angles: Clockwise from bottom-left (122° / 0.68*PI) across the top to bottom-right (58° / 2.32*PI)
                var startAngle = Math.PI * 0.68;
                var endAngle = Math.PI * 2.32;
                var totalSpan = endAngle - startAngle; // ~295 degrees

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

                // 3. Four discrete dots along the bottom opening (representing signal strength)
                // Left-to-right: 0.63*PI, 0.54*PI, 0.46*PI, 0.37*PI
                var dotAngles = [
                    Math.PI * 0.63,
                    Math.PI * 0.54,
                    Math.PI * 0.46,
                    Math.PI * 0.37
                ];
                var dotRadius = 1.8;

                for (var i = 0; i < 4; i++) {
                    var angle = dotAngles[i];
                    var dx = cx + r * Math.cos(angle);
                    var dy = cy + r * Math.sin(angle);

                    ctx.beginPath();
                    ctx.arc(dx, dy, dotRadius, 0, Math.PI * 2);
                    ctx.fillStyle = (i < root.signalDots) ? root.dotsActiveColor : root.trackColor;
                    ctx.fill();
                }
            }

            Component.onCompleted: requestPaint()
        }

        // Center Network Icon (Wi-Fi or Ethernet)
        Image {
            id: centerImg
            anchors.centerIn: parent
            width: 17
            height: 17
            source: root.networkIcon
            fillMode: Image.PreserveAspectFit
            visible: root.networkIcon !== ""
            layer.enabled: true
            layer.effect: MultiEffect {
                brightness: 1.0
                colorization: 1.0
                colorizationColor: root.networkIconColor
            }
        }
    }

    // Battery Percentage Label (Below Ring)
    Row {
        anchors.top: ringContainer.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        Text {
            text: "󰂄"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: root.batteryColor
            visible: root.isCharging
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.batteryLabel
            color: root.batteryColor
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 0.3
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
