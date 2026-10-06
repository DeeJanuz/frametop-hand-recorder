// A message: type info, positive, warning or error, with wrapped text and optional buttons
// (actions: [AppButton { ... }]; showActions: false hides them all). header: true spans the
// page's width, under its title.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Control {
    id: banner
    property string type: "info"
    property string text
    property bool header: false
    property alias actions: actionRow.data
    property bool showActions: actionRow.children.length > 0
    readonly property color tone: Theme.toneColor(type)

    Layout.fillWidth: true
    padding: Theme.spacing + 4
    leftPadding: Theme.largeSpacing + (header ? Theme.pageMargin - Theme.largeSpacing : 8)
    rightPadding: header ? Theme.pageMargin : Theme.largeSpacing

    background: Rectangle {
        radius: banner.header ? 0 : 4
        color: Qt.tint(Theme.surface, Theme.tint(banner.tone, 0.16))
        border.width: banner.header ? 0 : 1
        border.color: Theme.tint(banner.tone, 0.45)
        Rectangle {
            width: 8
            height: parent.height
            radius: banner.header ? 0 : 4
            color: banner.tone
        }
        // the stripe's right side square
        Rectangle {
            x: 4
            width: 4
            height: parent.height
            color: banner.tone
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing
        Label {
            Layout.fillWidth: true
            text: banner.text
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            color: Theme.text
        }
        Flow {
            id: actionRow
            Layout.fillWidth: true
            spacing: Theme.spacing
            visible: banner.showActions
        }
    }
}
