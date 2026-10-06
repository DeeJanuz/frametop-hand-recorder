// A progress bar: fraction 0..1, or a bar sweeping across while it's unknown (fraction < 0).
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: track
    property real fraction: 0
    readonly property bool unknown: fraction < 0
    Layout.fillWidth: true
    Layout.maximumWidth: 520
    implicitWidth: 520
    implicitHeight: 12
    radius: height / 2
    clip: true
    color: Theme.raised

    Rectangle {
        id: fill
        height: parent.height
        radius: parent.radius
        color: Theme.accent
        width: track.unknown ? parent.width / 4 : parent.width * Math.max(0, Math.min(1, track.fraction))
        x: 0
        SequentialAnimation on x {
            running: track.visible && track.unknown
            loops: Animation.Infinite
            onRunningChanged: if (!running) fill.x = 0
            NumberAnimation { from: -fill.width; to: track.width; duration: 1600 }
        }
    }
}
