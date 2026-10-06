// The window's colours and sizes: a dark palette, sized for a laser pointer in SteamVR's
// dashboard (a panel of about 1280x800).
pragma Singleton
import QtQuick

QtObject {
    // Colours
    readonly property color background: "#1b1e23"
    readonly property color surface: "#23272e"       // the navigation, list rows, banners
    readonly property color raised: "#2e333c"        // buttons, fields, check boxes
    readonly property color hover: "#3a404b"
    readonly property color pressed: "#474e5b"
    readonly property color border: "#5a6271"
    readonly property color separator: "#3a404a"
    readonly property color text: "#f1f3f6"
    readonly property color dimText: "#aab2bf"
    readonly property color accent: "#4cd9ff"
    readonly property color accentHover: "#7ee4ff"
    readonly property color accentPressed: "#2bb8de"
    readonly property color accentText: "#0b1a20"      // text on an accent background
    readonly property color positive: "#4cc38a"
    readonly property color warning: "#f0b232"
    readonly property color negative: "#f2575d"

    // SteamOS's UI font, named so the layout doesn't depend on fontconfig's default (CI installs
    // it too: tests/shoot.py checks it's there)
    readonly property string fontFamily: "Noto Sans"

    // Sizes (pixels)
    readonly property int fontSize: 22
    readonly property int smallFontSize: 18
    readonly property int headingSize: 28
    readonly property int titleSize: 34
    readonly property int controlHeight: 56
    readonly property int indicatorSize: 34
    readonly property int spacing: 12
    readonly property int largeSpacing: 24
    readonly property int radius: 8
    readonly property int scrollBarWidth: 24
    readonly property int navWidth: 250
    readonly property int contentMaxWidth: 900
    readonly property int pageMargin: 28

    function tint(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }
    // Banners: info, positive, warning, error.
    function toneColor(type) {
        return type === "positive" ? positive : type === "warning" ? warning : type === "error" ? negative : accent
    }
}
