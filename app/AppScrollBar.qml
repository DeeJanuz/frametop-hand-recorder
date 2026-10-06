// A wide scroll bar, shown whenever there's more to scroll to, so a laser pointer can drag it.
import QtQuick
import QtQuick.Controls.Basic

ScrollBar {
    id: control
    implicitWidth: orientation === Qt.Vertical ? Theme.scrollBarWidth : 100
    implicitHeight: orientation === Qt.Horizontal ? Theme.scrollBarWidth : 100
    padding: 3
    minimumSize: 0.08
    policy: size < 1.0 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

    contentItem: Rectangle {
        implicitWidth: Theme.scrollBarWidth - 6
        implicitHeight: Theme.scrollBarWidth - 6
        radius: Math.min(width, height) / 2
        color: control.pressed ? Theme.accent : control.hovered ? Theme.dimText : Theme.border
    }

    background: Rectangle {
        radius: Math.min(width, height) / 2
        color: Theme.surface
    }
}
