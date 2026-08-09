import QtQuick
import "Commons"

Item {
    id: root
    anchors.fill: parent
    property real radius: 0
    property color surfaceColor: "#11111b"
    property color accentColor: "#cba6f7"
    property color borderColor: Qt.rgba(1, 1, 1, 0.06)
    property bool active: false
    property string mode: Settings.isLoaded ? Settings.data.colorSchemes.hyprglassStyle : "liquid"
    property bool isFlare: false

    Connections {
        target: Settings.data.colorSchemes
        function onHyprglassStyleChanged() {
            root.mode = Settings.data.colorSchemes.hyprglassStyle;
        }
    }

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

    }

    // -------------------------------------------------------------
    // APPLE LIQUID GLASS / FROSTED STATE (WWDC 2025 Design Language)
    // -------------------------------------------------------------
    Item {
        anchors.fill: parent
        opacity: root.active ? 1.0 : 0.0
        visible: opacity > 0.0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        // 1. Translucent Liquid Tint / Frosted Glass Base
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: root.mode === "liquid" 
                   ? Qt.rgba(0.0, 0.0, 0.0, Settings.isLoaded ? Settings.data.colorSchemes.liquidOpacity : 0.12) 
                   : Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, Settings.isLoaded ? Settings.data.colorSchemes.frostedOpacity : 0.45)
        }

        // 2a. Dark Overlay Solid Color (for flares)
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: Qt.rgba(0.0, 0.0, 0.0, Settings.isLoaded ? (root.mode === "liquid" ? Settings.data.colorSchemes.liquidGradientOpacity : Settings.data.colorSchemes.frostedGradientOpacity) : 0.0)
            visible: root.isFlare && Settings.isLoaded && (root.mode === "liquid" ? Settings.data.colorSchemes.liquidGradientOpacity : Settings.data.colorSchemes.frostedGradientOpacity) > 0
        }

        // 2b. Dark Overlay Gradient
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            visible: !root.isFlare && Settings.isLoaded && (root.mode === "liquid" ? Settings.data.colorSchemes.liquidGradientOpacity : Settings.data.colorSchemes.frostedGradientOpacity) > 0
            
            gradient: Gradient {
                orientation: (Settings.isLoaded && (root.mode === "liquid" ? Settings.data.colorSchemes.liquidGradientHorizontal : Settings.data.colorSchemes.frostedGradientHorizontal)) ? Gradient.Horizontal : Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(0.0, 0.0, 0.0, Settings.isLoaded ? (root.mode === "liquid" ? Settings.data.colorSchemes.liquidGradientOpacity : Settings.data.colorSchemes.frostedGradientOpacity) : 0.0) }
                GradientStop { position: Settings.isLoaded ? (root.mode === "liquid" ? Settings.data.colorSchemes.liquidGradientStop : Settings.data.colorSchemes.frostedGradientStop) : 0.5; color: "transparent" }
            }
        }
    }
}
