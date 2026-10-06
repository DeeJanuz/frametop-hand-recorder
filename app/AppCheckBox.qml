// A check box with a big box and wrapped text, the whole row clickable.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

CheckBox {
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
        radius: 6
        color: control.checked ? Theme.accent : (control.down ? Theme.pressed : Theme.raised)
        border.width: 2
        border.color: control.checked ? Theme.accent : (control.hovered ? Theme.text : Theme.border)
        opacity: control.enabled ? 1 : 0.4

        // The check mark: two bars, drawn (no font or icon needed).
        Item {
            anchors.fill: parent
            visible: control.checkState === Qt.Checked
            Rectangle {
                x: parent.width * 0.18
                y: parent.height * 0.5
                width: parent.width * 0.3
                height: 4
                radius: 2
                color: Theme.accentText
                rotation: 45
                transformOrigin: Item.Left
            }
            Rectangle {
                x: parent.width * 0.37
                y: parent.height * 0.71
                width: parent.width * 0.52
                height: 4
                radius: 2
                color: Theme.accentText
                rotation: -50
                transformOrigin: Item.Left
            }
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
