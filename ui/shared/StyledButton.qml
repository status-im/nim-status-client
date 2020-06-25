import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQml 2.14
import "../imports"

Button {
    property string label: "My button"
    property color btnColor: Theme.lightBlue
    property color btnBorderColor: "transparent"
    property int btnBorderWidth: 0
    property color textColor: Theme.blue
    property bool disabled: false

    id: btnStyled
    width: txtBtnLabel.width + 2 * Theme.padding
    height: 44
    enabled: !disabled

    background: Rectangle {
        color: disabled ? Theme.grey : btnStyled.btnColor
        radius: Theme.radius
        anchors.fill: parent
        border.color: btnBorderColor
        border.width: btnBorderWidth
    }

    StyledText {
        id: txtBtnLabel
        color: btnStyled.disabled ? Theme.darkGrey : btnStyled.textColor
        font.pixelSize: 15
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        text: btnStyled.label
        font.weight: Font.Medium
    }

    MouseArea {
        cursorShape: Qt.PointingHandCursor
        anchors.fill: parent
        onClicked: {
            parent.onClicked()
        }
    }
}
