import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "./"
import "../../../../shared"
import "../../../../imports"

import StatusQ.Popups 0.1

StatusPopupMenu {

    property var chatItem

    StatusMenuItem {
        id: viewProfileMenuItem
        text: {
            if (chatItem) {
                switch (chatItem.chatType) {
                    case Constants.chatTypeOneToOne:
                      return qsTr("View Profile")
                      break;
                    case Constants.chatTypePrivateGroupChat:
                      return qsTr("View Group")
                      break;
                }
            }
            return ""
        }
        icon.name: "group-chat"
        enabled: chatItem && 
            (chatItem.chatType === Constants.chatTypeOneToOne ||
            chatItem.chatType === Constants.chatTypePrivateGroupChat)
        onTriggered: {
            if (chatItem.chatType === Constants.chatTypeOneToOne) {
                const userProfileImage = appMain.getProfileImage(chatItem.id)
                return openProfilePopup(
                    chatItem.name,
                    chatItem.id,
                    userProfileImage || chatItem.identicon,
                    "",
                    chatItem.name
                )
            }
            if (chatItem.chatType === Constants.chatTypePrivateGroupChat) {
                return openPopup(groupInfoPopupComponent, {channelType: GroupInfoPopup.ChannelType.ContextChannel})
            }
        }
    }

    StatusMenuSeparator {
        visible: viewProfileMenuItem.enabled
    }

    StatusMenuItem {
        text: chatItem && chatItem.muted ? 
              qsTr("Unmute chat") : 
              qsTr("Mute chat")
        icon.name: "notification"
        enabled: chatItem && chatItem.chatType !== Constants.chatTypePrivateGroupChat
        onTriggered: {
            if (chatItem && chatItem.muted) {
                return chatsModel.channelView.unmuteChatItem(chatItem.id)
            }
            chatsModel.channelView.muteChatItem(chatItem.id)
        }
    }

    StatusMenuItem {
        text: qsTr("Mark as Read")
        icon.name: "checkmark-circle"
        enabled: chatItem && chatItem.chatType !== Constants.chatTypePrivateGroupChat
        onTriggered: chatsModel.channelView.markChatItemAsRead(chatItem.id)
    }

    StatusMenuItem {
        text: qsTr("Clear history")
        icon.name: "close-circle"
        onTriggered: chatsModel.channelView.clearChatHistory(chatItem.id)
    }

    StatusMenuItem {
        text: qsTr("Edit Channel")
        icon.name: "edit"
        enabled: chatsModel.communities.activeCommunity.active &&
            chatsModel.communities.activeCommunity.admin
        onTriggered: openPopup(editChannelPopup, {
            communityId: chatsModel.communities.activeCommunity.id,
            channel: chatItem
        })
    }

    StatusMenuSeparator {
        visible: deleteOrLeaveMenuItem.enabled
    }

    StatusMenuItem {
        id: deleteOrLeaveMenuItem
        text: chatItem && chatItem.chatType === Constants.chatTypeOneToOne ? 
            qsTr("Delete chat") : 
            qsTr("Leave chat")
        icon.name: chatItem && chatItem.chatType === Constants.chatTypeOneToOne ? "delete" : "arrow-right"
        icon.width: chatItem && chatItem.chatType === Constants.chatTypeOneToOne ? 18 : 14
        iconRotation: chatItem && chatItem.chatType === Constants.chatTypeOneToOne ? 0 : 180

        type: StatusMenuItem.Type.Danger
        onTriggered: {
            let label = chatItem && chatItem.chatType === Constants.chatTypeOneToOne ? 
                qsTr("Delete chat") :
                qsTr("Leave chat")
            openPopup(deleteChatConfirmationDialogComponent, { 
                title: label,
                confirmButtonLabel: label,
                chatId: chatItem.id 
            })
        }

        enabled: !chatsModel.communities.activeCommunity.active
    }

    Component {
        id: deleteChatConfirmationDialogComponent
        ConfirmationDialog {
            property string chatId
            btnType: "warn"
            confirmationText: qsTr("Are you sure you want to leave this chat?")
            onClosed: {
                destroy()
            }
            onConfirmButtonClicked: {
                chatsModel.channelView.leaveChat(chatId)
                close();
            }
        }
    }
}
