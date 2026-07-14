import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.system.quickisland-performance-disable-wallpaper-label")
    description: I18n.tr("panels.system.quickisland-performance-disable-wallpaper-description")
    checked: !Settings.data.quickislandPerformance.disableWallpaper
    defaultValue: !Settings.getDefaultValue("quickislandPerformance.disableWallpaper")
    onToggled: checked => Settings.data.quickislandPerformance.disableWallpaper = !checked
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.system.quickisland-performance-disable-desktop-widgets-label")
    description: I18n.tr("panels.system.quickisland-performance-disable-desktop-widgets-description")
    checked: !Settings.data.quickislandPerformance.disableDesktopWidgets
    defaultValue: !Settings.getDefaultValue("quickislandPerformance.disableDesktopWidgets")
    onToggled: checked => Settings.data.quickislandPerformance.disableDesktopWidgets = !checked
  }
}
