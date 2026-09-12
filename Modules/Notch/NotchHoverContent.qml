import QtQuick
import QtQuick.Effects

// Content used only by the notch's hover state.  It is separate from the
// regular bar hover layout so enabling notch mode does not alter bar mode.
Item {
    id: root

    required property var shellRoot
    readonly property var shell: shellRoot || null
    readonly property color textColor: shell ? shell.textPrimary : "#ffffff"
    readonly property color dimColor: shell ? shell.textSecondary : "#c8c8c8"
    readonly property color mutedColor: shell ? shell.textMuted : "#808080"

    function week() {
        var today = new Date()
        var days = []
        var labels = ["S", "M", "T", "W", "T", "F", "S"]
        for (var i = -3; i <= 3; ++i) {
            var date = new Date(today)
            date.setDate(today.getDate() + i)
            days.push({ day: date.getDate(), weekday: labels[date.getDay()], isToday: i === 0 })
        }
        return days
    }

    Item {
        id: mediaArea
        width: 190
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Rectangle {
            id: artworkMask
            anchors.fill: artwork
            radius: artwork.radius
            visible: false
        }

        Rectangle {
            id: artwork
            width: 64
            height: 64
            radius: 14
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: shell && shell.mediaArtUrl ? "transparent" : Qt.alpha(shell ? shell.surfaceBright : "#303030", 0.72)

            Image {
                anchors.fill: parent
                source: shell ? (shell.mediaArtUrl || "") : ""
                visible: shell && shell.mediaArtUrl !== ""
                fillMode: Image.PreserveAspectCrop
                layer.enabled: visible
                layer.effect: MultiEffect { maskEnabled: true; maskSource: artworkMask }
            }

            Text {
                anchors.centerIn: parent
                visible: !shell || shell.mediaArtUrl === ""
                text: "♫"
                color: mutedColor
                font.pixelSize: 24
            }
        }

        Column {
            anchors.left: artwork.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: shell ? (shell.mediaTitle || "No media") : "No media"
                color: textColor
                font.pixelSize: 14
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: shell ? (shell.mediaArtist || "—") : "—"
                color: dimColor
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Item { width: 1; height: 5 }

            Row {
                spacing: 12

                Item {
                    width: 24; height: 24
                    Image { anchors.centerIn: parent; width: 12; height: 12; source: "../../icons/previous.png"; layer.enabled: true; layer.effect: MultiEffect { brightness: 1; colorization: 1; colorizationColor: textColor } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (shell && shell.mediaPlayer) shell.mediaPlayer.previous() } }
                }
                Item {
                    width: 24; height: 24
                    Image { anchors.centerIn: parent; width: 12; height: 12; source: shell && shell.mediaPlaying ? "../../icons/pause.png" : "../../icons/play-button.png"; layer.enabled: true; layer.effect: MultiEffect { brightness: 1; colorization: 1; colorizationColor: textColor } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (shell && shell.mediaPlayer) { if (shell.mediaPlaying) shell.mediaPlayer.pause(); else shell.mediaPlayer.play() } } }
                }
                Item {
                    width: 24; height: 24
                    Image { anchors.centerIn: parent; width: 12; height: 12; source: "../../icons/next.png"; layer.enabled: true; layer.effect: MultiEffect { brightness: 1; colorization: 1; colorizationColor: textColor } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (shell && shell.mediaPlayer) shell.mediaPlayer.next() } }
                }
            }
        }
    }

    Item {
        id: calendarArea
        width: 190
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: shell ? shell.currentTime12h : ""
                color: textColor
                font.pixelSize: 29
                font.weight: Font.Bold
                font.letterSpacing: 0.5
                font.family: "Varela Round"
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Repeater {
                    model: root.week()
                    delegate: Item {
                        required property var modelData
                        width: 16; height: 32
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.weekday; color: modelData.isToday ? textColor : Qt.alpha(mutedColor, 0.82); font.pixelSize: modelData.isToday ? 10 : 8; font.weight: modelData.isToday ? Font.Bold : Font.Medium }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.day; color: modelData.isToday ? textColor : Qt.alpha(mutedColor, 0.82); font.pixelSize: modelData.isToday ? 14 : 10; font.weight: modelData.isToday ? Font.Bold : Font.Medium }
                        }
                    }
                }
            }
        }
    }
}
