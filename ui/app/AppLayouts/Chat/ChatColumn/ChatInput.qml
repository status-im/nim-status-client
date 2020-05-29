import QtQuick 2.3
import QtQuick.Controls 2.3
import QtQuick.Controls 2.12 as QQC2
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1
import "../../../../shared"
import "../../../../imports"

Rectangle {
    id: element2
    width: 200
    height: 70
    Layout.fillWidth: true
    color: "white"
    border.width: 0

    Rectangle {
        id: rectangle
        color: "#00000000"
        border.color: Theme.grey
        anchors.fill: parent

        Button {
            id: chatSendBtn
            visible: txtData.length > 0
            x: 100
            width: 30
            height: 30
            text: ""
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 16
            onClicked: {
                chatsModel.sendMessage(txtData.text)
                txtData.text = ""
            }
            background: Rectangle {
                color: parent.enabled ? Theme.blue : Theme.grey
                radius: 50
            }
            Image {
                source: "../../../img/arrowUp.svg"
                width: 12
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        TextField {
            id: txtData
            text: ""
            leftPadding: 0
            padding: 0
            font.pixelSize: 14
            placeholderText: qsTr("Type a message...")
            anchors.right: chatSendBtn.left
            anchors.rightMargin: 16
            anchors.top: parent.top
            anchors.topMargin: 24
            anchors.left: parent.left
            anchors.leftMargin: 24
            Keys.onEnterPressed: {
                chatsModel.sendMessage(txtData.text)
                txtData.text = ""
            }
            Keys.onReturnPressed: {
                chatsModel.sendMessage(txtData.text)
                txtData.text = ""
            }
            background: Rectangle {
                color: "#00000000"
            }
        }

        MouseArea {
            id: mouseArea1
            anchors.rightMargin: 50
            anchors.fill: parent
            onClicked: {
                txtData.forceActiveFocus(Qt.MouseFocusReason)
            }
        }
    }
}
/*##^##
Designer {
    D{i:0;width:600}
}
##^##*/
