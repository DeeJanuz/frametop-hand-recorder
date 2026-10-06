// A field's name, above its control.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Label {
    Layout.fillWidth: true
    Layout.topMargin: Theme.spacing
    wrapMode: Text.Wrap
    font.pixelSize: Theme.smallFontSize
    font.bold: true
    color: Theme.dimText
}
