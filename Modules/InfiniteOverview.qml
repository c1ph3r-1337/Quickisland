import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: overviewWindow
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    
    WlrLayershell {
        layer: WlrLayer.Overlay
        namespace: "quickisland-overview"
        keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; left: true; right: true }
    }
    
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
    
    onVisibleChanged: {
        if (visible) {
            coordsProc.running = true;
            clientsProc.running = true;
            rootItem.forceActiveFocus();
        }
    }
    
    Item {
        id: rootItem
        anchors.fill: parent
        focus: true
        
        Keys.onEscapePressed: shell.overviewActive = false
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Space) {
                shell.overviewActive = false;
            }
        }
        
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.85)
            
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
                    color: Qt.rgba(1, 1, 1, 0.1)
                }
            }
            Repeater {
                model: 11
                Rectangle {
                    x: 0
                    y: (index - 5) * overviewWindow.height * container.scaleFactor + container.height/2
                    width: container.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }
            }
            
            Repeater {
                model: overviewWindow.clientsData
                Rectangle {
                    property real cx: container.width / 2
                    property real cy: container.height / 2
                    property real sx: cx - (overviewWindow.width * container.scaleFactor) / 2
                    property real sy: cy - (overviewWindow.height * container.scaleFactor) / 2
                    
                    x: sx + (modelData.at[0] * container.scaleFactor)
                    y: sy + (modelData.at[1] * container.scaleFactor)
                    width: modelData.size[0] * container.scaleFactor
                    height: modelData.size[1] * container.scaleFactor
                    
                    color: Qt.rgba(0.39, 0.58, 1.0, 0.6)
                    border.color: Qt.rgba(1, 1, 1, 0.8)
                    border.width: 1
                    radius: 4
                    
                    Text {
                        anchors.centerIn: parent
                        text: modelData.class
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
                        color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        border.color: (gridX === 0 && gridY === 0) ? "#4caf50" : "transparent"
                        border.width: 2
                        
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 4
                            text: targetVx + "," + targetVy
                            color: Qt.rgba(1, 1, 1, 0.5)
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
