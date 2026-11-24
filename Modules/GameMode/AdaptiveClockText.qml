import QtQuick
import qs.Commons
import qs.Services.Power
import qs.Widgets

Item {
    id: root

    property string text: ""
    property string family: Settings.data.ui.fontDefault
    property real pointSize: Style.fontSizeM
    property int weight: Style.fontWeightMedium
    property color color: QuickIslandPalette.mOnSurface
    property int wrapMode: Text.NoWrap
    property int horizontalAlignment: Text.AlignLeft
    property var features: ({})

    readonly property real fontScale: family === Settings.data.ui.fontDefault
        ? Settings.data.ui.fontDefaultScale
        : Settings.data.ui.fontFixedScale
    readonly property real effectivePointSize: pointSize * fontScale

    implicitWidth: PowerProfileService.quickislandGameMode
        ? rollingText.implicitWidth
        : regularText.implicitWidth
    implicitHeight: PowerProfileService.quickislandGameMode
        ? rollingText.implicitHeight
        : regularText.implicitHeight
    NText {
        id: regularText
        anchors.fill: parent
        visible: !PowerProfileService.quickislandGameMode
        text: root.text
        family: root.family
        pointSize: root.pointSize
        font.weight: root.weight
        applyUiScale: false
        color: root.color
        wrapMode: root.wrapMode
        horizontalAlignment: root.horizontalAlignment
        features: root.features
    }

    RollingTime {
        id: rollingText
        anchors.centerIn: parent
        visible: PowerProfileService.quickislandGameMode
        rollingEnabled: true
        text: root.text
        color: root.color
        font: Qt.font({
            family: root.family,
            pointSize: root.effectivePointSize,
            weight: root.weight
        })
    }
}
