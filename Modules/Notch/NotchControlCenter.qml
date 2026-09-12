import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.Commons

Item {
    id: ccView
    property var shell
    property var panelWindow
    property bool ccActive: true
    width: 460
    height: Math.min(ccColumn.height, 600)

    Flickable {
        anchors.fill: parent
        contentHeight: ccColumn.height
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: ccColumn; width: parent.width; spacing: 10

                            // Header
                            Item {
                                width: parent.width; height: 32
                                
                                Row {
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                                    Item {
                                        width: 32; height: 32
                                        Image {
                                            anchors.centerIn: parent; width: 20; height: 20
                                            source: "../../icons/back.png"
                                            fillMode: Image.PreserveAspectFit
                                            layer.enabled: ccView.ccActive
                                            layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textPrimary }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(0) }
                                    }
                                    Text { text: "Control Center"; color: shell.textPrimary; font.pixelSize: 16; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                }
                                
                                Item {
                                    width: 32; height: 32; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.centerIn: parent; width: 20; height: 20
                                        source: "../../icons/settings.svg"
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: ccView.ccActive
                                        layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textPrimary }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.setState(19) }
                                }
                            }

                            // Row 1: Wi-Fi + Audio
                            Row {
                                width: parent.width; spacing: 8

                                Rectangle {
                                    width: 130; height: 45; radius: 22.5
                                    color: wma.containsMouse ? shell.surfaceBright : (shell.wifiEnabled ? shell.accentDim : shell.surfaceAlt)
                                    border.width: (Settings.isLoaded && Settings.data.colorSchemes.hyprglass) ? 0 : (shell.wifiEnabled ? 1 : 0)
                                    border.color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2)

                                    Row {
                                        anchors.fill: parent; anchors.margins: 8; spacing: 8
                                        Rectangle {
                                            width: 28; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                                            color: shell.wifiEnabled ? shell.accent : shell.surfaceBright
                                            Image {
                                                anchors.centerIn: parent; width: 16; height: 16
                                                source: "../../icons/wifi.png"
                                                fillMode: Image.PreserveAspectFit
                                                layer.enabled: ccView.ccActive
                                                layer.effect: MultiEffect {
                                                    brightness: shell.wifiEnabled ? -0.8 : 1.0
                                                    colorization: 1.0
                                                    colorizationColor: shell.wifiEnabled ? shell._baseSurface : "#ffffff"
                                                }
                                            }
                                        }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { text: "Wi-Fi"; color: "#ffffff"; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            Text { text: shell.wifiEnabled ? (shell.wifiConnected ? shell.wifiSSID : "Disconnected") : "Off"; color: "#dddddd"; font.pixelSize: 9; elide: Text.ElideRight; width: 70 }
                                        }
                                    }

                                    MouseArea {
                                        id: wma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shell.setState(8)
                                    }
                                }

                                Rectangle {
                                    width: parent.width - 130 - parent.spacing; height: 45; radius: 22.5
                                    color: audma.containsMouse ? shell.surfaceBright : (!shell.sysMuted ? shell.accentDim : shell.surfaceAlt)
                                    border.width: (Settings.isLoaded && Settings.data.colorSchemes.hyprglass) ? 0 : (!shell.sysMuted ? 1 : 0)
                                    border.color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2)

                                    Row {
                                        anchors.fill: parent; anchors.margins: 8; spacing: 8
                                        Rectangle {
                                            width: 28; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                                            color: !shell.sysMuted ? shell.accent : shell.surfaceBright
                                            Image {
                                                anchors.centerIn: parent; width: 16; height: 16
                                                source: "../../icons/volume.png"
                                                fillMode: Image.PreserveAspectFit
                                                layer.enabled: ccView.ccActive
                                                layer.effect: MultiEffect {
                                                    brightness: !shell.sysMuted ? -0.8 : 1.0
                                                    colorization: 1.0
                                                    colorizationColor: !shell.sysMuted ? shell._baseSurface : "#ffffff"
                                                }
                                            }
                                        }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { text: "Audio"; color: "#ffffff"; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            Text { text: shell.sysMuted ? "Muted" : Math.round(shell.sysVolume * 100) + "%"; color: shell.textSecondary; font.pixelSize: 9 }
                                        }
                                    }

                                    MouseArea {
                                        id: audma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shell.toggleMute()
                                    }
                                }
                            }

                            // Row 2: Bluetooth + Peace + Night Light
                            Row {
                                width: parent.width; spacing: 8

                                Rectangle {
                                    id: btBtn
                                    width: Math.floor((parent.width - (parent.spacing * 2)) / 3); height: 45; radius: 22.5
                                    color: bta.containsMouse ? shell.surfaceBright : (shell.btPowered ? shell.accentDim : shell.surfaceAlt)
                                    border.width: (Settings.isLoaded && Settings.data.colorSchemes.hyprglass) ? 0 : (shell.btPowered ? 1 : 0)
                                    border.color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2)

                                    Row {
                                        anchors.fill: parent; anchors.margins: 8; spacing: 6
                                        Rectangle {
                                            width: 26; height: 26; radius: 13; color: shell.btPowered ? shell.accent : shell.surfaceBright; anchors.verticalCenter: parent.verticalCenter
                                            Image {
                                                anchors.centerIn: parent; width: 14; height: 14
                                                source: "../../icons/bluetooth.png"
                                                fillMode: Image.PreserveAspectFit
                                                layer.enabled: ccView.ccActive
                                                layer.effect: MultiEffect {
                                                    brightness: 1.0
                                                    colorization: 1.0
                                                    colorizationColor: shell.btPowered ? shell.surface : shell.textMuted
                                                }
                                            }
                                        }
                                        Column { anchors.verticalCenter: parent.verticalCenter; Text { text: "Bluetooth"; color: "#ffffff"; font.pixelSize: 10; font.weight: Font.DemiBold } Text { text: shell.btPowered ? "On" : "Off"; color: "#dddddd"; font.pixelSize: 8 } }
                                    }

                                    MouseArea {
                                        id: bta
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shell.setState(9)
                                    }
                                }
                                Rectangle {
                                    id: peaceBtn
                                    width: Math.floor((parent.width - (parent.spacing * 2)) / 3); height: 45; radius: 22.5
                                    color: pea.containsMouse ? shell.surfaceBright : (shell.peaceMode ? shell.accentDim : shell.surfaceAlt)
                                    border.width: (Settings.isLoaded && Settings.data.colorSchemes.hyprglass) ? 0 : (shell.peaceMode ? 1 : 0)
                                    border.color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2)

                                    Row {
                                        anchors.fill: parent; anchors.margins: 8; spacing: 6
                                        Rectangle {
                                            width: 26; height: 26; radius: 13; color: shell.peaceMode ? shell.accent : shell.surfaceBright; anchors.verticalCenter: parent.verticalCenter
                                            Image {
                                                anchors.centerIn: parent; width: 14; height: 14
                                                source: "../../icons/peace(dnd).png"
                                                fillMode: Image.PreserveAspectFit
                                                layer.enabled: ccView.ccActive
                                                layer.effect: MultiEffect {
                                                    brightness: 1.0
                                                    colorization: 1.0
                                                    colorizationColor: shell.peaceMode ? shell.surface : shell.textMuted
                                                }
                                            }
                                        }
                                        Column { anchors.verticalCenter: parent.verticalCenter; Text { text: "Peace"; color: "#ffffff"; font.pixelSize: 10; font.weight: Font.DemiBold } Text { text: shell.peaceMode ? "On" : "Off"; color: "#dddddd"; font.pixelSize: 8 } }
                                    }

                                    MouseArea {
                                        id: pea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shell.peaceMode = !shell.peaceMode
                                    }
                                }
                                Rectangle {
                                    width: parent.width - btBtn.width - peaceBtn.width - (parent.spacing * 2); height: 45; radius: 22.5
                                    color: nia.containsMouse ? shell.surfaceBright : (shell.nightMode ? shell.accentDim : shell.surfaceAlt)
                                    border.width: (Settings.isLoaded && Settings.data.colorSchemes.hyprglass) ? 0 : (shell.nightMode ? 1 : 0)
                                    border.color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2)

                                    Row {
                                        anchors.fill: parent; anchors.margins: 8; spacing: 6
                                        Rectangle {
                                            width: 26; height: 26; radius: 13; color: shell.nightMode ? shell.accent : shell.surfaceBright; anchors.verticalCenter: parent.verticalCenter
                                            Image {
                                                anchors.centerIn: parent; width: 14; height: 14
                                                source: "../../icons/night.png"
                                                fillMode: Image.PreserveAspectFit
                                                layer.enabled: ccView.ccActive
                                                layer.effect: MultiEffect {
                                                    brightness: 1.0
                                                    colorization: 1.0
                                                    colorizationColor: shell.nightMode ? shell.surface : shell.textMuted
                                                }
                                            }
                                        }
                                        Column { anchors.verticalCenter: parent.verticalCenter; Text { text: "Night"; color: "#ffffff"; font.pixelSize: 10; font.weight: Font.DemiBold } Text { text: shell.nightMode ? "On" : "Off"; color: "#dddddd"; font.pixelSize: 8 } }
                                    }

                                    MouseArea {
                                        id: nia
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shell.nightMode = !shell.nightMode
                                    }
                                }
                            }

                             // Personalization & Screen Toolkit Row
                             Row {
                                 width: parent.width; spacing: 8

                                 // Personalization (Left)
                                 Rectangle {
                                     width: (parent.width - 8) / 2; height: 45; radius: 22.5
                                     color: persBtnMa.containsMouse ? shell.surfaceBright : ((shell.currentState === 12 || shell.currentState === 11) ? shell.accentDim : shell.surfaceAlt)
                                     border.width: (Settings.isLoaded && Settings.data.colorSchemes.hyprglass) ? 0 : (1)
                                     border.color: (shell.currentState === 12 || shell.currentState === 11) ? Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2) : shell.surfaceBorder
                                     Behavior on color { ColorAnimation { duration: shell.animFast } }

                                     Row {
                                         anchors.fill: parent; anchors.margins: 8; spacing: 6
                                         Rectangle {
                                             width: 28; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                                             color: (shell.currentState === 12 || shell.currentState === 11) ? shell.accent : shell.surfaceBright
                                             Image {
                                                 anchors.centerIn: parent; width: 16; height: 16
                                                 source: "../../icons/palette.png"
                                                 fillMode: Image.PreserveAspectFit
                                                 layer.enabled: ccView.ccActive
                                                 layer.effect: MultiEffect {
                                                     brightness: 1.0
                                                     colorization: 1.0
                                                     colorizationColor: (shell.currentState === 12 || shell.currentState === 11) ? shell.surface : shell.textMuted
                                                 }
                                             }
                                         }
                                         Column {
                                             anchors.verticalCenter: parent.verticalCenter
                                             Text { text: "Personalization"; color: "#ffffff"; font.pixelSize: 10; font.weight: Font.DemiBold }
                                             Text { text: "Wallpaper, themes..."; color: "#dddddd"; font.pixelSize: 8 }
                                         }
                                     }

                                     MouseArea {
                                         id: persBtnMa
                                         anchors.fill: parent
                                         hoverEnabled: true
                                         cursorShape: Qt.PointingHandCursor
                                         onClicked: shell.setState(12)
                                     }
                                 }

                                 // Screen Toolkit (Right)
                                 Rectangle {
                                     width: (parent.width - 8) / 2; height: 45; radius: 22.5
                                     color: screenToolkitBtnMa.containsMouse ? shell.surfaceBright : (shell.currentState === 14 ? shell.accentDim : shell.surfaceAlt)
                                     border.width: (Settings.isLoaded && Settings.data.colorSchemes.hyprglass) ? 0 : (1)
                                     border.color: shell.currentState === 14 ? Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.2) : shell.surfaceBorder
                                     Behavior on color { ColorAnimation { duration: shell.animFast } }

                                     Row {
                                         anchors.fill: parent; anchors.margins: 8; spacing: 6
                                         Rectangle {
                                             width: 28; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                                             color: shell.currentState === 14 ? shell.accent : shell.surfaceBright
                                              Image {
                                                  anchors.centerIn: parent; width: 16; height: 16
                                                  source: "../../icons/screentools.png"
                                                  fillMode: Image.PreserveAspectFit
                                                  layer.enabled: ccView.ccActive
                                                  layer.effect: MultiEffect {
                                                      brightness: 1.0
                                                      colorization: 1.0
                                                      colorizationColor: shell.currentState === 14 ? shell.surface : shell.textMuted
                                                  }
                                              }
                                         }
                                         Column {
                                             anchors.verticalCenter: parent.verticalCenter
                                             Text { text: "Screen Toolkit"; color: "#ffffff"; font.pixelSize: 10; font.weight: Font.DemiBold }
                                             Text { text: "Capture, record, OCR..."; color: shell.textSecondary; font.pixelSize: 8 }
                                         }
                                     }

                                     MouseArea {
                                         id: screenToolkitBtnMa
                                         anchors.fill: parent
                                         hoverEnabled: true
                                         cursorShape: Qt.PointingHandCursor
                                         onClicked: shell.setState(14)
                                     }
                                 }
                         }
                         
                         // Audio Slider
                         Rectangle {
                             width: parent.width; height: 36; radius: 18
                             color: shell.surfaceAlt
                             border.width: (Settings.isLoaded && Settings.data.colorSchemes.hyprglass) ? 0 : 1
                             border.color: shell.surfaceBorder

                             Rectangle {
                                 width: Math.max(18, parent.width * shell.sysVolume)
                                 height: parent.height; radius: 18
                                 color: shell.accent
                                 Behavior on width { NumberAnimation { duration: shell.animFast; easing.type: Easing.OutCubic } }
                             }

                             // Icon (overlayed on left)
                                Image {
                                    width: 15; height: 15
                                    anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                    source: "../../icons/volume.png"
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: ccView.ccActive
                                    layer.effect: MultiEffect {
                                        brightness: shell.sysVolume > 0.08 && !shell.sysMuted ? -0.8 : 1.0
                                        colorization: 1.0
                                        colorizationColor: shell.sysVolume > 0.08 && !shell.sysMuted ? shell._baseSurface : "#ffffff"
                                    }
                                }


                                MouseArea {
                                    id: volMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    onPressed: (mouse) => {
                                        shell.volDragging = true;
                                        mouse.accepted = true;
                                        shell.setVolume(mouse.x / width);
                                    }
                                    onReleased: (mouse) => {
                                        shell.volDragging = false;
                                    }
                                    onCanceled: {
                                        shell.volDragging = false;
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (pressed) {
                                            shell.setVolume(mouse.x / width);
                                        }
                                    }
                                    onWheel: (wheel) => {
                                        var step = 0.02;
                                        if (wheel.angleDelta.y > 0) {
                                            shell.setVolume(shell.sysVolume + step);
                                        } else if (wheel.angleDelta.y < 0) {
                                            shell.setVolume(shell.sysVolume - step);
                                        }
                                        wheel.accepted = true;
                                    }
                                }
                            }

                            // Brightness Slider (real)
                            Rectangle {
                                width: parent.width; height: 30; radius: 15; color: shell.surfaceBright; clip: true

                                // Fill
                                Rectangle {
                                    width: parent.width * shell.sysBrightness
                                    height: parent.height
                                    radius: parent.radius
                                    color: shell.peach
                                    Behavior on width {
                                        enabled: !brightMouseArea.pressed
                                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                    }
                                }

                                // Icon (overlayed on left)
                                Image {
                                    width: 15; height: 15
                                    anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                    source: "../../icons/brightness.png"
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: ccView.ccActive
                                    layer.effect: MultiEffect {
                                        brightness: shell.sysBrightness > 0.08 ? -0.8 : 1.0
                                        colorization: 1.0
                                        colorizationColor: shell.sysBrightness > 0.08 ? shell._baseSurface : "#ffffff"
                                    }
                                }


                                MouseArea {
                                    id: brightMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    onPressed: (mouse) => {
                                        mouse.accepted = true;
                                        shell.setBrightness(mouse.x / width);
                                    }
                                    onReleased: (mouse) => {
                                        // Released handler empty
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (pressed) {
                                            shell.setBrightness(mouse.x / width);
                                        }
                                    }
                                    onWheel: (wheel) => {
                                        var step = 0.02;
                                        if (wheel.angleDelta.y > 0) {
                                            shell.setBrightness(shell.sysBrightness + step);
                                        } else if (wheel.angleDelta.y < 0) {
                                            shell.setBrightness(shell.sysBrightness - step);
                                        }
                                        wheel.accepted = true;
                                    }
                                }
                            }

                            // Media Card (real)
                            Rectangle {
                                width: parent.width; height: 115; radius: 16; color: shell.surfaceAlt; clip: true
                                visible: shell.mediaTitle !== ""

                                Rectangle {
                                    anchors.fill: parent; radius: parent.radius
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.12) }
                                        GradientStop { position: 0.5; color: Qt.rgba(shell.red.r, shell.red.g, shell.red.b, 0.08) }
                                        GradientStop { position: 1.0; color: Qt.rgba(shell.accent.r, shell.accent.g, shell.accent.b, 0.05) }
                                    }
                                }

                                Row {
                                    anchors.fill: parent; anchors.margins: 15; spacing: 15

                                    // Album Art / Fallback
                                    Rectangle {
                                        id: albumArtContainer
                                        width: 85; height: 85; radius: 10; color: shell.surfaceBright
                                        anchors.verticalCenter: parent.verticalCenter

                                        layer.enabled: ccView.ccActive
                                        layer.smooth: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: ShaderEffectSource {
                                                sourceItem: Rectangle {
                                                    width: 85
                                                    height: 85
                                                    radius: 10
                                                    color: "white"
                                                }
                                            }
                                        }

                                        Image {
                                            id: albumArtImage
                                            anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                                            source: shell.mediaArtUrl !== "" ? shell.mediaArtUrl : ""
                                            visible: shell.mediaArtUrl !== ""
                                        }
                                        Image {
                                            width: 32; height: 32; anchors.centerIn: parent
                                            source: "../../icons/volume.png"
                                            fillMode: Image.PreserveAspectFit
                                            visible: shell.mediaArtUrl === ""
                                            layer.enabled: ccView.ccActive
                                            layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textMuted }
                                        }
                                    }

                                    // Right Content Column
                                    Column {
                                        width: parent.width - 85 - 15; spacing: 6; anchors.verticalCenter: parent.verticalCenter

                                        // Song info
                                        Column {
                                            width: parent.width; spacing: 1
                                            Text { text: shell.mediaTitle; color: shell.textPrimary; font.pixelSize: 13; font.weight: Font.Bold; elide: Text.ElideRight; width: parent.width }
                                            Text { text: shell.mediaArtist; color: shell.textSecondary; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width }
                                        }

                                        // Progress bar
                                        Item {
                                            width: parent.width; height: 4
                                            Rectangle {
                                                width: parent.width; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.1)
                                                Rectangle {
                                                    width: shell.mediaLength > 0 ? parent.width * (shell.mediaPosition / shell.mediaLength) : 0
                                                    height: parent.height; radius: parent.radius; color: shell.accent
                                                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.Linear } }
                                                }
                                            }
                                        }

                                        // Time labels
                                        Item {
                                            width: parent.width; height: 10
                                            Text {
                                                function fmt(s) { var m=Math.floor(s/60); var ss=Math.floor(s%60); return m+":"+(ss<10?"0":"")+ss; }
                                                text: fmt(shell.mediaPosition); color: shell.textMuted; font.pixelSize: 8; anchors.left: parent.left
                                            }
                                            Text {
                                                function fmt(s) { var m=Math.floor(s/60); var ss=Math.floor(s%60); return m+":"+(ss<10?"0":"")+ss; }
                                                text: fmt(shell.mediaLength); color: shell.textMuted; font.pixelSize: 8; anchors.right: parent.right
                                            }
                                        }

                                        Item { width: 1; height: 2 } // Spacer

                                        // Media Controls Row
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 24

                                            // Previous
                                            Item {
                                                width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
                                                Image {
                                                    anchors.fill: parent; source: "../../icons/previous.png"
                                                    fillMode: Image.PreserveAspectFit
                                                    layer.enabled: ccView.ccActive
                                                    layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textSecondary }
                                                }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (shell.mediaPlayer) shell.mediaPlayer.previous(); } }
                                            }

                                            // Play/Pause
                                            Rectangle {
                                                width: 26; height: 26; radius: 13; color: shell.textPrimary
                                                anchors.verticalCenter: parent.verticalCenter
                                                Image {
                                                    anchors.centerIn: parent
                                                    width: 12; height: 12
                                                    source: shell.mediaPlaying ? "../../icons/pause.png" : "../../icons/play-button.png"
                                                    fillMode: Image.PreserveAspectFit
                                                    layer.enabled: ccView.ccActive
                                                    layer.effect: MultiEffect { brightness: -0.8; colorization: 1.0; colorizationColor: shell._baseSurface }
                                                }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (shell.mediaPlayer) { if (shell.mediaPlaying) shell.mediaPlayer.pause(); else shell.mediaPlayer.play(); } } }
                                            }

                                            // Next
                                            Item {
                                                width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
                                                Image {
                                                    anchors.fill: parent; source: "../../icons/next.png"
                                                    fillMode: Image.PreserveAspectFit
                                                    layer.enabled: ccView.ccActive
                                                    layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: shell.textSecondary }
                                                }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (shell.mediaPlayer) shell.mediaPlayer.next(); } }
                                            }
                                        }
                                    }
                                }
                            }

                            // No media placeholder
                            Rectangle {
                                width: parent.width; height: 48; radius: 14; color: shell.surfaceAlt
                                visible: false
                                Text { anchors.centerIn: parent; text: "No media playing"; color: shell.textMuted; font.pixelSize: 11 }
                            }

                            // Notifications
                            Column {
                                width: parent.width
                                spacing: 8
                                visible: shell.notifHistory.count > 0

                                Row {
                                    width: parent.width
                                    Text { text: "Notifications"; color: shell.textSecondary; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    Item { width: parent.width - 150; height: 1 }
                                    Text {
                                        text: "Clear all"; color: shell.accent; font.pixelSize: 11; font.weight: Font.Medium
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.clearNotifications() }
                                    }
                                }

                                // Notification cards from real history
                                Repeater {
                                    model: Math.min(shell.notifHistory.count, 5)

                                    Rectangle {
                                        width: ccColumn.width; height: nCol.height + 20; radius: 14; color: shell.surfaceAlt

                                        Column {
                                            id: nCol
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                            anchors.margins: 12; anchors.rightMargin: 32; spacing: 4

                                            Row {
                                                spacing: 8
                                                Rectangle {
                                                    width: 22; height: 22; radius: 11; anchors.verticalCenter: parent.verticalCenter
                                                    color: {
                                                        var palette = [shell.wpAccent, shell.wpBlue, shell.wpGreen, shell.wpPeach, shell.wpRed];
                                                        return palette[index % palette.length];
                                                    }

                                                    Image {
                                                        anchors.centerIn: parent
                                                        width: 12; height: 12
                                                        source: "../../icons/notification.png"
                                                        fillMode: Image.PreserveAspectFit
                                                        visible: {
                                                            var item = shell.notifHistory.get(index);
                                                            return item ? item.appName.toLowerCase() !== "power" : true;
                                                        }
                                                        layer.enabled: ccView.ccActive
                                                        layer.effect: MultiEffect {
                                                            brightness: -0.8
                                                            colorization: 1.0
                                                            colorizationColor: shell._baseSurface
                                                        }
                                                    }

                                                    Image {
                                                        anchors.centerIn: parent
                                                        width: 12; height: 12
                                                        source: "../../icons/power.png"
                                                        fillMode: Image.PreserveAspectFit
                                                        visible: {
                                                            var item = shell.notifHistory.get(index);
                                                            return item ? item.appName.toLowerCase() === "power" : false;
                                                        }
                                                        layer.enabled: ccView.ccActive
                                                        layer.effect: MultiEffect {
                                                            brightness: -0.8
                                                            colorization: 1.0
                                                            colorizationColor: shell._baseSurface
                                                        }
                                                    }
                                                }
                                                Text { text: shell.notifHistory.get(index).appName; color: shell.textPrimary; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            }
                                            Text { text: shell.notifHistory.get(index).summary; color: shell.textPrimary; font.pixelSize: 13; font.weight: Font.Bold; width: parent.width; elide: Text.ElideRight }
                                            Text { text: shell.notifHistory.get(index).body; color: shell.textSecondary; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
                                        }

                                        Text {
                                            anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: 12; anchors.topMargin: 12
                                            text: "×"; color: shell.textMuted; font.pixelSize: 16
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.notifHistory.remove(index) }
                                        }
                                    }
                                }
                            }
                        }


    }

    }
