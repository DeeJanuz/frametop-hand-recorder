// A slider with a big handle, for dragging with a laser pointer.
import QtQuick
import QtQuick.Controls.Basic

Slider {
    id: control
    implicitHeight: 52
    leftPadding: 22
    rightPadding: 22

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 8
        radius: 4
        color: Theme.raised
        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 4
            color: Theme.tint(Theme.accent, 0.55)
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * control.availableWidth - width / 2
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 40
        height: 40
        radius: 20
        color: control.pressed ? Theme.accent : control.hovered ? Theme.accentHover : Theme.text
        border.width: 2
        border.color: Theme.background
    }
}
