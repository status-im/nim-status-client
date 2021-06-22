import QtQuick 2.13
import "../../../../../imports"
import "../../../../../shared"
import "../../../../../shared/status"
import ".."

Rectangle {
    property string chatId: ""
    property string name: "channelName"
    property string identicon
    property string responseTo
    property int notificationType
    property int chatType: chatsModel.channelView.chats.getChannelType(chatId)
    property int realChatType: {
        if (chatType === Constants.chatTypeCommunity) {
            // TODO add a check for private community chats once it is created
            return Constants.chatTypePublic
        }
        return chatType
    }

    property string profileImage: realChatType === Constants.chatTypeOneToOne ? appMain.getProfileImage(chatId) || ""  : ""

    id: wrapper
    height: 24
    width: childrenRect.width + 12
    color: Style.current.transparent
    border.color: Style.current.borderSecondary
    border.width: 1
    radius: 11

    Loader {
        active: true
        height: parent.height
        sourceComponent: {
            switch (model.notificationType) {
            case Constants.activityCenterNotificationTypeMention: return channelComponent
            case Constants.activityCenterNotificationTypeReply: return replyComponent
            default: return channelComponent
            }
        }
    }

    Component {
        id: replyComponent

        Item {
            property int replyMessageIndex: chatsModel.getMessageIndex(chatId, responseTo)
            property string repliedMessageContent: replyMessageIndex > -1 ? chatsModel.messageView.getMessageData(chatId, replyMessageIndex, "message") : "";


            onReplyMessageIndexChanged: {
                wrapper.visible = replyMessageIndex > -1
            }

            width: childrenRect.width
            height: parent.height
            SVGImage {
                id: replyIcon
                width: 16
                height: 16
                source: "../../../../img/reply-small-arrow.svg"
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter:parent.verticalCenter
            }

            StyledTextEdit {
                text: Utils.getReplyMessageStyle(Emoji.parse(Utils.linkifyAndXSS(repliedMessageContent), Emoji.size.small), false, appSettings.useCompactMode)
                textFormat: Text.RichText
                height: 18
                width: implicitWidth > 300 ? 300 : implicitWidth
                clip: true
                anchors.left: replyIcon.right
                anchors.leftMargin: 4
                color: Style.current.secondaryText
                font.weight: Font.Medium
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
                selectByMouse: true
            }
        }
    }

    Component {
        id: channelComponent

        Item {
            width: childrenRect.width
            height: parent.height

            Connections {
                enabled: realChatType === Constants.chatTypeOneToOne
                target: profileModel.contacts.list
                onContactChanged: {
                    if (pubkey === wrapper.chatId) {
                        wrapper.profileImage = appMain.getProfileImage(wrapper.chatId)
                    }
                }
            }

            SVGImage {
                id: channelIcon
                width: 16
                height: 16
                fillMode: Image.PreserveAspectFit
                source: "../../../../img/channel-icon-" + (wrapper.realChatType === Constants.chatTypePublic ? "public-chat.svg" : "group.svg")
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter:parent.verticalCenter
            }

            StatusIdenticon {
                id: contactImage
                height: 16
                width: 16
                chatId: wrapper.chatId
                chatName: wrapper.name
                chatType: wrapper.realChatType
                identicon: wrapper.profileImage || wrapper.identicon
                anchors.left: channelIcon.right
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                letterSize: 11
            }

            StyledText {
                id: contactInfo
                text: wrapper.realChatType !== Constants.chatTypePublic ?
                          Emoji.parse(Utils.removeStatusEns(Utils.filterXSS(wrapper.name))) :
                          "#" + Utils.filterXSS(wrapper.name)
                anchors.left: contactImage.right
                anchors.leftMargin: 4
                color: Style.current.secondaryText
                font.weight: Font.Medium
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
