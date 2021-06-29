import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../imports"
import "../shared/status"
import "./"

ModalPopup {
    id: popup

    property bool newVersionAvailable: true
    property string downloadURL: "https://github.com/status-im/status-desktop/releases/latest"

    height: 240
    width: 400
    title: newVersionAvailable ?
           qsTr("New version available!") :
           qsTr("No new version available")

    SVGImage {
        visible: newVersionAvailable
        id: imgExclamation
        width: 13.33
        height: 13.33
        sourceSize.height: height * 2
        sourceSize.width: width * 2
        anchors.horizontalCenter: parent.horizontalCenter
        fillMode: Image.PreserveAspectFit
        source: "../app/img/exclamation_outline.svg"
    }


    StyledText {
        visible: newVersionAvailable
        id: innerText
        text: qsTr("Make sure you have your account password and seed phrase stored. Without them you can lock yourself out of your account and lose funds.")
        font.pixelSize: 13
        color: Style.current.red
        anchors.top: imgExclamation.bottom
        anchors.topMargin: Style.current.halfPadding
        anchors.left: parent.left
        anchors.right: parent.right
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    StyledText {
        visible: !newVersionAvailable
        id: innerText2
        text: qsTr("You are up to date!")
        font.pixelSize: 15
        anchors.left: parent.left
        anchors.right: parent.right
        wrapMode: Text.WordWrap
    }

    footer: StatusButton {
        id: confirmButton
        text: newVersionAvailable ?
              qsTr("Download") :
              qsTr("Ok")
        anchors.right: parent.right
        onClicked: newVersionAvailable ? appMain.openLink(downloadURL) : close()
    }
}



