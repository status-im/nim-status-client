import QtQuick 2.13
import "../../../../../imports"
import "../../../../../shared"
import "../../../../../shared/status"
import ".."


Item {
    visible: {
        if (hideReadNotifications && model.read) {
            return false
        }

        return activityCenter.currentFilter === ActivityCenter.Filter.All ||
                (model.notificationType === Constants.activityCenterNotificationTypeMention && activityCenter.currentFilter === ActivityCenter.Filter.Mentions) ||
                (model.notificationType === Constants.activityCenterNotificationTypeReply && activityCenter.currentFilter === ActivityCenter.Filter.Replies)
    }
    width: parent.width
    height: visible ? messageNotificationContent.height : 0

    StatusIconButton {
        id: markReadBtn
        icon.name: "double-check"
        iconColor: Style.current.primary
        icon.width: 24
        icon.height: 24
        width: 32
        height: 32
        onClicked: chatsModel.activityNotificationList.markActivityCenterNotificationRead(model.id)
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: messageNotificationContent.verticalCenter
        z: 52

        StatusToolTip {
            visible: markReadBtn.hovered
            text: qsTr("Mark as Read")
            orientation: "left"
            x: - width - Style.current.padding
            y: markReadBtn.height / 2 - height / 2 + 4
        }
    }

    Item {
        id: messageNotificationContent
        width: parent.width
        height: childrenRect.height

        Message {
            id: notificationMessage
            anchors.right: undefined
            fromAuthor: model.message.fromAuthor
            chatId: model.message.chatId
            userName: model.message.userName
            alias: model.message.alias
            localName: model.message.localName
            message: model.message.message
            plainText: model.message.plainText
            identicon: model.message.identicon
            isCurrentUser: model.message.isCurrentUser
            timestamp: model.message.timestamp
            sticker: model.message.sticker
            contentType: model.message.contentType
            outgoingStatus: model.message.outgoingStatus
            responseTo: model.message.responseTo
            imageClick: imagePopup.openPopup.bind(imagePopup)
            messageId: model.message.messageId
            linkUrls: model.message.linkUrls
            communityId: model.message.communityId
            hasMention: model.message.hasMention
            stickerPackId: model.message.stickerPackId
            pinnedBy: model.message.pinnedBy
            pinnedMessage: model.message.isPinned
            activityCenterMessage: true
            read: model.read
            clickMessage: function (isProfileClick) {
                if (isProfileClick) {
                    const pk = model.message.fromAuthor
                    const userProfileImage = appMain.getProfileImage(pk)
                    return openProfilePopup(chatsModel.userNameOrAlias(pk), pk, userProfileImage || utilsModel.generateIdenticon(pk))
                }

                activityCenter.close()

                if (model.message.communityId) {
                    chatsModel.communities.setActiveCommunity(model.message.communityId)
                }

                chatsModel.channelView.setActiveChannel(model.message.chatId)
                positionAtMessage(model.message.messageId)
            }

            prevMessageIndex: previousNotificationIndex
            prevMsgTimestamp: previousNotificationTimestamp
        }

        Rectangle {
            anchors.top: notificationMessage.bottom
            anchors.bottom: badge.bottom
            anchors.bottomMargin: -Style.current.smallPadding
            width: parent.width
            color: model.read ? Style.current.transparent : Utils.setColorAlpha(Style.current.blue, 0.1)

        }

        ActivityChannelBadge {
            id: badge
            name: model.name
            chatId: model.chatId
            notificationType: model.notificationType
            responseTo: model.message.responseTo
            communityId: model.message.communityId
            anchors.top: notificationMessage.bottom
            anchors.left: parent.left
            anchors.leftMargin: 61 // TODO find a way to align with the text of the message
        }
    }
}
