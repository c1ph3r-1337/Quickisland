import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import qs.Services.UI
import qs.Services.Keyboard
import qs.Services.Power

Item {
    id: lockScreenRoot
    property bool locked: false
    signal unlocked

    property color accentColor: "#5F9C74"
    property string timeString: ""

    // Synchronized lockscreen state across monitors
    property string currentPassword: ""
    property string islandState: "idle" // "idle", "authenticating", "error", "success"

    // References for input/animations
    property var activePwdInput: null
    property var activeShakeAnim: null

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

    readonly property string currentUser: Quickshell.env("USER") || "user"

    // Font Loaders
    FontLoader {
        id: sfProRoundedHeavy
        source: Qt.resolvedUrl("Assets/Fonts/SF-Pro-Rounded/SF-Pro-Rounded-Heavy.otf")
    }
    FontLoader {
        id: sfProRoundedBold
        source: Qt.resolvedUrl("Assets/Fonts/SF-Pro-Rounded/SF-Pro-Rounded-Bold.otf")
    }
    FontLoader {
        id: symbolFont
        source: Qt.resolvedUrl("Assets/glyph/fonts/SymbolsNerdFont.ttf")
    }

    readonly property string clockFontFamily: sfProRoundedHeavy.status === FontLoader.Ready
        ? sfProRoundedHeavy.name
        : (sfProRoundedBold.status === FontLoader.Ready ? sfProRoundedBold.name : "SF Pro Rounded")

    readonly property string symbolFontName: symbolFont.status === FontLoader.Ready ? symbolFont.name : "Symbols Nerd Font"

    // Wayland Session Lock
    WlSessionLock {
        id: lockSession
        locked: lockScreenRoot.locked

        WlSessionLockSurface {
            id: lockSurface

            Item {
                id: container
                anchors.fill: parent
                focus: true

                // Forward all keyboard events directly to password input
                Keys.forwardTo: [pwdInput]
                Keys.onPressed: (event) => {
                    if (pwdInput && !pwdInput.activeFocus) {
                        pwdInput.forceActiveFocus();
                    }
                }

                // ==========================================
                // 1. BLURRED & DARKENED WALLPAPER
                // ==========================================
                Item {
                    id: bgContainer
                    anchors.fill: parent

                    Image {
                        id: bgImage
                        anchors.fill: parent
                        source: {
                            if (typeof WallpaperService !== "undefined" && lockSurface.screen) {
                                var wp = WallpaperService.getWallpaper(lockSurface.screen.name);
                                if (wp && wp.length > 0) return "file://" + wp;
                            }
                            return Qt.resolvedUrl("Assets/glyph/images/custom_bg.png");
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true

                        Connections {
                            target: (typeof WallpaperService !== "undefined") ? WallpaperService : null
                            function onWallpaperChanged(screenName, path) {
                                if (lockSurface.screen && screenName === lockSurface.screen.name) {
                                    bgImage.source = "file://" + path;
                                }
                            }
                        }
                    }

                    MultiEffect {
                        anchors.fill: bgImage
                        source: bgImage
                        blurEnabled: true
                        blur: 0.65
                        brightness: -0.22
                        contrast: 0.08
                        visible: bgImage.status === Image.Ready
                    }

                    // Scrim overlay to ensure wallpaper is slightly darkened
                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: 0.22
                    }
                }

                // ==========================================
                // 2. CENTER CLOCK (SF Pro Rounded Heavy + High-DPI Vector Rendering)
                // ==========================================
                Item {
                    id: clockContainer
                    anchors.centerIn: parent
                    width: clockText.implicitWidth
                    height: clockText.implicitHeight
                    z: 5

                    property string timeStr: "00:00"

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: {
                            var d = new Date();
                            var h = d.getHours();
                            var m = d.getMinutes();
                            clockContainer.timeStr = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
                        }
                    }

                    // Subtle ambient shadow for depth & contrast over bright backgrounds
                    Text {
                        anchors.centerIn: parent
                        text: clockContainer.timeStr
                        color: "#000000"
                        opacity: 0.16
                        font.family: lockScreenRoot.clockFontFamily
                        font.pixelSize: Math.round(Math.min(container.width * 0.22, container.height * 0.28, 220))
                        font.bold: true
                        font.weight: Font.Black
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        antialiasing: true
                        smooth: true
                        renderType: Text.CurveRendering
                        transform: Translate { y: 2 }
                    }

                    // Luminous Foreground Clock with silky subpixel antialiasing
                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        text: clockContainer.timeStr
                        color: "#ffffff"
                        opacity: 0.84
                        font.family: lockScreenRoot.clockFontFamily
                        font.pixelSize: Math.round(Math.min(container.width * 0.22, container.height * 0.28, 220))
                        font.bold: true
                        font.weight: Font.Black
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        antialiasing: true
                        smooth: true
                        renderType: Text.CurveRendering
                    }
                }

                // ==========================================
                // 3. TOP DYNAMIC ISLAND LOCK PILL (Borderless)
                // ==========================================
                Rectangle {
                    id: topIsland
                    anchors.top: parent.top
                    anchors.topMargin: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 0
                    height: 32
                    radius: 16
                    color: "#000000"
                    border.width: 0

                    // Smooth, stabilized width expansion without bouncy jitter
                    width: {
                        if (lockScreenRoot.islandState === "authenticating") return 80;
                        if (lockScreenRoot.currentPassword.length === 0) return 72;
                        return Math.min(220, 64 + lockScreenRoot.currentPassword.length * 12);
                    }
                    Behavior on width {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    // Horizontal Shake Animation for authentication failure
                    SequentialAnimation {
                        id: errorShake
                        property int duration: 45
                        property int distance: 10
                        Component.onCompleted: {
                            lockScreenRoot.activeShakeAnim = this;
                        }

                        NumberAnimation { target: topIsland; property: "anchors.horizontalCenterOffset"; to: -errorShake.distance; duration: errorShake.duration; easing.type: Easing.OutCubic }
                        NumberAnimation { target: topIsland; property: "anchors.horizontalCenterOffset"; to: errorShake.distance; duration: errorShake.duration; easing.type: Easing.OutCubic }
                        NumberAnimation { target: topIsland; property: "anchors.horizontalCenterOffset"; to: -errorShake.distance * 0.6; duration: errorShake.duration; easing.type: Easing.OutCubic }
                        NumberAnimation { target: topIsland; property: "anchors.horizontalCenterOffset"; to: errorShake.distance * 0.6; duration: errorShake.duration; easing.type: Easing.OutCubic }
                        NumberAnimation { target: topIsland; property: "anchors.horizontalCenterOffset"; to: 0; duration: errorShake.duration; easing.type: Easing.OutCubic }
                    }

                    // 3A. Vector Lock Icon (Idle state when empty)
                    Image {
                        id: lockIcon
                        anchors.centerIn: parent
                        source: Qt.resolvedUrl("icons/island_lock.svg")
                        sourceSize.width: 16
                        sourceSize.height: 16
                        smooth: true
                        visible: opacity > 0.01
                        opacity: (lockScreenRoot.currentPassword.length === 0 && lockScreenRoot.islandState !== "authenticating") ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 130 } }
                    }

                    // 3B. Password Dots (Typing state)
                    Row {
                        id: dotsRow
                        anchors.centerIn: parent
                        spacing: 5
                        visible: opacity > 0.01
                        opacity: (lockScreenRoot.currentPassword.length > 0 && lockScreenRoot.islandState !== "authenticating") ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Repeater {
                            model: Math.min(lockScreenRoot.currentPassword.length, 16)
                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                color: lockScreenRoot.islandState === "error" ? "#f38ba8" : "#ffffff"
                                scale: 1.0

                                NumberAnimation on scale {
                                    from: 0.2
                                    to: 1.0
                                    duration: 100
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }

                    // 3C. Authenticating Pulse
                    Row {
                        id: authIndicator
                        anchors.centerIn: parent
                        spacing: 5
                        visible: lockScreenRoot.islandState === "authenticating"
                        opacity: visible ? 1.0 : 0.0

                        Repeater {
                            model: 3
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: "#fab387"

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: lockScreenRoot.islandState === "authenticating"
                                    PauseAnimation { duration: index * 180 }
                                    NumberAnimation { from: 0.3; to: 1.0; duration: 300; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 1.0; to: 0.3; duration: 300; easing.type: Easing.InOutQuad }
                                    PauseAnimation { duration: (2 - index) * 180 }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // 4. KEYBOARD INTERACTION & TEXTINPUT
                // ==========================================
                TextInput {
                    id: pwdInput
                    anchors.fill: parent
                    opacity: 0
                    focus: true
                    echoMode: TextInput.Password
                    selectByMouse: false
                    cursorVisible: false
                    enabled: lockScreenRoot.islandState !== "authenticating"

                    onTextChanged: {
                        if (text !== lockScreenRoot.currentPassword) {
                            lockScreenRoot.currentPassword = text;
                        }
                        if (lockScreenRoot.islandState === "error") {
                            lockScreenRoot.islandState = "idle";
                        }
                    }

                    onAccepted: {
                        if (lockScreenRoot.currentPassword.length > 0) {
                            lockScreenRoot.handleLogin();
                        }
                    }

                    Keys.onEscapePressed: {
                        text = "";
                        lockScreenRoot.currentPassword = "";
                        lockScreenRoot.islandState = "idle";
                    }

                    Component.onCompleted: {
                        lockScreenRoot.activePwdInput = this;
                        forceActiveFocus();
                    }
                }

                // Click anywhere on screen to refocus password input
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: {
                        if (pwdInput) pwdInput.forceActiveFocus();
                    }
                }

                // ==========================================
                // 5. POWER MENU (Bottom-Right, Clean & Minimal)
                // ==========================================
                Row {
                    id: powerMenu
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 28
                    spacing: 14
                    opacity: 0.35
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    // Suspend / Sleep Button
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: Qt.rgba(0, 0, 0, 0.6)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "󰤄"
                            font.family: lockScreenRoot.symbolFontName
                            font.pixelSize: 18
                            color: "white"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: powerMenu.opacity = 0.95
                            onExited: powerMenu.opacity = 0.35
                            onClicked: Quickshell.execDetached(["sh", "-c", "systemctl suspend || loginctl suspend"])
                        }
                    }

                    // Restart Button
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: Qt.rgba(0, 0, 0, 0.6)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            font.family: lockScreenRoot.symbolFontName
                            font.pixelSize: 18
                            color: "white"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: powerMenu.opacity = 0.95
                            onExited: powerMenu.opacity = 0.35
                            onClicked: Quickshell.execDetached(["sh", "-c", "systemctl reboot || loginctl reboot"])
                        }
                    }

                    // Power / Shutdown Button
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: Qt.rgba(0, 0, 0, 0.6)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "󰐥"
                            font.family: lockScreenRoot.symbolFontName
                            font.pixelSize: 18
                            color: "white"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: powerMenu.opacity = 0.95
                            onExited: powerMenu.opacity = 0.35
                            onClicked: Quickshell.execDetached(["sh", "-c", "systemctl poweroff || loginctl poweroff"])
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // 6. PAM AUTHENTICATION HANDLERS
    // ==========================================
    PamContext {
        id: pam
        config: lockScreenRoot.pamConfig
        user: lockScreenRoot.currentUser

        onPamMessage: {
            if (responseRequired) {
                if (lockScreenRoot.currentPassword !== "") {
                    respond(lockScreenRoot.currentPassword);
                } else {
                    respond("");
                }
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                lockScreenRoot.islandState = "success";
                lockScreenRoot.currentPassword = "";
                if (lockScreenRoot.activePwdInput) {
                    lockScreenRoot.activePwdInput.text = "";
                }
                unlockTimer.start();
            } else {
                lockScreenRoot.islandState = "error";
                if (lockScreenRoot.activeShakeAnim) {
                    lockScreenRoot.activeShakeAnim.start();
                }
                if (lockScreenRoot.activePwdInput) {
                    lockScreenRoot.activePwdInput.text = "";
                    lockScreenRoot.activePwdInput.forceActiveFocus();
                }
                lockScreenRoot.currentPassword = "";
                resetErrorTimer.start();
            }
        }
    }

    Timer {
        id: unlockTimer
        interval: 220
        onTriggered: {
            lockScreenRoot.unlocked();
        }
    }

    Timer {
        id: resetErrorTimer
        interval: 850
        onTriggered: {
            if (lockScreenRoot.islandState === "error") {
                lockScreenRoot.islandState = "idle";
            }
        }
    }

    function handleLogin() {
        if (lockScreenRoot.currentPassword === "" || lockScreenRoot.islandState === "authenticating") {
            if (lockScreenRoot.activeShakeAnim) lockScreenRoot.activeShakeAnim.start();
            return;
        }

        lockScreenRoot.islandState = "authenticating";
        pam.start();
    }

    // When lock state changes
    onLockedChanged: {
        if (locked) {
            lockScreenRoot.currentPassword = "";
            lockScreenRoot.islandState = "idle";
            if (lockScreenRoot.activePwdInput) {
                lockScreenRoot.activePwdInput.text = "";
                lockScreenRoot.activePwdInput.forceActiveFocus();
            }
        }
    }
}
