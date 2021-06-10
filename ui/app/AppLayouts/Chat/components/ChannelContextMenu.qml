import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "./"
import "../../../../shared"
import "../../../../imports"

PopupMenu {
    property int channelIndex
    property var contextChannel: ({})

    id: channelContextMenu
    width: 175
    subMenuIcons: [
        /* { */
        /*     source:  Qt.resolvedUrl("../../../img/bell.svg"), */
        /*     width: 16, */
        /*     height: 16 */
        /* }, */
        {
            source: Qt.resolvedUrl("../../../img/fetch.svg"),
            width: 16,
            height: 16
        }
    ]

    function openMenu(channel, index, x, y) {
        channelContextMenu.contextChannel = channel
        if (index !== undefined) {
            channelContextMenu.channelIndex = index
        }
        channelContextMenu.popup(x, y)
    }

    Action {
        id: viewProfileButton
        enabled: channelContextMenu.contextChannel.chatType !== Constants.chatTypePublic
        text: {
            if (channelContextMenu.contextChannel.chatType === Constants.chatTypeOneToOne) {
                //% "View Profile"
                return qsTrId("view-profile")
            }
            if (channelContextMenu.contextChannel.chatType === Constants.chatTypePrivateGroupChat) {
                //% "View Group"
                return qsTrId("view-group")
            }
            //% "Share Chat"
            return qsTrId("share-chat")
        }
        icon.source: "../../../img/group.svg"
        icon.width: 16
        icon.height: 16
        onTriggered: {
            if (channelContextMenu.contextChannel.chatType === Constants.chatTypeOneToOne) {
                const userProfileImage = appMain.getProfileImage(channelContextMenu.contextChannel.id)
                return openProfilePopup(
                  channelContextMenu.contextChannel.name,
                  channelContextMenu.contextChannel.id,
                  userProfileImage || channelContextMenu.contextChannel.identicon
                )
            }
            if (channelContextMenu.contextChannel.chatType === Constants.chatTypePrivateGroupChat) {
                return openPopup(groupInfoPopupComponent, {channel: channelContextMenu.contextChannel})
            }
        }
    }

    Separator {
        visible: viewProfileButton.enabled
    }

    Action {
        text: channelContextMenu.contextChannel.muted ?
                  //% "Unmute chat"
                  qsTrId("unmute-chat") :
                  //% "Mute chat"
                  qsTrId("mute-chat")
        icon.source: "../../../img/bell.svg"
        icon.width: 16
        icon.height: 16
        onTriggered: {
            if (chatsModel.channelIsMuted(channelContextMenu.channelIndex)) {
                chatsModel.unmuteChannel(channelContextMenu.channelIndex)
                return
            }
            chatsModel.muteChannel(channelContextMenu.channelIndex)
        }
    }

    Action {
        //% "Mark as Read"
        text: qsTrId("mark-as-read")
        icon.source: "../../../img/check-circle.svg"
        icon.width: 16
        icon.height: 16
        onTriggered: {
            chatsModel.markAllChannelMessagesReadByIndex(channelContextMenu.channelIndex)
        }
    }

    Action {
        enabled: profileModel.fleets.fleet == Constants.waku_prod || profileModel.fleets.fleet == Constants.waku_test
        text: qsTr("WakuV2 - requestAllHistoricMessages")
        onTriggered: chatsModel.requestAllHistoricMessages()
    }


    // FetchMoreMessages {}  // TODO: disabling it temporarily because wakuext_syncChatFromSyncedFrom does not support specifying a date range
    Action {
        //% "Clear History"
        text: qsTrId("clear-history")
        icon.source: "../../../img/close.svg"
        icon.width: 16
        icon.height: 16
        onTriggered: chatsModel.clearChatHistoryByIndex(channelContextMenu.channelIndex)
    }

    Separator {
        visible: deleteAction.enabled
    }
    Action {
        id: deleteAction
        text: {
            if (channelContextMenu.contextChannel.chatType === Constants.chatTypeOneToOne) {
                //% "Delete chat"
                return qsTrId("delete-chat")
            }
            if (channelContextMenu.contextChannel.chatType === Constants.chatTypePrivateGroupChat) {
                //% "Leave group"
                return qsTrId("leave-group")
            }
            //% "Leave chat"
            return qsTrId("leave-chat")
        }
        icon.source: {
            if (channelContextMenu.contextChannel.chatType === Constants.chatTypeOneToOne) {
                return "../../../img/delete.svg"
            }
            return "../../../img/leave_chat.svg"
        }
        icon.width: 16
        icon.height: 16
        icon.color: Style.current.red
        onTriggered: openPopup(deleteChatConfirmationDialogComponent)
        enabled: !chatsModel.communities.activeCommunity.active
    }

    Component {
        id: deleteChatConfirmationDialogComponent
        ConfirmationDialog {
            btnType: "warn"
            confirmationText: qsTr("Are you sure you want to leave this chat?")
            onClosed: {
                destroy()
            }
            onConfirmButtonClicked: {
                chatsModel.leaveChatByIndex(channelContextMenu.channelIndex)
                close();
            }
        }
    }
}

