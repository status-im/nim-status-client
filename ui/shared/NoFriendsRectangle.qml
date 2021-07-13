import QtQuick 2.13
import "../imports"
import "."
import "./status"

Item {
    id: noContactsRect
    width: 260
    //% "You don’t have any contacts yet. Invite your friends to start chatting."
    property string text: qsTrId("you-don-t-have-any-contacts-yet--invite-your-friends-to-start-chatting-")
    property alias textColor: noContacts.color
    StyledText {
        id: noContacts
        text: noContactsRect.text
        color: Style.current.secondaryText
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
        anchors.topMargin: Style.current.padding
        onClicked: inviteFriendsPopup.open()
    }
    InviteFriendsPopup {
        id: inviteFriendsPopup
    }
}
