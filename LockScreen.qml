import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import qs.Services.UI

Item {
    id: lockScreenRoot
    property bool locked: false
    signal unlocked
    
    property color accentColor: "#cba6f7"
    property string timeString: ""

    // References to UI components inside the WlSessionLock nested context
    property var statusLabelRef: null
    property var pwdInputRef: null

    // Detect PAM service (Arch/Fedora/Ubuntu support)
    property string pamConfig: "login"
    property bool pamReady: false

    Process {
        id: detectPamServiceProc
        command: ["sh", "-c", "
            if [ -f /etc/pam.d/login ]; then echo 'login'; exit 0; fi;
            if [ -f /etc/pam.d/system-auth ]; then echo 'system-auth'; exit 0; fi;
            if [ -f /etc/pam.d/common-auth ]; then echo 'common-auth'; exit 0; fi;
            echo 'login';
        "]
        stdout: StdioCollector {
            onStreamFinished: {
                var service = String(text || "").trim();
                if (service.length > 0) {
                    lockScreenRoot.pamConfig = service;
                }
                lockScreenRoot.pamReady = true;
            }
        }
        Component.onCompleted: running = true
    }

    WlSessionLock {
        id: lockSession
        locked: lockScreenRoot.locked

        WlSessionLockSurface {
            id: lockSurface

            // Lock screen contents
            Item {
                anchors.fill: parent

                // MouseArea safety guard to capture focus immediately on click or hover
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onEntered: {
                        if (lockScreenRoot.locked && !pwdInput.activeFocus) {
                            pwdInput.forceActiveFocus();
                        }
                    }
                    onClicked: {
                        pwdInput.forceActiveFocus();
                    }
                }

                // 1. Frosted Glass Blurred Background (matching current screen wallpaper)
                Image {
                    id: bgImage
                    anchors.fill: parent
                    source: (typeof WallpaperService !== "undefined" && lockSurface.screen) ? "file://" + WallpaperService.getWallpaper(lockSurface.screen.name) : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: source.toString() !== ""

                    Connections {
                        target: (typeof WallpaperService !== "undefined") ? WallpaperService : null
                        function onWallpaperChanged(screenName, path) {
                            if (lockSurface.screen && screenName === lockSurface.screen.name) {
                                bgImage.source = "file://" + path;
                            }
                        }
                    }
                }

                // Fallback background color if wallpaper service isn't active
                Rectangle {
                    anchors.fill: parent
                    color: "#0b0813"
                    visible: bgImage.source.toString() === ""
                }

                MultiEffect {
                    anchors.fill: bgImage
                    source: bgImage
                    blurEnabled: true
                    blur: 0.75
                    brightness: -0.28
                    contrast: 0.05
                    visible: bgImage.visible
                }

                // 2. Minimal, Aesthetic Centered Column
                // 2. Glyph Theme Centered Column
                Column {
                    anchors.centerIn: parent
                    spacing: 20
                    width: 320

                    // Sleek Digital Clock
                    Text {
                        text: lockScreenRoot.timeString || ""
                        color: "#ffffff"
                        font.pixelSize: 84
                        font.weight: Font.DemiBold
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Item { width: 1; height: 30 }

                    // Avatar Canvas
                    Item {
                        width: 100; height: 100
                        anchors.horizontalCenter: parent.horizontalCenter
                        Canvas {
                            anchors.fill: parent
                            visible: avatarImage.status === Image.Ready
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.beginPath();
                                ctx.arc(width/2, height/2, width/2, 0, 2 * Math.PI);
                                ctx.closePath();
                                ctx.clip();
                                ctx.drawImage(avatarImage, 0, 0, width, height);
                            }
                            Image {
                                id: avatarImage
                                source: "file:///usr/share/sddm/themes/glyph/assets/images/avatar.jpg"
                                visible: false
                                onStatusChanged: if (status === Image.Ready) parent.requestPaint()
                            }
                        }
                    }

                    // Username
                    Text {
                        text: Quickshell.env("USER").toUpperCase()
                        color: "#ffffff"
                        font.pixelSize: 20
                        font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Item { width: 1; height: 10 }

                    // Password Row
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10
                        
                        Item {
                            width: 280; height: 50
                            
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(255, 255, 255, 0.05)
                                radius: 14
                                border.width: 0
                                antialiasing: true
                            }
                            
                            TextInput {
                                id: pwdInput
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: "#ffffff"
                                font.pixelSize: 18
                                echoMode: TextInput.Password
                                focus: lockScreenRoot.locked
                                selectByMouse: true

                                Text {
                                    text: "ENTER PASSWORD"
                                    color: Qt.rgba(255, 255, 255, 0.5)
                                    font.pixelSize: 16
                                    visible: !parent.text && !parent.activeFocus
                                    anchors.centerIn: parent
                                }

                                Keys.onReturnPressed: {
                                    if (text !== "") {
                                        lockScreenRoot.tryUnlock(text);
                                    }
                                }
                                
                                Component.onCompleted: {
                                     var root = lockScreenRoot;
                                     root.pwdInputRef = this;
                                     root.lockedChanged.connect(function() {
                                         if (root.locked && pwdInput) {
                                             pwdInput.text = "";
                                             pwdInput.forceActiveFocus();
                                             Qt.callLater(() => {
                                                 if (pwdInput) pwdInput.forceActiveFocus();
                                             });
                                         }
                                     });
                                }
                            }
                        }
                        
                        // Arrow Button
                        Rectangle {
                            width: 50; height: 50
                            radius: 25
                            color: "#5F9C74"
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (pwdInput.text !== "") lockScreenRoot.tryUnlock(pwdInput.text);
                                }
                            }
                            Image {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: 2.5
                                source: "file:///usr/share/sddm/themes/glyph/assets/images/login_arrow_trimmed.png"
                                width: 20
                                height: 20
                                fillMode: Image.PreserveAspectFit
                                antialiasing: true
                            }
                        }
                    }

                    // Feedback/status text
                    Text {
                        id: statusLabel
                        text: ""
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                        Component.onCompleted: lockScreenRoot.statusLabelRef = this
                    }
                    }
                }
            }
        }

    // PAM Authentication Context
    PamContext {
        id: pam
        config: lockScreenRoot.pamConfig
        user: Quickshell.env("USER")

        onPamMessage: {
            if (responseRequired) {
                var inputField = lockScreenRoot.pwdInputRef;
                if (inputField && inputField.text !== "") {
                    respond(inputField.text);
                }
            }
        }

        onCompleted: result => {
            var label = lockScreenRoot.statusLabelRef;
            var inputField = lockScreenRoot.pwdInputRef;
            if (result === PamResult.Success) {
                if (label) {
                    label.text = "Success!";
                    label.color = "#a6e3a1";
                }
                if (inputField) {
                    inputField.text = "";
                }
                lockScreenRoot.unlocked();
            } else {
                if (label) {
                    label.text = "Incorrect password. Try again.";
                    label.color = "#f38ba8";
                }
                if (inputField) {
                    inputField.text = "";
                    inputField.forceActiveFocus();
                }
            }
        }
    }

    // Capture the root reference in Component.onCompleted callback to avoid global QML connect issues
    Component.onCompleted: {
        var root = lockScreenRoot;
        root.lockedChanged.connect(function() {
            if (root.locked) {
                var input = root.pwdInputRef;
                if (input) {
                    input.text = "";
                    input.forceActiveFocus();
                    Qt.callLater(() => {
                        if (input) input.forceActiveFocus();
                    });
                }
                var label = root.statusLabelRef;
                if (label) {
                    label.text = "Press Enter to Unlock";
                    label.color = Qt.rgba(1, 1, 1, 0.45);
                }
            }
        });
    }

    function tryUnlock(password) {
        var label = lockScreenRoot.statusLabelRef;
        if (label) {
            label.text = "Authenticating...";
            label.color = "#fab387";
        }
        pam.start();
    }
}
