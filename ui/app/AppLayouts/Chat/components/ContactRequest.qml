import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"

Rectangle {
    property string name
    property string address
    property string identicon
    property string localNickname
    property var profileClick: function() {}
    signal blockContactActionTriggered(name: string, address: string)
    property bool isHovered: false
    id: container

    height: visible ? 64 : 0
    anchors.right: parent.right
    anchors.left: parent.left
    border.width: 0
    radius: Style.current.radius
    color: isHovered ? Style.current.backgroundHover : Style.current.transparent

    StatusImageIdenticon {
        id: accountImage
        anchors.left: parent.left
        anchors.leftMargin: Style.current.padding
        anchors.verticalCenter: parent.verticalCenter
        source: identicon
    }

    StyledText {
        id: usernameText
        text: name
        elide: Text.ElideRight
        font.pixelSize: 17
        anchors.top: accountImage.top
        anchors.topMargin: Style.current.smallPadding
        anchors.left: accountImage.right
        anchors.leftMargin: Style.current.padding
        anchors.right: buttons.left
        anchors.rightMargin: Style.current.padding
    }

    HoverHandler {
        onHoveredChanged: container.isHovered = hovered
    }

    AcceptRejectOptionsButtons {
        id: buttons
        anchors.right: parent.right
        anchors.rightMargin: Style.current.padding
        anchors.verticalCenter: parent.verticalCenter
        onAcceptClicked: {
            chatsModel.channelView.joinPrivateChat(container.address, "")
            profileModel.contacts.addContact(container.address)
        }
        onDeclineClicked: profileModel.contacts.rejectContactRequest(container.address)
        onProfileClicked: profileClick(true, name, address, identicon, "", localNickname)
        onBlockClicked: container.blockContactActionTriggered(name, address)
    }
}
