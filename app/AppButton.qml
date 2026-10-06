// A text button big enough for a laser pointer. highlighted: the page's main action (accent);
// flat: no fill until hovered; checkable buttons show their checked state with an accent edge.
import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control
    padding: Theme.spacing
    leftPadding: Theme.largeSpacing
    rightPadding: Theme.largeSpacing
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(Theme.controlHeight, implicitContentHeight + topPadding + bottomPadding)

    contentItem: Label {
        text: control.text
        font: control.font
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: control.highlighted && control.enabled ? Theme.accentText : Theme.text
        opacity: control.enabled ? 1 : 0.4
    }

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: Theme.controlHeight
        radius: Theme.radius
        color: control.highlighted && control.enabled
               ? (control.down ? Theme.accentPressed : control.hovered ? Theme.accentHover : Theme.accent)
               : control.down ? Theme.pressed
               : control.hovered && control.enabled ? Theme.hover
               : control.flat ? "transparent" : Theme.raised
        border.width: control.checked ? 3 : (control.flat || control.highlighted ? 0 : 1)
        border.color: control.checked ? Theme.accent : Theme.border
        opacity: control.enabled ? 1 : 0.55
    }
}
