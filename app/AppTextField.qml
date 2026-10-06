// A one-line text field, as tall as the buttons.
import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: control
    implicitHeight: Theme.controlHeight
    implicitWidth: 520
    leftPadding: 16
    rightPadding: 16
    color: Theme.text
    placeholderTextColor: Theme.dimText
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentText
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: Theme.radius
        color: Theme.raised
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : control.hovered ? Theme.text : Theme.border
        opacity: control.enabled ? 1 : 0.55
    }
}
