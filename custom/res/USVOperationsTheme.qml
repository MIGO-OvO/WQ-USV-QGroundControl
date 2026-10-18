import QtQuick

import QGroundControl
import QGroundControl.Controls

QtObject {
    readonly property real backgroundOpacity: ScreenTools.panelOpacity
    readonly property real bodyPointSize: Math.max(12, ScreenTools.defaultFontPointSize)
    readonly property real captionPointSize: bodyPointSize / 1.125
    readonly property real headingPointSize: bodyPointSize * 1.125
    function background(color) { return Qt.rgba(color.r, color.g, color.b, backgroundOpacity); }
    readonly property color accent: Qt.lighter(palette.buttonHighlight, 1.15)
    readonly property real controlHeight: Math.max(ScreenTools.minTouchPixels, line * 2.4)
    readonly property color danger: Qt.lighter(palette.colorRed, 1.25)
    readonly property color dangerFill: Qt.darker(palette.colorRed, 1.3)
    readonly property bool dark: palette.globalTheme === QGCPalette.Dark
    readonly property color divider: Qt.tint(surface, Qt.rgba(text.r, text.g, text.b, 0.20))
    readonly property real dockRadius: unit * 1.5
    readonly property real gap: unit * 1.5
    readonly property color good: Qt.lighter(palette.colorGreen, dark ? 1 : 1.7)
    readonly property real line: ScreenTools.defaultFontPixelHeight
    readonly property color panel: background(surface)
    readonly property color toolbarSurface: panel
    readonly property color mutedFill: Qt.tint(surface, Qt.rgba(text.r, text.g, text.b, 0.06))
    // Map overlays keep an opaque foreground over an alpha-only background.
    readonly property QGCPalette palette: QGCPalette {
        colorGroupEnabled: true
    }
    readonly property color primaryFill: Qt.darker(palette.buttonHighlight, 1.8)
    readonly property real radius: unit * 0.5
    readonly property color raised: Qt.lighter(surface, 1.45)
    readonly property color secondary: Qt.tint(surface, Qt.rgba(text.r, text.g, text.b, 0.72))
    readonly property color surface: dark ? Qt.darker(palette.window, 1.18) : Qt.darker(palette.window, 7)
    readonly property color text: dark ? palette.text : palette.window
    readonly property real unit: ScreenTools.defaultFontPixelWidth
    readonly property color warning: Qt.lighter(palette.colorOrange, 1.25)
}
