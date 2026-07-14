import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Power
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: PowerProfileService.quickislandPerformanceMode ? "rocket" : "rocket-off"
  tooltipText: I18n.tr("tooltips.quickisland-performance-enabled")
  hot: PowerProfileService.quickislandPerformanceMode
  onClicked: PowerProfileService.toggleQuickislandPerformance()
}
