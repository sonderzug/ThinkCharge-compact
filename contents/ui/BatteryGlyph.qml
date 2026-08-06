import QtQuick

Item {
    id: root
    property color glyphColor: "white"
    property color targetColor: "#3daee9"
    property color actualColor: charging ? "#2ecc71" : glyphColor
    property real targetFillLevel: 0.8
    property real actualFillLevel: 0.6
    property bool charging: false
    implicitWidth: 20
    implicitHeight: 12

    Rectangle {
        id: body
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 3
        height: parent.height
        radius: 2
        color: "transparent"
        border.width: 1
        border.color: root.glyphColor
        Rectangle {
            x: 2
            y: 2
            width: Math.max(0, (body.width - 4) * Math.max(0, Math.min(1, root.targetFillLevel)))
            height: body.height - 4
            color: root.targetColor
            opacity: 0.8
            radius: 0.5
        }
        Rectangle {
            x: 2
            y: 2
            width: Math.max(0, (body.width - 4) * Math.max(0, Math.min(1, root.actualFillLevel)))
            height: body.height - 4
            color: root.actualColor
            opacity: 1
            radius: 0.5
        }
        Canvas {
            anchors.centerIn: parent
            width: 7
            height: 10
            visible: root.charging
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = "white"
                ctx.beginPath()
                ctx.moveTo(width * 0.58, 0)
                ctx.lineTo(width * 0.12, height * 0.56)
                ctx.lineTo(width * 0.48, height * 0.56)
                ctx.lineTo(width * 0.34, height)
                ctx.lineTo(width * 0.9, height * 0.4)
                ctx.lineTo(width * 0.56, height * 0.4)
                ctx.closePath()
                ctx.fill()
            }
        }
    }
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height * 0.45
        radius: 1
        color: root.glyphColor
    }
}
