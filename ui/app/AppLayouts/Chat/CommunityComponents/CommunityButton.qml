import QtQuick 2.13
import QtQuick.Controls 2.13
import "../../../../shared"
import "../../../../shared/status"
import "../../../../imports"
import "../components"

StatusIconTabButton {
    property string communityId: ""
    property string name: "channelName"
    property int unviewedMessagesCount: 0
    property string image
    property bool hasMentions: false

    id: communityButton
    anchors.horizontalCenter: parent.horizontalCenter
    iconSource: communityButton.image
    anchors.topMargin: 0

    section: Constants.community

    checked: chatsModel.communities.activeCommunity.active && chatsModel.communities.activeCommunity.id === communityId

    borderOnChecked: true
    doNotHandleClick: true
    onClicked: {
        appMain.changeAppSection(Constants.chat)
        chatsModel.communities.setActiveCommunity(communityId)
    }

    StatusToolTip {
        visible: communityButton.hovered
        text: communityButton.name
        delay: 50
        orientation: "right"
        x: communityButton.width + Style.current.padding
        y: communityButton.height / 2 - height / 2 + 4
    }

    Rectangle {
        id: chatBadge
        visible: unviewedMessagesCount > 0
        anchors.top: parent.top
        anchors.left: parent.right
        anchors.leftMargin: -17
        anchors.topMargin: 1
        radius: height / 2
        color: Style.current.blue
        border.color: Style.current.background
        border.width: 2
        width: unviewedMessagesCount < 10 ? 22 : messageCount.width + 14
        height: 22
        Text {
            id: messageCount
            font.pixelSize: chatsModel.messageView.unreadMessagesCount > 99 ? 10 : 12
            color: Style.current.white
            anchors.centerIn: parent
            text: unviewedMessagesCount > 99 ? "99+" : unviewedMessagesCount
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                commnunityMenu.communityId = communityButton.communityId
                commnunityMenu.popup()
                return
            }
            communityButton.clicked()
        }
    }
}
