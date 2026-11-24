import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
import "../utils/utils.js" as U
Item {
    id: root
    property var pluginApi: null
    property var mainInstance: null
    implicitWidth: parent?.width ?? 0
    implicitHeight: contentCol.implicitHeight
    readonly property string pickedHex: {
        var v = mainInstance?.resultHex ?? ""
        return (typeof v === "string" && v.length === 7 && v.charAt(0) === "#") ? v : ""
    }
    readonly property string pickedRgb: {
        var v = mainInstance?.resultRgb ?? ""
        return (typeof v === "string" && v !== "") ? v : ""
    }
    readonly property string pickedHsv: {
        var v = mainInstance?.resultHsv ?? ""
        return (typeof v === "string" && v !== "") ? v : ""
    }
    readonly property string pickedHsl: {
        var v = mainInstance?.resultHsl ?? ""
        return (typeof v === "string" && v !== "") ? v : ""
    }
    readonly property string colorCapturePath: mainInstance?.colorCapturePath ?? ""
    readonly property int    colorCacheBust:   mainInstance?.colorCacheBust ?? 0
    readonly property var    colorHistory:     mainInstance?.colorHistory ?? []
    Process { id: clipProc }
    function _copy(text) {
        if (!text || text === "") return
        clipProc.exec({
            command: ["bash", "-c", "printf '%s' " + U.shellEscape(text) + " | wl-copy 2>/dev/null"]
        })
    }
    function clear() {
        if (mainInstance) {
            mainInstance.clearColorResult()
            mainInstance.activeTool = ""
        }
    }
    Column {
        id: contentCol
        width: parent.width
        spacing: Style.marginM
        Rectangle {
            width: parent.width
            height: 36
            radius: Style.radiusM
            color: pickAgainBtn.containsMouse ? QuickIslandPalette.mPrimary : QuickIslandPalette.mSurface
            border.color: QuickIslandPalette.mPrimary
            border.width: Style.capsuleBorderWidth
            Row {
                anchors.centerIn: parent
                spacing: Style.marginS
                NIcon {
                    icon: "color-picker"
                    color: pickAgainBtn.containsMouse ? QuickIslandPalette.mOnPrimary : QuickIslandPalette.mPrimary
                }
                NText {
                    text: pluginApi?.tr("panel.pickAgain")
                    color: pickAgainBtn.containsMouse ? QuickIslandPalette.mOnPrimary : QuickIslandPalette.mPrimary
                    pointSize: Style.fontSizeS
                }
            }
            MouseArea {
                id: pickAgainBtn
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mainInstance?.runColorPicker()
            }
        }
        Column {
            visible: root.pickedHex !== ""
            width: parent.width
            spacing: Style.marginM
            Row {
                width: parent.width
                spacing: Style.marginM
                Rectangle {
                    width: 110
                    height: 110
                    radius: Style.radiusM
                    color: QuickIslandPalette.mSurfaceVariant
                    clip: true
                    border.color: Style.capsuleBorderColor
                    border.width: Style.capsuleBorderWidth
                    Image {
                        id: pixelImg
                        anchors.fill: parent
                        source: root.colorCapturePath !== ""
                            ? ("file://" + root.colorCapturePath + "?b=" + root.colorCacheBust)
                            : ""
                        fillMode: Image.Stretch
                        smooth: false
                        cache: false
                        visible: status === Image.Ready
                        onStatusChanged: {
                            if (status === Image.Ready) visible = true
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width:  12
                        height: 12
                        radius: 6
                        color: "transparent"
                        border.color: "white"
                        border.width: 2
                        visible: root.colorCapturePath !== ""
                        z:1
                    }
                    NText {
                        anchors.centerIn: parent
                        visible: pixelImg.status !== Image.Ready
                        text: pluginApi?.tr("panel.loading")
                        color: QuickIslandPalette.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                    }
                }
                Column {
                    width: parent.width - 110 - Style.marginM
                    spacing: Style.marginS
                    Rectangle {
                        id: colorSwatch
                        width: parent.width
                        height: 72
                        radius: Style.radiusM
                        color: root.pickedHex !== "" ? root.pickedHex : "#888888"
                        border.color: Style.capsuleBorderColor
                        border.width: Style.capsuleBorderWidth
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root._copy(root.pickedHex)
                                ToastService.notify(pluginApi?.tr("panel.formatCopied", { label: pluginApi?.tr("panel.labelHex") }), "", "circle-check", root.pickedHex, 3000, "", null)
                            }
                        }
                    }
                    NText {
                        width: parent.width
                        text: root.pickedHex.toUpperCase()
                        color: QuickIslandPalette.mOnSurface
                        font.weight: Font.Bold
                        pointSize: Style.fontSizeM
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            Repeater {
                model: [
                    { label: pluginApi?.tr("panel.labelHex"), value: root.pickedHex },
                    { label: pluginApi?.tr("panel.labelRgb"), value: root.pickedRgb },
                    { label: pluginApi?.tr("panel.labelHsl"), value: root.pickedHsl },
                    { label: pluginApi?.tr("panel.labelHsv"), value: root.pickedHsv }
                ]
                delegate: Rectangle {
                    width: root.width
                    height: 36
                    radius: Style.radiusM
                    color: rh.containsMouse ? QuickIslandPalette.mHover : QuickIslandPalette.mSurface
                    border.color: Style.capsuleBorderColor
                    border.width: Style.capsuleBorderWidth
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Style.marginS
                        anchors.rightMargin: Style.marginS
                        spacing: Style.marginS
                        NText {
                            text: (modelData && modelData.label) ? modelData.label : ""
                            color: QuickIslandPalette.mPrimary
                            font.weight: Font.Bold
                            pointSize: Style.fontSizeS
                            width: 36
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                        }
                        NText {
                            text: modelData.value || "—"
                            color: QuickIslandPalette.mOnSurface
                            pointSize: Style.fontSizeS
                            width: root.width - 90
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                    NIcon {
                        icon: "copy"
                        color: rh.containsMouse ? QuickIslandPalette.mPrimary : QuickIslandPalette.mOnSurfaceVariant
                        anchors.right: parent.right
                        anchors.rightMargin: Style.marginS
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    MouseArea {
                        id: rh
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root._copy(modelData.value)
                            ToastService.notify(pluginApi?.tr("panel.formatCopied", { label: modelData.label }), "", "circle-check", root.pickedHex, 3000, "", null)
                        }
                    }
                }
            }
            Column {
                width: parent.width
                spacing: Style.marginS
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: Style.radiusM
                    color: cah.containsMouse ? QuickIslandPalette.mSurfaceVariant : QuickIslandPalette.mSurface
                    border.color: Style.capsuleBorderColor
                    border.width: Style.capsuleBorderWidth
                    Row {
                        anchors.centerIn: parent
                        spacing: Style.marginS
                        NIcon {
                            icon: "copy"
                            color: cah.containsMouse ? QuickIslandPalette.mOnSurface : QuickIslandPalette.mOnSurfaceVariant
                        }
                        NText {
                            text: pluginApi?.tr("panel.copyAll")
                            color: cah.containsMouse ? QuickIslandPalette.mOnSurface : QuickIslandPalette.mOnSurfaceVariant
                            pointSize: Style.fontSizeS
                        }
                    }
                    MouseArea {
                        id: cah
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root._copy(root.pickedHex + "\n" + root.pickedRgb + "\n" + root.pickedHsl + "\n" + root.pickedHsv)
                            ToastService.notify(pluginApi?.tr("panel.allFormatsCopied"), "", "copy", root.pickedHex, 3000, "", null)
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: Style.radiusM
                    color: clrh.containsMouse ? Qt.alpha(QuickIslandPalette.mError, 0.15) : QuickIslandPalette.mSurface
                    border.color: clrh.containsMouse ? QuickIslandPalette.mError : Style.capsuleBorderColor
                    border.width: Style.capsuleBorderWidth
                    Row {
                        anchors.centerIn: parent
                        spacing: Style.marginS
                        NIcon {
                            icon: "trash"
                            color: clrh.containsMouse ? QuickIslandPalette.mError : QuickIslandPalette.mOnSurfaceVariant
                        }
                        NText {
                            text: pluginApi?.tr("panel.clearResult")
                            color: clrh.containsMouse ? QuickIslandPalette.mError : QuickIslandPalette.mOnSurfaceVariant
                            pointSize: Style.fontSizeS
                        }
                    }
                    MouseArea {
                        id: clrh
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clear()
                    }
                }
            }
        }
        Column {
            width: parent.width
            spacing: Style.marginS
            visible: root.colorHistory.length > 0

            Item {
                width:  parent.width
                height: 22

                Rectangle {
                    anchors.left:           parent.left
                    anchors.right:          historyLabel.left
                    anchors.rightMargin:    Style.marginS
                    anchors.verticalCenter: parent.verticalCenter
                    height:  1
                    color:   QuickIslandPalette.mOnSurfaceVariant
                    opacity: 0.3
                }

                NText {
                    id:              historyLabel
                    anchors.centerIn: parent
                    text:             pluginApi?.tr("panel.history")
                    color:            QuickIslandPalette.mOnSurfaceVariant
                    pointSize:        Style.fontSizeXS
                }

                Rectangle {
                    anchors.left:           historyLabel.right
                    anchors.leftMargin:     Style.marginS
                    anchors.right:          clearHistoryBtn.left
                    anchors.rightMargin:    Style.marginS
                    anchors.verticalCenter: parent.verticalCenter
                    height:  1
                    color:   QuickIslandPalette.mOnSurfaceVariant
                    opacity: 0.3
                }

                Rectangle {
                    id:                     clearHistoryBtn
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width:  22; height: 22
                    radius: Style.radiusS
                    color:  hhc.containsMouse ? QuickIslandPalette.mError : "transparent"
                    NIcon {
                        anchors.centerIn: parent
                        icon:  "trash"
                        scale: 0.75
                        color: hhc.containsMouse ? QuickIslandPalette.mError : QuickIslandPalette.mOnSurfaceVariant
                    }
                    MouseArea {
                        id:          hhc
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            mainInstance?.clearColorHistory()
                            ToastService.showNotice(pluginApi?.tr("panel.historyCleared"))
                        }
                    }
                }
            }
            Flow {
                width: parent.width
                spacing: Style.marginS
                Repeater {
                    model: root.colorHistory
                    delegate: Rectangle {
                        width: 28
                        height: 28
                        radius: Style.radiusS
                        border.color: hh.containsMouse ? QuickIslandPalette.mPrimary : Style.capsuleBorderColor
                        border.width: hh.containsMouse ? 2 : Style.capsuleBorderWidth
                        Component.onCompleted: color = modelData
                        MouseArea {
                            id: hh
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root._copy(modelData)
                                ToastService.notify(pluginApi?.tr("panel.colorCopied", { color: modelData }), "", "circle-check", modelData, 3000, "", null)
                            }
                            onEntered: TooltipService.show(hh, modelData.toUpperCase() + " — " + pluginApi?.tr("panel.clickToCopy"))
                            onExited: TooltipService.hide()
                        }
                    }
                }
            }
        }
    }
}

