.pragma library

// Shared geometry for Game Mode menus. The panel follows the full-width
// Game Mode bar, while each menu keeps its controls grouped in the center.
var panelHeight = 110
var launcherInset = 6
var launcherGap = 8
var launcherCellWidth = 88
var launcherCellHeight = 88
var controlCenterInset = 6
var controlCenterGap = 8
var contentMaxWidth = 1080
var formMaxWidth = 460
var notificationGroupMaxWidth = 388
var sessionButtonWidth = 80
var sessionPanelHeight = 96
var sessionGap = 8
var sessionSidePadding = 8

function sessionPanelWidth() {
    return sessionButtonWidth * 5 + sessionGap * 4 + sessionSidePadding * 2
}

function panelWidthFor(screenWidth) {
    return screenWidth > 0 ? screenWidth : 440
}

function contentWidthFor(availableWidth) {
    return Math.min(Math.max(0, availableWidth - 32), contentMaxWidth)
}

function centeredContentX(availableWidth, contentWidth) {
    return Math.max(0, (availableWidth - contentWidth) / 2)
}

function formWidthFor(availableWidth) {
    return Math.min(Math.max(0, availableWidth - 32), formMaxWidth)
}

function notificationWidthFor(availableWidth) {
    return Math.min(Math.max(0, availableWidth - 32), notificationGroupMaxWidth)
}

function appliesToState(state) {
    return state >= 2 && state <= 20
}

function usesCompactHeight(state) {
    return state >= 4 && state <= 6
}
