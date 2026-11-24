import QtQuick

Item {
    id: root

    property string text: ""
    property color color: "white"
    property font font: Qt.font({ family: "Sans", pixelSize: 14 })
    property bool rollingEnabled: false
    property int rollDuration: 240

    implicitWidth: digitRow.implicitWidth
    implicitHeight: digitRow.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Row {
        id: digitRow
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.text.length

            delegate: Item {
                id: digitCell

                property string nextCharacter: root.text.charAt(index)
                property string shownCharacter: ""
                property bool rolling: false

                Component.onCompleted: shownCharacter = nextCharacter

                TextMetrics {
                    id: characterMetrics
                    font: root.font
                    text: digitCell.nextCharacter >= "0" && digitCell.nextCharacter <= "9"
                        ? "8"
                        : digitCell.nextCharacter
                }

                width: characterMetrics.width
                height: characterMetrics.height
                clip: true

                Text {
                    id: currentCharacter
                    text: digitCell.shownCharacter
                    color: root.color
                    font: root.font
                    width: digitCell.width
                    height: digitCell.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    y: 0
                }

                Text {
                    id: incomingCharacter
                    text: digitCell.nextCharacter
                    color: root.color
                    font: root.font
                    width: digitCell.width
                    height: digitCell.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    y: -digitCell.height
                    visible: digitCell.rolling
                }

                ParallelAnimation {
                    id: digitRoll

                    NumberAnimation {
                        target: currentCharacter
                        property: "y"
                        to: digitCell.height
                        duration: root.rollDuration
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: incomingCharacter
                        property: "y"
                        to: 0
                        duration: root.rollDuration
                        easing.type: Easing.OutCubic
                    }

                    onFinished: {
                        digitCell.shownCharacter = digitCell.nextCharacter;
                        digitCell.rolling = false;
                        currentCharacter.y = 0;
                        incomingCharacter.y = -digitCell.height;
                    }
                }

                onNextCharacterChanged: {
                    if (shownCharacter === "") {
                        shownCharacter = nextCharacter;
                        return;
                    }
                    if (nextCharacter === shownCharacter)
                        return;

                    var digitChanged = nextCharacter >= "0" && nextCharacter <= "9"
                            && shownCharacter >= "0" && shownCharacter <= "9";
                    if (root.rollingEnabled && digitChanged) {
                        digitCell.rolling = true;
                        currentCharacter.y = 0;
                        incomingCharacter.y = -digitCell.height;
                        digitRoll.restart();
                    } else {
                        digitRoll.stop();
                        digitCell.rolling = false;
                        digitCell.shownCharacter = nextCharacter;
                        currentCharacter.y = 0;
                        incomingCharacter.y = -digitCell.height;
                    }
                }

                Connections {
                    target: root
                    function onRollingEnabledChanged() {
                        if (!root.rollingEnabled) {
                            digitRoll.stop();
                            digitCell.rolling = false;
                            digitCell.shownCharacter = digitCell.nextCharacter;
                            currentCharacter.y = 0;
                            incomingCharacter.y = -digitCell.height;
                        }
                    }
                }
            }
        }
    }
}
