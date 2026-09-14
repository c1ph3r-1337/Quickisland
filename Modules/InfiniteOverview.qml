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
    
    property var layoutData: null
    property bool isEntering: false
    property bool jumpPending: false
    
    // Read the layout JSON produced by overview_zoom.sh
    Process {
        id: layoutProc
        command: ["bash", "-c", "cat ~/.cache/quickisland/overview_layout.json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    overviewWindow.layoutData = JSON.parse(text);
                } catch(e) {
                    overviewWindow.layoutData = null;
                }
            }
        }
    }
    
    // Enter overview: physically zoom out all windows
    Process {
        id: enterProc
        command: ["bash", "-c", "~/.config/quickshell/quickisland/scripts/overview_zoom.sh enter"]
        stdout: StdioCollector {
            onStreamFinished: {
                // After windows are zoomed out, read the layout
                layoutProc.running = true;
                overviewWindow.isEntering = false;
            }
        }
    }
    
    // Exit overview: restore windows
    Process {
        id: exitProc
        command: ["bash", "-c", "~/.config/quickshell/quickisland/scripts/overview_zoom.sh exit"]
    }
    
    // Jump to a workspace
    Process {
        id: jumpProc
        property int targetVx: 0
        property int targetVy: 0
        command: ["bash", "-c", "~/.config/quickshell/quickisland/scripts/overview_zoom.sh jump " + targetVx + " " + targetVy]
    }
    
    Connections {
        target: shell
        function onOverviewActiveChanged() {
            if (shell.overviewActive) {
                overviewWindow.isEntering = true;
                enterProc.running = true;
                rootItem.forceActiveFocus();
            } else {
                overviewWindow.layoutData = null;
                if (!overviewWindow.jumpPending) {
                    exitProc.running = true;
                }
                overviewWindow.jumpPending = false;
            }
        }
    }
    
    Item {
        id: rootItem
        anchors.fill: parent
        focus: shell.overviewActive
        visible: shell.overviewActive
        
        Keys.onEscapePressed: shell.overviewActive = false
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Space) {
                shell.overviewActive = false;
            }
        }
        
        // Dim background behind scaled windows
        Rectangle {
            anchors.fill: parent
            color: "#B3000000"
            
            MouseArea {
                anchors.fill: parent
                onClicked: shell.overviewActive = false
            }
        }
        
        // Grid cell labels and click targets
        Repeater {
            model: {
                if (!overviewWindow.layoutData) return 0;
                var d = overviewWindow.layoutData;
                return d.cols * d.rows;
            }
            
            Item {
                property var d: overviewWindow.layoutData
                property int col: index % d.cols
                property int row: Math.floor(index / d.cols)
                property int cellVx: d.min_vx + col
                property int cellVy: d.max_vy - row
                property bool isCurrent: (cellVx === d.vx && cellVy === d.vy)
                
                x: d.ox + col * (d.cell_w + d.gap)
                y: d.oy + row * (d.cell_h + d.gap)
                width: d.cell_w
                height: d.cell_h
                
                // Cell border
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: isCurrent ? "#4caf50" : (cellMa.containsMouse ? "#66FFFFFF" : "#33FFFFFF")
                    border.width: isCurrent ? 2 : 1
                    radius: 6
                    
                    // Hover highlight
                    Rectangle {
                        anchors.fill: parent
                        color: cellMa.containsMouse ? "#1AFFFFFF" : "transparent"
                        radius: 6
                    }
                    
                    // Coordinate label
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 4
                        text: cellVx + "," + cellVy
                        color: isCurrent ? "#4caf50" : "#80FFFFFF"
                        font.pixelSize: Math.max(10, d.cell_h * 0.08)
                        font.bold: isCurrent
                    }
                }
                
                MouseArea {
                    id: cellMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        overviewWindow.jumpPending = true;
                        shell.overviewActive = false;
                        jumpProc.targetVx = cellVx;
                        jumpProc.targetVy = cellVy;
                        jumpProc.running = true;
                    }
                }
            }
        }
        
        // Loading indicator
        Text {
            anchors.centerIn: parent
            text: "Loading overview..."
            color: "#80FFFFFF"
            font.pixelSize: 16
            visible: overviewWindow.isEntering
        }
    }
}
