// A radio button with a big circle and wrapped text, the whole row clickable. Radio buttons
// in the same parent item exclude each other: keep each group in its own layout.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

RadioButton {
    id: control
    Layout.fillWidth: true
    spacing: Theme.spacing + 4
    padding: 8
    implicitHeight: Math.max(Theme.controlHeight, implicitContentHeight + topPadding + bottomPadding)

    indicator: Rectangle {
        implicitWidth: Theme.indicatorSize
        implicitHeight: Theme.indicatorSize
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        radius: width / 2
        color: control.down ? Theme.pressed : Theme.raised
        border.width: 2
        border.color: control.checked ? Theme.accent : (control.hovered ? Theme.text : Theme.border)
        opacity: control.enabled ? 1 : 0.4
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.5
            height: width
            radius: width / 2
            color: Theme.accent
            visible: control.checked
        }
    }

    contentItem: Label {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        font: control.font
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
        color: Theme.text
        opacity: control.enabled ? 1 : 0.4
    }

    background: Rectangle {
        radius: Theme.radius
        color: control.down ? Theme.raised : control.hovered ? Theme.surface : "transparent"
    }
}
