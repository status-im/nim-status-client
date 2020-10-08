import QtQuick 2.13
import QtQuick.Controls 2.13
import QtGraphicalEffects 1.13
import "../../imports"
import "../../shared"

RoundButton {
    id: control

    property string type: "primary"
    property color iconColor: Style.current.secondaryText
    property color disabledColor: iconColor
    property int iconRotation: 0

    implicitHeight: 32
    implicitWidth: 32

    icon.height: 20
    icon.width: 20
    icon.color: {
        if (!enabled) {
            return control.disabledColor
        }

        return (hovered || highlighted) ? Style.current.blue : control.iconColor
    }
    radius: Style.current.radius

    onIconChanged: {
        icon.source = icon.name ? "../../app/img/" + icon.name + ".svg" : ""
    }

    background: Rectangle {
        anchors.fill: parent
        color: {
            if (type === "secondary") {
                return "transparent"
            }
            return hovered || highlighted ? Style.current.secondaryBackground : "transparent"
        }
        radius: control.radius
    }

    contentItem: Item {
        anchors.fill: parent

        SVGImage {
            id: iconImg
            visible: false
            source: control.icon.source
            height: control.icon.height
            width: control.icon.width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            fillMode: Image.PreserveAspectFit
            rotation: control.iconRotation
        }
        ColorOverlay {
            anchors.fill: iconImg
            source: iconImg
            color: control.icon.color
            antialiasing: true
            smooth: true
            rotation: control.iconRotation
        }

    }

    MouseArea {
        cursorShape: Qt.PointingHandCursor
        anchors.fill: parent
        onPressed: mouse.accepted = false
    }
}
