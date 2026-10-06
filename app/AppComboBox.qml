// A combo box with big rows in its list, for a laser pointer. Its models here are lists of
// objects (textRole names the shown key).
import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: control
    implicitHeight: Theme.controlHeight
    implicitWidth: 460
    leftPadding: 16
    rightPadding: 16 + 40

    delegate: ItemDelegate {
        id: row
        required property var modelData
        required property int index
        width: ListView.view ? ListView.view.width : control.width
        implicitHeight: Theme.controlHeight
        leftPadding: 16
        rightPadding: 16
        highlighted: control.highlightedIndex === index
        text: control.textRole ? modelData[control.textRole] : modelData
        contentItem: Label {
            text: row.text
            font.pixelSize: control.font.pixelSize
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            color: row.highlighted ? Theme.accentText : Theme.text
            font.bold: control.currentIndex === row.index
        }
        background: Rectangle {
            radius: Theme.radius - 2
            color: row.highlighted ? Theme.accent : row.down ? Theme.pressed : "transparent"
        }
    }

    indicator: Canvas {
        x: control.width - width - 20
        y: (control.height - height) / 2
        width: 18
        height: 11
        contextType: "2d"
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width / 2, height)
            ctx.closePath()
            ctx.fillStyle = Theme.text
            ctx.fill()
        }
        opacity: control.enabled ? 1 : 0.4
    }

    contentItem: Label {
        text: control.displayText
        font: control.font
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        color: Theme.text
        opacity: control.enabled ? 1 : 0.4
    }

    background: Rectangle {
        implicitHeight: Theme.controlHeight
        radius: Theme.radius
        color: control.down ? Theme.pressed : control.hovered && control.enabled ? Theme.hover : Theme.raised
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Theme.accent : Theme.border
        opacity: control.enabled ? 1 : 0.55
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        // Kept inside the window, scrolling when it doesn't fit.
        margins: 8
        implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding,
                                 control.Window.height - 16)
        padding: 6

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: AppScrollBar { }
        }

        background: Rectangle {
            radius: Theme.radius
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
        }
    }
}
