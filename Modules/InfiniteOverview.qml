import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: overviewWindow
    property var modelData
    screen: modelData
    color: "transparent"
    
    Region { id: clickThroughRegion }
    mask: shell.overviewActive ? null : clickThroughRegion
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickisland-overview"
    WlrLayershell.keyboardFocus: shell.overviewActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    
    anchors { top: true; bottom: true; left: true; right: true }
    
    property int currentVx: 0
    property int currentVy: 0
    property var clientsData: []
    
    Process {
        id: clientsProc
        command: ["bash", "-c", "hyprctl clients -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    overviewWindow.clientsData = JSON.parse(text);
                } catch(e) {}
            }
        }
    }
    
    Process {
        id: coordsProc
        command: ["bash", "-c", "cat ~/.cache/quickisland/infinite_canvas_coords 2>/dev/null || echo '0 0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(" ");
                if (parts.length >= 2) {
                    overviewWindow.currentVx = parseInt(parts[0]);
                    overviewWindow.currentVy = parseInt(parts[1]);
                }
            }
        }
    }
    
    Connections {
        target: shell
        function onOverviewActiveChanged() {
            if (shell.overviewActive) {
                coordsProc.running = true;
                clientsProc.running = true;
                rootItem.forceActiveFocus();
            } else {
                rootItem.focus = false;
            }
        }
    }
    
    Item {
        id: rootItem
        anchors.fill: parent
        focus: shell.overviewActive
        visible: shell.overviewActive
        opacity: shell.overviewActive ? 1.0 : 0.0
        
        Behavior on opacity { NumberAnimation { duration: 150 } }
        
        Keys.onEscapePressed: shell.overviewActive = false
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Space) {
                shell.overviewActive = false;
            }
        }
        
        Rectangle {
            anchors.fill: parent
            color: "#D9000000"
            
            MouseArea {
                anchors.fill: parent
                onClicked: shell.overviewActive = false
            }
        }
        
        Item {
            id: container
            anchors.centerIn: parent
            width: overviewWindow.width * 0.8
            height: overviewWindow.height * 0.8
            
            property real scaleFactor: (container.width / 5) / overviewWindow.width
            
            Repeater {
                model: 11
                Rectangle {
                    x: (index - 5) * overviewWindow.width * container.scaleFactor + container.width/2
                    y: 0
                    width: 1
                    height: container.height
                    color: "#1AFFFFFF"
                }
            }
            Repeater {
                model: 11
                Rectangle {
                    x: 0
                    y: (index - 5) * overviewWindow.height * container.scaleFactor + container.height/2
                    width: container.width
                    height: 1
                    color: "#1AFFFFFF"
                }
            }
            
            Repeater {
                model: overviewWindow.clientsData
                delegate: Rectangle {
                    property var client: modelData
                    property real cx: container.width / 2
                    property real cy: container.height / 2
                    property real sx: cx - (overviewWindow.width * container.scaleFactor) / 2
                    property real sy: cy - (overviewWindow.height * container.scaleFactor) / 2
                    
                    x: sx + (client.at[0] * container.scaleFactor)
                    y: sy + (client.at[1] * container.scaleFactor)
                    width: client.size[0] * container.scaleFactor
                    height: client.size[1] * container.scaleFactor
                    
                    color: "#996496FF"
                    border.color: "#CCFFFFFF"
                    border.width: 1
                    radius: 4
                    
                    Text {
                        anchors.centerIn: parent
                        text: client.class
                        color: "white"
                        font.pixelSize: 10
                        width: parent.width - 4
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        clip: true
                    }
                }
            }
            
            Repeater {
                model: 25
                Item {
                    property int gridX: (index % 5) - 2
                    property int gridY: Math.floor(index / 5) - 2
                    property int targetVx: overviewWindow.currentVx + gridX
                    property int targetVy: overviewWindow.currentVy - gridY
                    property real sx: container.width/2 - (overviewWindow.width * container.scaleFactor)/2
                    property real sy: container.height/2 - (overviewWindow.height * container.scaleFactor)/2
                    
                    x: sx + (gridX * overviewWindow.width * container.scaleFactor)
                    y: sy + (gridY * overviewWindow.height * container.scaleFactor)
                    width: overviewWindow.width * container.scaleFactor
                    height: overviewWindow.height * container.scaleFactor
                    
                    Rectangle {
                        anchors.fill: parent
                        color: ma.containsMouse ? "#1AFFFFFF" : "transparent"
                        border.color: (gridX === 0 && gridY === 0) ? "#4caf50" : "transparent"
                        border.width: 2
                        
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 4
                            text: targetVx + "," + targetVy
                            color: "#4DFFFFFF"
                            font.pixelSize: 10
                        }
                    }
                    
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            shell.overviewActive = false;
                            jumpProc.targetVx = targetVx;
                            jumpProc.targetVy = targetVy;
                            jumpProc.running = true;
                        }
                    }
                }
            }
        }
    }
    
    Process {
        id: jumpProc
        property int targetVx: 0
        property int targetVy: 0
        command: ["bash", "-c", "~/.config/quickshell/quickisland/scripts/infinite_canvas.sh jump " + targetVx + " " + targetVy]
    }
}
