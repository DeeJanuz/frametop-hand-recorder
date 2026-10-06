// A page whose content (one column, at most Theme.contentMaxWidth wide) scrolls, with a
// wide scroll bar. Put the content in "content: [ ... ]" or as children.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

AppPage {
    id: page
    default property alias content: column.data
    property alias flickable: flick
    // The column's width, for content that sizes itself.
    readonly property real columnWidth: column.width

    contentItem: Flickable {
        id: flick
        clip: true
        contentWidth: width
        contentHeight: column.implicitHeight + 2 * Theme.pageMargin
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: AppScrollBar { }

        ColumnLayout {
            id: column
            readonly property real room: flick.width - 2 * Theme.pageMargin - Theme.scrollBarWidth
            width: Math.min(Theme.contentMaxWidth, room)
            x: Theme.pageMargin + Math.max(0, (room - width) / 2)
            y: Theme.pageMargin
            spacing: Theme.spacing
        }
    }
}
