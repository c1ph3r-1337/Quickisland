import QtQuick

Item {
    id: root
    anchors.fill: parent
    property real radius: 0
    property color surfaceColor: "#11111b"
    property color accentColor: "#cba6f7"
    property color borderColor: Qt.rgba(1, 1, 1, 0.06)
    property bool active: false

    // -------------------------------------------------------------
    // DEFAULT STATE (Opaque Surface)
    // -------------------------------------------------------------
    Item {
        anchors.fill: parent
        opacity: root.active ? 0.0 : 1.0
        visible: opacity > 0.0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        // Base fill
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: root.surfaceColor
        }

        // Default top highlight gradient
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.035) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }

        // Default border
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            border.width: 1
            border.color: root.borderColor
        }
    }

    // -------------------------------------------------------------
    // APPLE LIQUID GLASS STATE (WWDC 2025 Design Language)
    // -------------------------------------------------------------
    Item {
        anchors.fill: parent
        opacity: root.active ? 1.0 : 0.0
        visible: opacity > 0.0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        // 1. Translucent Liquid Tint (Base Glass Material)
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: root.surfaceColor
        }
    }
}
