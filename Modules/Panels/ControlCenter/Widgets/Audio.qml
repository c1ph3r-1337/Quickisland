import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Media
import qs.Services.UI
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: AudioService.muted ? "volume-off" : "volume-high"
  hot: !AudioService.muted
  tooltipText: "Audio"
  onClicked: {
    AudioService.setOutputMuted(!AudioService.muted);
  }
}
