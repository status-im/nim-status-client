import QtQuick 2.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"

Rectangle {
    id: noContactsRect
    width: 260
    property string text: qsTr("You don’t have any contacts yet. Invite your friends to start chatting.")
    StyledText {
        id: noContacts
        text: noContactsRect.text
        color: Style.current.darkGrey
        anchors.top: parent.top
        anchors.topMargin: Style.current.padding
        anchors.left: parent.left
        anchors.right: parent.right
        wrapMode: Text.WordWrap
        font.pixelSize: 15
        horizontalAlignment: Text.AlignHCenter
    }
    StatusButton {
        //% "Invite friends"
        text: qsTrId("invite-friends")
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: noContacts.bottom
        anchors.topMargin: Style.current.xlPadding
        onClicked: inviteFriendsPopup.open()
    }
    InviteFriendsPopup {
        id: inviteFriendsPopup
    }
}
