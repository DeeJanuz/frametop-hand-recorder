// A section of a form page: a heading with a thin line under it.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    property alias text: heading.text
    Layout.fillWidth: true
    Layout.topMargin: Theme.largeSpacing
    spacing: 6
    Label {
        id: heading
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font.pixelSize: Theme.headingSize
        font.bold: true
        color: Theme.text
    }
    Separator { Layout.fillWidth: true }
}
