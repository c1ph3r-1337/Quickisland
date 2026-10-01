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

Item {
    id: lockScreenRoot
    property bool locked: false
    signal unlocked

    property color accentColor: "#5F9C74"
    property string timeString: ""

    // References to UI components inside the WlSessionLock nested context
    property var pwdInputRef: null
    property var errorShakeRef: null
    property var containerRef: null

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

    // Read hostname
    FileView {
        id: hostnameFile
        path: "/etc/hostname"
    }

    readonly property string currentHostName: {
        var txt = "";
        try {
            if (typeof hostnameFile.text === "function") {
                txt = hostnameFile.text().trim();
            } else if (typeof hostnameFile.text === "string") {
                txt = hostnameFile.text.trim();
            }
        } catch (e) {}
        if (txt.length > 0) return txt;
        var envHost = Quickshell.env("HOSTNAME");
        if (envHost && envHost.trim().length > 0) return envHost.trim();
        return "archlinux";
    }

    readonly property string currentUser: Quickshell.env("USER") || "user"
    readonly property string currentDesktop: (Quickshell.env("XDG_CURRENT_DESKTOP") || "HYPRLAND").toUpperCase()

    // Fonts from Glyph SDDM theme
    FontLoader {
        id: ndotFont
        source: Qt.resolvedUrl("Assets/glyph/fonts/Ndot-57-Aligned.ttf")
    }
    FontLoader {
        id: symbolFont
        source: Qt.resolvedUrl("Assets/glyph/fonts/SymbolsNerdFont.ttf")
    }

    readonly property string globalFont: ndotFont.status === FontLoader.Ready ? ndotFont.name : "monospace"
    readonly property string symbolFontName: symbolFont.status === FontLoader.Ready ? symbolFont.name : "JetBrainsMono Nerd Font"

    function getOSLogo(name) {
        var n = name.toLowerCase();
        if (n.includes("arch")) return "󰣇";
        if (n.includes("ubuntu")) return "󰕈";
        if (n.includes("fedora")) return "󰣛";
        if (n.includes("debian")) return "󰣚";
        if (n.includes("manjaro")) return "󱘊";
        if (n.includes("mint")) return "󰣭";
        if (n.includes("kali")) return "󴑗";
        if (n.includes("pop")) return "󰣏";
        if (n.includes("nix")) return "󱄅";
        if (n.includes("gentoo")) return "󰣨";
        if (n.includes("suse")) return "󰣫";
        if (n.includes("void")) return "󰣦";
        if (n.includes("artix")) return "󰣆";
        if (n.includes("alpine")) return "󰣪";
        if (n.includes("cent")) return "󰣑";
        if (n.includes("garuda")) return "󱄊";
        if (n.includes("endeavour")) return "󰣚";
        return "󰣇";
    }

    WlSessionLock {
        id: lockSession
        locked: lockScreenRoot.locked

        WlSessionLockSurface {
            id: lockSurface

            // Main Container (mirrors SDDM glyph Main.qml)
            Rectangle {
                id: container
                anchors.fill: parent
                color: "black"
                focus: true

                // State Management
                property bool isUnlocked: false
                property color finalClockColor: "#ffffff"
                property bool readyToReveal: true
                property bool isLoggingIn: false
                property string statusMessage: ""
                property color statusColor: Qt.rgba(1, 1, 1, 0.45)

                property string timeStr: "00:00"

                Component.onCompleted: {
                    lockScreenRoot.containerRef = this;
                }

                // Clock update timer
                Timer {
                    id: clockTimer
                    interval: 1000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: {
                        var date = new Date();
                        var hours = date.getHours();
                        var minutes = date.getMinutes();

                        // 12-hour format default to match SDDM glyph theme.conf
                        hours = hours % 12;
                        if (hours === 0) hours = 12;
                        var hStr = hours < 10 ? "0" + hours : "" + hours;
                        var mStr = minutes < 10 ? "0" + minutes : "" + minutes;
                        container.timeStr = hStr + ":" + mStr;
                    }
                }

                // Background Image
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
                    onStatusChanged: {
                        if (status === Image.Ready) brightnessTimer.start();
                    }

                    Connections {
                        target: (typeof WallpaperService !== "undefined") ? WallpaperService : null
                        function onWallpaperChanged(screenName, path) {
                            if (lockSurface.screen && screenName === lockSurface.screen.name) {
                                bgImage.source = "file://" + path;
                            }
                        }
                    }
                }

                // Frosted Glass Blur when unlocked
                MultiEffect {
                    anchors.fill: bgImage
                    source: bgImage
                    blurEnabled: true
                    blur: container.isUnlocked ? 0.75 : 0.0
                    brightness: container.isUnlocked ? -0.28 : 0.0
                    contrast: 0.05
                    visible: bgImage.status === Image.Ready
                    Behavior on blur { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on brightness { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }

                // Dynamic luminance detection from SDDM glyph theme
                Timer {
                    id: brightnessTimer
                    interval: 50
                    onTriggered: brightnessCanvas.requestPaint()
                }

                Canvas {
                    id: brightnessCanvas
                    width: 20
                    height: 20
                    visible: false
                    renderTarget: Canvas.Image
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.drawImage(bgImage, 0, 0, width, height);
                        var data = ctx.getImageData(0, 0, width, height).data;
                        var r = 0, g = 0, b = 0;
                        for (var i = 0; i < data.length; i += 4) {
                            r += data[i];
                            g += data[i+1];
                            b += data[i+2];
                        }
                        var luminance = (0.299 * (r / (data.length / 4)) + 0.587 * (g / (data.length / 4)) + 0.114 * (b / (data.length / 4))) / 255;
                        container.finalClockColor = (luminance > 0.5) ? "#000000" : "#ffffff";
                        revealTimer.start();
                    }
                }

                Timer {
                    id: revealTimer
                    interval: 50
                    onTriggered: container.readyToReveal = true
                }

                // Dimming Overlay (matches SDDM glyph)
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: container.isUnlocked ? 0.45 : 0.15
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }

                // Click background to reveal login card
                MouseArea {
                    anchors.fill: parent
                    enabled: !container.isUnlocked
                    onClicked: {
                        container.isUnlocked = true;
                        focusTimer.start();
                    }
                }

                // Keypress anywhere to reveal login card and type password
                Keys.onPressed: (event) => {
                    if (!container.isUnlocked) {
                        container.isUnlocked = true;
                        if (event.text && event.text.length > 0 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
                            if (lockScreenRoot.pwdInputRef) {
                                lockScreenRoot.pwdInputRef.text += event.text;
                            }
                        }
                        event.accepted = true;
                        focusTimer.start();
                    }
                }

                Keys.onEscapePressed: (event) => {
                    if (container.isUnlocked) {
                        container.isUnlocked = false;
                        if (lockScreenRoot.pwdInputRef) {
                            lockScreenRoot.pwdInputRef.text = "";
                        }
                        container.statusMessage = "";
                        container.isLoggingIn = false;
                        container.focus = true;
                        event.accepted = true;
                    }
                }

                Timer {
                    id: focusTimer
                    interval: 100
                    onTriggered: {
                        if (lockScreenRoot.pwdInputRef) {
                            lockScreenRoot.pwdInputRef.forceActiveFocus();
                        }
                    }
                }

                // ==========================================
                // 1. THE GLYPH CLOCK (Top-Left, 80px margin)
                // ==========================================
                Item {
                    id: glyphClock
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 80
                    width: 600
                    height: 300

                    visible: container.readyToReveal
                    opacity: visible ? (container.isUnlocked ? 0.4 : 1.0) : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        spacing: 0

                        // Big Dot-Matrix Digits
                        Row {
                            spacing: 0
                            Repeater {
                                model: container.timeStr.length
                                Item {
                                    width: {
                                        var c = container.timeStr.charAt(index);
                                        if (c === "1") return 65;
                                        if (c === ":") return 35;
                                        return 95;
                                    }
                                    height: 150
                                    Text {
                                        anchors.centerIn: parent
                                        text: container.timeStr.charAt(index)
                                        font.family: lockScreenRoot.globalFont
                                        font.pixelSize: 150
                                        color: container.finalClockColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }

                        // Date & Hostname Subtitle
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 5
                            spacing: 0

                            Text {
                                text: Qt.formatDate(new Date(), "ddd, d MMM").toUpperCase()
                                font.family: lockScreenRoot.globalFont
                                font.pixelSize: 32
                                color: container.finalClockColor
                                opacity: 0.9
                                topPadding: -10
                            }

                            Row {
                                spacing: 12
                                topPadding: 10

                                Text {
                                    text: lockScreenRoot.getOSLogo("arch") + "  " + lockScreenRoot.currentHostName.toUpperCase()
                                    font.family: lockScreenRoot.globalFont
                                    font.pixelSize: 22
                                    color: container.finalClockColor
                                    opacity: 0.8
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // 2. THE OBSIDIAN LOGIN PANEL (Centered)
                // ==========================================
                Item {
                    id: loginPanelContainer
                    anchors.centerIn: parent
                    width: 400
                    height: 400

                    opacity: container.isUnlocked ? 1.0 : 0.0
                    visible: opacity > 0
                    scale: container.isUnlocked ? 1.0 : 0.95

                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                    onVisibleChanged: {
                        if (visible) {
                            focusTimer.start();
                        } else {
                            if (lockScreenRoot.pwdInputRef) lockScreenRoot.pwdInputRef.text = "";
                            container.isLoggingIn = false;
                            container.statusMessage = "";
                            if (lockScreenRoot.errorShakeRef) lockScreenRoot.errorShakeRef.stop();
                            card.x = (loginPanelContainer.width - card.width) / 2;
                        }
                    }

                    Rectangle {
                        id: card
                        width: 340
                        height: 300
                        x: (parent.width - width) / 2
                        y: (parent.height - height) / 2
                        color: Qt.rgba(0, 0, 0, 0.55)
                        radius: 32
                        border.width: 0
                        antialiasing: true

                        SequentialAnimation {
                            id: errorShake
                            property int duration: 40
                            property int distance: 8
                            Component.onCompleted: lockScreenRoot.errorShakeRef = this

                            NumberAnimation { target: card; property: "x"; to: ((card.parent.width - card.width) / 2) - errorShake.distance; duration: errorShake.duration; easing.type: Easing.OutCubic }
                            NumberAnimation { target: card; property: "x"; to: ((card.parent.width - card.width) / 2) + errorShake.distance; duration: errorShake.duration; easing.type: Easing.OutCubic }
                            NumberAnimation { target: card; property: "x"; to: ((card.parent.width - card.width) / 2) - errorShake.distance; duration: errorShake.duration; easing.type: Easing.OutCubic }
                            NumberAnimation { target: card; property: "x"; to: ((card.parent.width - card.width) / 2) + errorShake.distance; duration: errorShake.duration; easing.type: Easing.OutCubic }
                            NumberAnimation { target: card; property: "x"; to: (card.parent.width - card.width) / 2; duration: errorShake.duration; easing.type: Easing.OutCubic }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 18

                            // User Profile Row (Avatar + Username)
                            Item {
                                Layout.preferredWidth: 280
                                Layout.preferredHeight: 64
                                Layout.alignment: Qt.AlignHCenter

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 15

                                    Rectangle {
                                        width: 54
                                        height: 54
                                        radius: 27
                                        color: Qt.rgba(255, 255, 255, 0.08)
                                        border.width: 0
                                        antialiasing: true

                                        // Fallback user initial
                                        Text {
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: 2
                                            text: lockScreenRoot.currentUser.charAt(0).toUpperCase()
                                            color: "white"
                                            font.pixelSize: 26
                                            font.family: lockScreenRoot.globalFont
                                        }

                                        // Universal Circle Avatar
                                        Canvas {
                                            id: avatarCanvas
                                            anchors.fill: parent
                                            visible: avatarImage.status === Image.Ready

                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.reset();
                                                ctx.beginPath();
                                                ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI);
                                                ctx.closePath();
                                                ctx.clip();
                                                ctx.drawImage(avatarImage, 0, 0, width, height);
                                            }

                                            Image {
                                                id: avatarImage
                                                source: Qt.resolvedUrl("Assets/glyph/images/avatar.jpg")
                                                visible: false
                                                onStatusChanged: {
                                                    if (status === Image.Ready) avatarCanvas.requestPaint();
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: lockScreenRoot.currentUser.toUpperCase()
                                        color: "white"
                                        font.pixelSize: 20
                                        font.family: lockScreenRoot.globalFont
                                    }
                                }
                            }

                            // Password Input Field
                            Item {
                                Layout.preferredWidth: 280
                                Layout.preferredHeight: 50
                                Layout.alignment: Qt.AlignHCenter

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
                                    echoMode: TextInput.Password
                                    color: "white"
                                    font.pixelSize: 18
                                    font.family: lockScreenRoot.globalFont
                                    horizontalAlignment: TextInput.AlignHCenter
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectionColor: lockScreenRoot.accentColor
                                    selectByMouse: true
                                    enabled: !container.isLoggingIn
                                    focus: container.isUnlocked

                                    onAccepted: lockScreenRoot.handleLogin()

                                    Keys.onEscapePressed: (event) => {
                                        container.isUnlocked = false;
                                        pwdInput.text = "";
                                        container.statusMessage = "";
                                        container.isLoggingIn = false;
                                        container.focus = true;
                                        event.accepted = true;
                                    }

                                    Component.onCompleted: {
                                        lockScreenRoot.pwdInputRef = this;
                                    }
                                }

                                Text {
                                    text: "ENTER PASSWORD"
                                    font.family: lockScreenRoot.globalFont
                                    font.pixelSize: 16
                                    color: Qt.rgba(255, 255, 255, 0.5)
                                    anchors.centerIn: parent
                                    visible: pwdInput.text === "" && !pwdInput.activeFocus
                                    z: 5
                                }
                            }

                            // Session Pill & Arrow Submit Button
                            RowLayout {
                                Layout.preferredWidth: 280
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 15

                                // Session pill
                                Rectangle {
                                    Layout.preferredWidth: 180
                                    Layout.preferredHeight: 40
                                    color: Qt.rgba(255, 255, 255, 0.05)
                                    radius: 20
                                    border.width: 0
                                    antialiasing: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: lockScreenRoot.currentDesktop
                                        font.family: lockScreenRoot.globalFont
                                        font.pixelSize: 12
                                        color: "white"
                                        opacity: 0.7
                                    }
                                }

                                // Arrow Submit Button
                                Rectangle {
                                    id: loginBtn
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 25
                                    color: container.isLoggingIn ? Qt.rgba(255, 255, 255, 0.1) : lockScreenRoot.accentColor
                                    scale: loginBtnMouse.pressed ? 0.9 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }

                                    Item {
                                        anchors.fill: parent

                                        Text {
                                            anchors.centerIn: parent
                                            text: "⋯"
                                            color: "white"
                                            font.pixelSize: 28
                                            visible: container.isLoggingIn
                                        }

                                        Image {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: 2.5
                                            source: Qt.resolvedUrl("Assets/glyph/images/login_arrow_trimmed.png")
                                            width: 20
                                            height: 20
                                            fillMode: Image.PreserveAspectFit
                                            visible: !container.isLoggingIn
                                            antialiasing: true
                                        }
                                    }

                                    MouseArea {
                                        id: loginBtnMouse
                                        anchors.fill: parent
                                        enabled: !container.isLoggingIn
                                        onClicked: lockScreenRoot.handleLogin()
                                    }
                                }
                            }

                            // Status / Feedback message
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: container.statusMessage
                                color: container.statusColor
                                font.pixelSize: 12
                                font.family: lockScreenRoot.globalFont
                                visible: container.statusMessage !== ""
                            }
                        }

                        // Num Lock Indicator
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "NUM LOCK IS ON"
                            font.family: lockScreenRoot.globalFont
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            color: lockScreenRoot.accentColor
                            opacity: 0.8
                            visible: typeof LockKeysService !== "undefined" && LockKeysService.numLockOn
                        }
                    }
                }

                // ==========================================
                // 3. THE GLYPH POWER MENU (Bottom-Right, 50px margins)
                // ==========================================
                Item {
                    id: powerMenu
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 50
                    width: 250
                    height: 80

                    opacity: container.isUnlocked ? 0.5 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }

                    RowLayout {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: 20

                        // Suspend / Sleep Button
                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: 24
                            color: Qt.rgba(0, 0, 0, 0.7)
                            border.width: 0
                            antialiasing: true
                            scale: sleepMouse.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰤄"
                                font.family: lockScreenRoot.symbolFontName
                                font.pixelSize: 20
                                color: "white"
                            }

                            MouseArea {
                                id: sleepMouse
                                anchors.fill: parent
                                onClicked: Quickshell.execDetached(["sh", "-c", "systemctl suspend || loginctl suspend"])
                            }
                        }

                        // Restart Button
                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: 24
                            color: Qt.rgba(0, 0, 0, 0.7)
                            border.width: 0
                            antialiasing: true
                            scale: restartMouse.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰑐"
                                font.family: lockScreenRoot.symbolFontName
                                font.pixelSize: 20
                                color: "white"
                            }

                            MouseArea {
                                id: restartMouse
                                anchors.fill: parent
                                onClicked: Quickshell.execDetached(["sh", "-c", "systemctl reboot || loginctl reboot"])
                            }
                        }

                        // Power / Shutdown Button (Nothing Red)
                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 60
                            radius: 30
                            color: "#D71921"
                            border.width: 0
                            antialiasing: true
                            scale: powerMouse.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰐥"
                                font.family: lockScreenRoot.symbolFontName
                                font.pixelSize: 24
                                color: "white"
                            }

                            MouseArea {
                                id: powerMouse
                                anchors.fill: parent
                                onClicked: Quickshell.execDetached(["sh", "-c", "systemctl poweroff || loginctl poweroff"])
                            }
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // 4. PAM AUTHENTICATION HANDLERS
    // ==========================================
    PamContext {
        id: pam
        config: lockScreenRoot.pamConfig
        user: lockScreenRoot.currentUser

        onPamMessage: {
            if (responseRequired) {
                var inputField = lockScreenRoot.pwdInputRef;
                if (inputField && inputField.text !== "") {
                    respond(inputField.text);
                }
            }
        }

        onCompleted: result => {
            var inputField = lockScreenRoot.pwdInputRef;
            var shake = lockScreenRoot.errorShakeRef;
            var cont = lockScreenRoot.containerRef;

            if (result === PamResult.Success) {
                if (cont) {
                    cont.statusMessage = "AUTHENTICATED";
                    cont.statusColor = "#a6e3a1";
                    cont.isLoggingIn = false;
                }
                if (inputField) {
                    inputField.text = "";
                }
                lockScreenRoot.unlocked();
            } else {
                if (cont) {
                    cont.statusMessage = "INCORRECT PASSWORD";
                    cont.statusColor = "#f38ba8";
                    cont.isLoggingIn = false;
                }
                if (shake) {
                    shake.start();
                }
                if (inputField) {
                    inputField.text = "";
                    inputField.forceActiveFocus();
                }
            }
        }
    }

    function handleLogin() {
        var inputField = lockScreenRoot.pwdInputRef;
        var cont = lockScreenRoot.containerRef;
        var shake = lockScreenRoot.errorShakeRef;

        if (!inputField || inputField.text === "" || (cont && cont.isLoggingIn)) {
            if (shake) shake.start();
            return;
        }

        if (cont) {
            cont.isLoggingIn = true;
            cont.statusMessage = "AUTHENTICATING...";
            cont.statusColor = "#fab387";
        }
        pam.start();
    }

    // When lock state changes
    onLockedChanged: {
        if (locked) {
            var cont = lockScreenRoot.containerRef;
            if (cont) {
                cont.isUnlocked = false;
                cont.isLoggingIn = false;
                cont.statusMessage = "";
                cont.focus = true;
            }
            var input = lockScreenRoot.pwdInputRef;
            if (input) {
                input.text = "";
            }
        }
    }
}
