import QtQuick 2.13
import QtQuick.Controls 2.13
import QtGraphicalEffects 1.13
import QtQuick.Layouts 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"

ModalPopup {
    id: root
    //% "Muted chats"
    title: qsTrId("muted-chats")
    property bool showMutedContacts: false

    onClosed: {
        root.destroy()
    }

    ListView {
        id: mutedChatsList
        anchors.top: parent.top
        visible: true
        anchors.left: parent.left
        anchors.right: parent.right
        model: root.showMutedContacts ? profileModel.mutedChats.contacts : profileModel.mutedChats.chats
        delegate: Rectangle {
            id: channelItem
            property bool isHovered: false
            height: contactImage.height + Style.current.smallPadding * 2
            width: parent.width
            radius: Style.current.radius
            color: isHovered ? Style.current.backgroundHover : Style.current.transparent

            StatusIdenticon {
                id: contactImage
                height: 40
                width: 40
                chatName: model.name
                chatType: model.chatType
                identicon: model.identicon
                anchors.left: parent.left
                anchors.leftMargin: Style.current.smallPadding
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                id: contactInfo
                text: model.chatType !== Constants.chatTypePublic ?
                    Emoji.parse(Utils.removeStatusEns(Utils.filterXSS(model.name)), "26x26") :
              "#" + Utils.filterXSS(model.name)
                anchors.right: unmuteButton.left
                anchors.rightMargin: Style.current.smallPadding
                elide: Text.ElideRight
                font.pixelSize: 15
                anchors.left: contactImage.right
                anchors.leftMargin: Style.current.padding
                anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: channelItem.isHovered = true
                onExited: channelItem.isHovered = false
            }

            StatusButton {
                id: unmuteButton
                type: "secondary"
                anchors.right: parent.right
                anchors.rightMargin: Style.current.smallPadding
                anchors.verticalCenter: parent.verticalCenter
                //% "Unmute"
                text: qsTrId("unmute")

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: {
                        channelItem.isHovered = true
                    }
                    onClicked: {
                        chatsModel.channelView.unmuteChatItem(model.id)
                    }
                }
            }
        }
    }
}
