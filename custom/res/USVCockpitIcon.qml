import QtQuick

Item {
    id: root

    property color color: "white"
    property string name: ""
    readonly property string pathData: {
        switch (name) {
        case "menu": return "M3 5H21 M3 12H21 M3 19H21";
        case "gps": return "M12 2V5 M12 19V22 M2 12H5 M19 12H22 M20 12A8 8 0 1 1 4 12A8 8 0 1 1 20 12 M14 12A2 2 0 1 1 10 12A2 2 0 1 1 14 12";
        case "link": return "M12 12V21 M7 21L12 12L17 21 M9 8A4 4 0 0 0 9 14 M15 8A4 4 0 0 1 15 14 M6 5A8 8 0 0 0 6 17 M18 5A8 8 0 0 1 18 17 M13 10A1 1 0 1 1 11 10A1 1 0 1 1 13 10";
        case "ros": return "M12 6L5 17 M12 6L19 17 M5 17H19 M15 4A3 3 0 1 1 9 4A3 3 0 1 1 15 4 M8 19A3 3 0 1 1 2 19A3 3 0 1 1 8 19 M22 19A3 3 0 1 1 16 19A3 3 0 1 1 22 19";
        case "signal": return "M3 12H6L9 5L13 19L16 9L18 12H21";
        case "pump": return "M10 2H14L15 5L18 6L21 6L23 10L21 12L21 15L22 18L19 21L16 20L13 21L11 23L7 21L7 18L5 15L2 14V10L5 9L7 6L7 3Z M16 12A4 4 0 1 1 8 12A4 4 0 1 1 16 12";
        case "battery": return "M2 6H20V18H2Z M22 9V15 M5 9H16V15H5Z";
        case "boat": return "M8 4H16V9 M12 1V4 M4 11L12 8L20 11L17 18H7Z M2 21Q5 18 8 21Q12 18 16 21Q19 18 22 21";
        case "route": return "M2 5Q5 2 8 5Q11 8 14 5Q17 2 22 5 M2 12Q5 9 8 12Q11 15 14 12Q17 9 22 12 M2 19Q5 16 8 19Q11 22 14 19Q17 16 22 19";
        case "home": return "M2 11L12 2L22 11 M5 9V21H10V14H14V21H19V9";
        case "hold": return "M12 22L5 12A8 8 0 1 1 19 12Z M15 8A3 3 0 1 1 9 8A3 3 0 1 1 15 8";
        case "pause": return "M6 4H9V20H6Z M15 4H18V20H15Z";
        case "play": return "M6 3L21 12L6 21Z";
        case "stop": return "M5 5H19V19H5Z";
        case "hand": return "M9 13V4Q9 1 12 4V11 M12 10Q14 7 15 11Q18 8 18 13Q21 11 21 15V19Q20 22 15 22Q12 22 10 20L4 14Q2 11 5 11L9 13Z";
        case "flask": return "M8 2H16 M10 2V9L4 21H20L14 9V2 M7 15H17";
        case "baseline": return "M4 3H20V21H4Z M8 7H11 M14 7H17 M8 11H11 M14 11H17 M8 15H17 M8 18H17";
        case "temperature": return "M9 15V5Q9 1 12 1Q15 1 15 5V15A5 5 0 1 1 9 15 M12 7V17 M14 19A2 2 0 1 1 10 19A2 2 0 1 1 14 19";
        case "chip": return "M6 6H18V18H6Z M9 2V6 M15 2V6 M9 18V22 M15 18V22 M2 9H6 M2 15H6 M18 9H22 M18 15H22";
        case "diagnostics": return "M3 21V15H6V21Z M10 21V9H13V21Z M17 21V3H20V21Z";
        case "check": return "M5 12L10 17L20 6";
        case "warning": return "M12 2L23 22H1Z M12 8V14 M12 17V19";
        case "chevron": return "M8 4L16 12L8 20";
        case "down": return "M4 8L12 16L20 8";
        case "clock": return "M22 12A10 10 0 1 1 2 12A10 10 0 1 1 22 12 M12 6V12L17 15";
        default: return "";
        }
    }

    implicitHeight: 24
    implicitWidth: 24
    Accessible.ignored: true
    Image {
        anchors.fill: parent
        sourceSize.width: Math.round(width * Screen.devicePixelRatio)
        sourceSize.height: Math.round(height * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectFit
        source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="' + root.pathData + '" fill="none" stroke="' + Qt.rgba(root.color.r, root.color.g, root.color.b, 1).toString() + '" stroke-opacity="' + root.color.a + '" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>')
    }
}
