import QtQuick
import QtQuick.Effects

Item {
    id: root

    property real value: 0.0          // 0.0 to 1.0
    property int activeDots: Math.round(value * 4) // 0 to 4 dots
    property color strokeColor: "#5F9C74"
    property color trackColor: Qt.rgba(1, 1, 1, 0.15)
    property color iconColor: strokeColor

    property string iconSource: ""
    property string iconGlyph: ""
    property string labelText: ""
    property color labelColor: strokeColor
    property string tooltipText: ""

    signal clicked()

    width: 44
    height: 58

    property real animatedValue: value
    Behavior on animatedValue {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    onAnimatedValueChanged: ringCanvas.requestPaint()
    onStrokeColorChanged: ringCanvas.requestPaint()
    onActiveDotsChanged: ringCanvas.requestPaint()
    onTrackColorChanged: ringCanvas.requestPaint()

    scale: ringMouse.containsMouse ? 1.08 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    // Circular Ring Container
    Item {
        id: ringContainer
        width: 42
        height: 42
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
                var strokeWidth = 3.0;
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

                // 2. Active progress arc
                var val = Math.max(0.0, Math.min(1.0, root.animatedValue));
                if (val > 0.01) {
                    ctx.strokeStyle = root.strokeColor;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, startAngle, startAngle + totalSpan * val, false);
                    ctx.stroke();
                }

                // 3. Four discrete dots along the bottom opening (from 122° to 58°, centered at 90° = 0.5*PI)
                // Left-to-right: 0.63*PI, 0.54*PI, 0.46*PI, 0.37*PI
                var dotAngles = [
                    Math.PI * 0.63,
                    Math.PI * 0.54,
                    Math.PI * 0.46,
                    Math.PI * 0.37
                ];
                var dotRadius = 1.6;

                for (var i = 0; i < 4; i++) {
                    var angle = dotAngles[i];
                    var dx = cx + r * Math.cos(angle);
                    var dy = cy + r * Math.sin(angle);

                    ctx.beginPath();
                    ctx.arc(dx, dy, dotRadius, 0, Math.PI * 2);
                    ctx.fillStyle = (i < root.activeDots) ? root.strokeColor : root.trackColor;
                    ctx.fill();
                }
            }

            Component.onCompleted: requestPaint()
        }

        // Center Icon (Image or Glyph)
        Image {
            id: centerImg
            anchors.centerIn: parent
            width: 16
            height: 16
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            visible: root.iconSource !== ""
            layer.enabled: true
            layer.effect: MultiEffect {
                brightness: 1.0
                colorization: 1.0
                colorizationColor: root.iconColor
            }
        }

        Text {
            id: centerText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: root.iconGlyph
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: root.iconColor
            visible: root.iconGlyph !== "" && root.iconSource === ""
        }
    }

    // Label Text (Below Ring)
    Text {
        anchors.top: ringContainer.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.labelText
        color: root.labelColor
        font.pixelSize: 9
        font.weight: Font.DemiBold
        font.letterSpacing: 0.5
        visible: root.labelText !== ""
    }

    MouseArea {
        id: ringMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
