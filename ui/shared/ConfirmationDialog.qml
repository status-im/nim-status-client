import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../imports"
import "../shared/status"
import "./"

ModalPopup {
    id: confirmationDialog

    property Popup parentPopup
    property string btnType: "warn"
    property bool showCancelButton: false


    height: 186
    width: 400
    //% "Confirm your action"
    title: qsTrId("confirm-your-action")

    //% "Confirm"
    property string confirmButtonLabel: qsTrId("close-app-button")
    //% "Cancel"
    property string cancelButtonLabel: qsTr("Cancel")
    //% "Are you sure you want to this?"
    property string confirmationText: qsTrId("are-you-sure-you-want-to-this-")

    property var value

    signal confirmButtonClicked()
    signal cancelButtonClicked()

    StyledText {
        id: innerText
        text: confirmationDialog.confirmationText
        font.pixelSize: 15
        anchors.left: parent.left
        anchors.right: parent.right
        wrapMode: Text.WordWrap
    }

    footer: Item {
        id: footerContainer
        width: parent.width
        height: confirmButton.height

        StatusButton {
            id: confirmButton
            type: confirmationDialog.btnType
            anchors.right: cancelButton.left
            anchors.rightMargin: Style.current.smallPadding
            text: confirmationDialog.confirmButtonLabel
            anchors.bottom: parent.bottom
            onClicked: confirmationDialog.confirmButtonClicked()
        }

        StatusButton {
            id: cancelButton
            anchors.right: parent.right
            visible: showCancelButton
            anchors.rightMargin: Style.current.smallPadding
            text: confirmationDialog.cancelButtonLabel
            anchors.bottom: parent.bottom
            onClicked: confirmationDialog.cancelButtonClicked()
        }
    }
}



