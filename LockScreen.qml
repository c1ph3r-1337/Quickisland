import QtQuick
import QtQuick.Controls
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
                Column {
                    anchors.centerIn: parent
                    spacing: 48
                    width: 320

                    // Sleek Digital Clock
                    Column {
                        spacing: 8
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            text: lockScreenRoot.timeString || ""
                            color: "#ffffff"
                            font.pixelSize: 96
                            font.weight: Font.Thin
                            font.letterSpacing: -2
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: {
                                var d = new Date();
                                var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
                                var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
                                return days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate();
                            }
                            color: Qt.rgba(1, 1, 1, 0.65)
                            font.pixelSize: 15
                            font.weight: Font.Light
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // Spacer/gap
                    Item {
                        width: 1; height: 16
                    }

                    // User & Password Input Area
                    Column {
                        spacing: 16
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter

                        // User welcome message
                        Text {
                            text: "Welcome back, " + Quickshell.env("USER")
                            color: Qt.rgba(1, 1, 1, 0.85)
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        // Password Input Field Container (sleek capsule/pill shape)
                        Rectangle {
                            width: 260; height: 40; radius: 20
                            color: Qt.rgba(0, 0, 0, 0.35)
                            border.width: 1
                            border.color: pwdInput.activeFocus ? (lockScreenRoot.accentColor || "#ffffff") : Qt.rgba(1, 1, 1, 0.15)
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            anchors.horizontalCenter: parent.horizontalCenter

                            TextInput {
                                id: pwdInput
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 18
                                verticalAlignment: Text.AlignVCenter
                                color: "#ffffff"
                                font.pixelSize: 14
                                echoMode: TextInput.Password
                                focus: lockScreenRoot.locked
                                selectByMouse: true

                                property string placeholderText: "Enter Password"
                                Text {
                                    text: parent.placeholderText
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                    font.pixelSize: 14
                                    visible: !parent.text && !parent.activeFocus
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
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
                                             // Force focus in next event loops to bypass Wayland mapping delay
                                             Qt.callLater(() => {
                                                 if (pwdInput) pwdInput.forceActiveFocus();
                                             });
                                         }
                                     });
                                 }
                            }
                        }

                        // Feedback/status text
                        Text {
                            id: statusLabel
                            text: "Press Enter to Unlock"
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
