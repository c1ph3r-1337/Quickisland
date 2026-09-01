import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

NIconButtonHot {
  id: root
  property ShellScreen screen
  icon: "broadcast"
  tooltipText: "Hotspot"

  property bool hotspotActive: false

  onClicked: {
    if (hotspotActive) {
      Quickshell.execDetached(["nmcli", "connection", "down", "c1ph3r_hotspot"]);
      hotspotActive = false;
    } else {
      Quickshell.execDetached(["nmcli", "connection", "up", "c1ph3r_hotspot"]);
      hotspotActive = true;
    }
  }

  Process {
    id: statusCheckProcess
    command: ["sh", "-c", "nmcli -t -f NAME,STATE connection show | grep '^c1ph3r_hotspot:activated'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim().length > 0) {
          root.hotspotActive = true;
        } else {
          root.hotspotActive = false;
        }
      }
    }
  }

  hot: hotspotActive
}
