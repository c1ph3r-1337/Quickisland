import QtQuick

Item {
    id: root

    property string text: ""
    property color color: "white"
    property font font: Qt.font({ family: "Sans", pixelSize: 14 })
    property bool rollingEnabled: false
    property int rollDuration: 240

    implicitWidth: rollingEnabled ? rollingText.implicitWidth : regularText.implicitWidth
    implicitHeight: rollingEnabled ? rollingText.implicitHeight : regularText.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Text {
        id: regularText
        visible: !root.rollingEnabled
        text: root.text
        color: root.color
        font: root.font
    }

    RollingTime {
        id: rollingText
        anchors.centerIn: parent
        visible: root.rollingEnabled
        text: root.text
        color: root.color
        font: root.font
        rollingEnabled: root.rollingEnabled
        rollDuration: root.rollDuration
    }
}
