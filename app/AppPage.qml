// A page without scrolling: a title bar (Back on pushed pages, the title, tools on the right),
// then header banners across the page, then the content.
//   tools: [AppButton { ... }]      buttons at the title bar's right
//   banners: [Banner { header: true; ... }]
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Page {
    id: page
    property alias tools: toolRow.data
    property alias banners: bannerColumn.data
    readonly property bool canGoBack: StackView.view !== null && StackView.index > 0
    padding: 0

    background: Rectangle { color: Theme.background }

    header: Rectangle {
        color: Theme.background
        implicitHeight: headerColumn.implicitHeight
        ColumnLayout {
            id: headerColumn
            width: parent.width
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.pageMargin
                Layout.rightMargin: Theme.pageMargin
                Layout.topMargin: Theme.spacing
                Layout.bottomMargin: Theme.spacing
                spacing: Theme.largeSpacing
                AppButton {
                    visible: page.canGoBack
                    text: "‹ Back"
                    onClicked: page.StackView.view.pop()
                }
                Label {
                    Layout.fillWidth: true
                    text: page.title
                    elide: Text.ElideRight
                    font.pixelSize: Theme.titleSize
                    font.bold: true
                    color: Theme.text
                    verticalAlignment: Text.AlignVCenter
                    Layout.minimumHeight: Theme.controlHeight
                }
                Row {
                    id: toolRow
                    spacing: Theme.spacing
                }
            }
            Separator { Layout.fillWidth: true }
            ColumnLayout {
                id: bannerColumn
                Layout.fillWidth: true
                spacing: 0
            }
        }
    }
}
