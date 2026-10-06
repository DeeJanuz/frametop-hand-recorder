// The dashboard spike's window (spike.py): big controls, and every input logged.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    visible: true
    title: "Hand Recorder: dashboard spike"
    color: "#1b1e23"
    font.pixelSize: 24
    palette.window: "#1b1e23"
    palette.windowText: "#eef1f5"
    palette.base: "#262a31"
    palette.text: "#eef1f5"
    palette.button: "#30353e"
    palette.buttonText: "#eef1f5"
    palette.highlight: "#4cd9ff"
    palette.highlightedText: "#10161c"
    palette.placeholderText: "#8a929e"

    property int clicks: 0
    property string status: "Try each control, then tell the session what happened."

    onWidthChanged: spike.note("size", width + "x" + height)
    onHeightChanged: spike.note("size", width + "x" + height)
    onActiveChanged: spike.note("active", String(active))

    component Big: Button {
        Layout.preferredHeight: 72
        Layout.fillWidth: true
        font.pixelSize: 24
    }

    // Keys from anywhere in the window (a keyboard, or SteamVR's)
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => spike.note("key", event.text + " (" + event.key + ")")
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        ColumnLayout {
            Layout.preferredWidth: 760
            Layout.fillHeight: true
            spacing: 16

            Label {
                text: "Dashboard spike"
                font.pixelSize: 34
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: root.status
                color: "#4cd9ff"
            }
            Big {
                text: "Click me (" + root.clicks + ")"
                onClicked: { root.clicks += 1; spike.note("click", String(root.clicks)) }
            }
            TextField {
                id: field
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                placeholderText: "Click here: does the SteamVR keyboard open?"
                onTextEdited: spike.note("text", text)
                onActiveFocusChanged: spike.note("text-focus", String(activeFocus))
            }
            RowLayout {
                Layout.fillWidth: true
                Big {
                    text: "Copy the text"
                    onClicked: { spike.copy(field.text || "spike clipboard test"); root.status = "Copied" }
                }
                Big {
                    text: "Paste"
                    onClicked: { const t = spike.paste(); field.text = t; root.status = "Pasted: " + t }
                }
            }
            Big {
                text: "Open huggingface.co in the browser"
                onClicked: root.status = spike.openLink() ? "Asked for the browser: did it open, and can you use it?"
                                                          : "Qt couldn't open the link"
            }
            Big {
                text: spike.panelOn ? "Stop the headset panel" : "Show the headset panel"
                onClicked: root.status = spike.togglePanel()
            }
            Big {
                text: spike.awake ? "Allow sleep again" : "Block sleep for 15 minutes"
                onClicked: root.status = spike.toggleAwake()
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Headset button: " + spike.presses
                font.pixelSize: 26
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 18
                color: "#8a929e"
                text: spike.info + "\nWindow: " + root.width + "x" + root.height
            }
            Item { Layout.fillHeight: true }
            Big {
                text: "Quit"
                onClicked: Qt.quit()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Label { text: "Scroll this list" }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: 80
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                    width: 28
                }
                delegate: ItemDelegate {
                    required property int index
                    width: ListView.view.width - 32
                    height: 64
                    text: "Row " + (index + 1)
                    onClicked: spike.note("row", String(index + 1))
                }
                property int lastLogged: -1
                onContentYChanged: {
                    const row = Math.round(contentY / 64)
                    if (Math.abs(row - lastLogged) >= 5) { lastLogged = row; spike.note("scroll", "row " + row) }
                }
            }
        }
    }
}
