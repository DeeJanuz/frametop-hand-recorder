// An empty page or list: a centred title, an explanation, and an optional button
// (actionText; pressing it emits triggered()).
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: placeholder
    property string text
    property string explanation
    property string actionText
    signal triggered()
    spacing: Theme.largeSpacing

    Label {
        Layout.fillWidth: true
        text: placeholder.text
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Theme.headingSize
        font.bold: true
        color: Theme.text
    }
    Label {
        Layout.fillWidth: true
        visible: placeholder.explanation !== ""
        text: placeholder.explanation
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: Theme.dimText
    }
    AppButton {
        Layout.alignment: Qt.AlignHCenter
        visible: placeholder.actionText !== ""
        text: placeholder.actionText
        highlighted: true
        onClicked: placeholder.triggered()
    }
}
