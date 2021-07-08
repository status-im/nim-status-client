import QtQuick 2.13
import Qt.labs.platform 1.1
import QtQuick.Controls 2.13
import QtQuick.Window 2.13
import QtQuick.Layouts 1.13
import QtQml.Models 2.13
import QtGraphicalEffects 1.13
import QtQuick.Dialogs 1.3
import "../../../../shared"
import "../../../../shared/status"
import "../../../../imports"
import "../components"
import "./samples/"
import "./MessageComponents"
import "../ContactsColumn"
import "../CommunityComponents"

SplitView {
    id: svRoot
    property alias chatLogView: chatLogView
    property alias scrollToMessage: chatLogView.scrollToMessage
    
    property var messageList: MessagesData {}
    property bool loadingMessages: false
    property real scrollY: chatLogView.visibleArea.yPosition * chatLogView.contentHeight
    property int newMessages: 0
    property var currentTime

    Layout.fillWidth: true
    Layout.fillHeight: true

    handle: SplitViewHandle { implicitWidth: 5}

    ScrollView {
        id: root

        contentItem: chatLogView
        
        SplitView.fillWidth: true
        SplitView.minimumWidth: 200

        ScrollBar.vertical.policy: chatLogView.contentHeight > chatLogView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ListView {
            id: chatLogView
            anchors.fill: parent
            anchors.bottomMargin: Style.current.bigPadding
            spacing: appSettings.useCompactMode ? 0 : 4
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: {
                if (utilsModel.getOs() === Constants.windows) {
                    return 5000
                }
                return 10000
            }
            verticalLayoutDirection: ListView.BottomToTop

            // This header and Connections is to create an invisible padding so that the chat identifier is at the top
            // The Connections is necessary, because doing the check inside the header created a binding loop (the contentHeight includes the header height
            // If the content height is smaller than the full height, we "show" the padding so that the chat identifier is at the top, otherwise we disable the Connections
            header: Item {
                height: 0
                width: chatLogView.width
            }
            function checkHeaderHeight() {
                if (!chatLogView.headerItem) {
                    return
                }

                if (chatLogView.contentItem.height - chatLogView.headerItem.height < chatLogView.height) {
                    chatLogView.headerItem.height = chatLogView.height - (chatLogView.contentItem.height - chatLogView.headerItem.height) - 36
                } else {
                    chatLogView.headerItem.height = 0
                }
            }

            property var scrollToMessage: function (messageId) {
                let item
                for (let i = 0; i < messageListDelegate.count; i++) {
                    item = messageListDelegate.items.get(i)
                    if (item.model.messageId === messageId) {
                        chatLogView.positionViewAtIndex(i, ListView.Center)
                        return
                    }
                }
            }

            Connections {
                id: contentHeightConnection
                enabled: true
                target: chatLogView
                onContentHeightChanged: {
                    chatLogView.checkHeaderHeight()
                }
                onHeightChanged: {
                    chatLogView.checkHeaderHeight()
                }
            }

            Timer {
                id: timer
            }

            Button {
                readonly property int buttonPadding: 5

                id: scrollDownButton
                visible: false
                height: 32
                width: nbMessages.width + arrowImage.width + 2 * Style.current.halfPadding + (nbMessages.visible ? scrollDownButton.buttonPadding : 0)
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.rightMargin: Style.current.padding
                background: Rectangle {
                    color: Style.current.buttonSecondaryColor
                    border.width: 0
                    radius: 16
                }
                onClicked: {
                    newMessages = 0
                    scrollDownButton.visible = false
                    chatLogView.scrollToBottom(true)
                }

                StyledText {
                    id: nbMessages
                    visible: newMessages > 0
                    width: visible ? implicitWidth : 0
                    text: newMessages
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    color: Style.current.pillButtonTextColor
                    font.pixelSize: 15
                    anchors.leftMargin: Style.current.halfPadding
                }

                SVGImage {
                    id: arrowImage
                    width: 24
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: nbMessages.right
                    source: "../../../img/leave_chat.svg"
                    anchors.leftMargin: nbMessages.visible ? scrollDownButton.buttonPadding : 0
                    rotation: -90

                    ColorOverlay {
                        anchors.fill: parent
                        source: parent
                        color: Style.current.pillButtonTextColor
                    }
                }

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onPressed: mouse.accepted = false
                }
            }

            function scrollToBottom(force, caller) {
                if (!force && !chatLogView.atYEnd) {
                    // User has scrolled up, we don't want to scroll back
                    return false
                }
                if (caller && caller !== chatLogView.itemAtIndex(chatLogView.count - 1)) {
                    // If we have a caller, only accept its request if it's the last message
                    return false
                }
                // Call this twice and with a timer since the first scroll to bottom might have happened before some stuff loads
                // meaning that the scroll will not actually be at the bottom on switch
                // Add a small delay because images, even though they say they say they are loaed, they aren't shown yet
                Qt.callLater(chatLogView.positionViewAtBeginning)
                timer.setTimeout(function() {
                    Qt.callLater(chatLogView.positionViewAtBeginning)
                }, 100);
                return true
            }

            Connections {
                target: chatsModel

                onAppReady: {
                    chatLogView.scrollToBottom(true)
                }
            }

            Connections {
                target: chatsModel.messageView
                onMessagesLoaded: {
                    loadingMessages = false;
                }

                onSendingMessage: {
                    chatLogView.scrollToBottom(true)
                }

                onSendingMessageFailed: {
                    sendingMsgFailedPopup.open();
                }

                onNewMessagePushed: {
                    if (!chatLogView.scrollToBottom()) {
                        newMessages++
                    }
                }

                onMessageNotificationPushed: function(chatId, msg, messageType, chatType, timestamp, identicon, username, hasMention, isAddedContact, channelName) {
                    if (messageType == Constants.editType) return;
                    if (appSettings.notificationSetting == Constants.notifyAllMessages || 
                        (appSettings.notificationSetting == Constants.notifyJustMentions && hasMention)) {
                        if (chatId === chatsModel.channelView.activeChannel.id && applicationWindow.active === true) {
                            // Do not show the notif if we are in the channel already and the window is active and focused
                            return
                        }

                        chatColumnLayout.currentNotificationChatId = chatId
                        chatColumnLayout.currentNotificationCommunityId = null

                        let name;
                        if (appSettings.notificationMessagePreviewSetting === Constants.notificationPreviewAnonymous) {
                            name = "Status"
                        } else if (chatType === Constants.chatTypePublic) {
                            name = chatId
                        } else {
                            name = chatType === Constants.chatTypePrivateGroupChat ? Utils.filterXSS(channelName) : Utils.removeStatusEns(username)
                        }

                        let message;
                        if (appSettings.notificationMessagePreviewSetting > Constants.notificationPreviewNameOnly) {
                            switch(messageType){
                            //% "Image"
                            case Constants.imageType: message = qsTrId("image"); break
                            //% "Sticker"
                            case Constants.stickerType: message = qsTrId("sticker"); break
                            default: message = msg // don't parse emojis here as it emits HTML
                            }
                        } else {
                            //% "You have a new message"
                            message = qsTrId("you-have-a-new-message")
                        }

                        currentlyHasANotification = true
                        if (appSettings.useOSNotifications && systemTray.supportsMessages) {
                            systemTray.showMessage(name,
                                                message,
                                                SystemTrayIcon.NoIcon,
                                                Constants.notificationPopupTTL)
                        } else {
                            notificationWindow.notifyUser(chatId, name, message, chatType, identicon, chatColumnLayout.clickOnNotification)
                        }
                    }
                }
            }

            Connections {
                target: chatsModel.communities

                onMembershipRequestChanged: function (communityId, communityName, accepted) {
                    chatColumnLayout.currentNotificationChatId = null
                    chatColumnLayout.currentNotificationCommunityId = communityId
                    systemTray.showMessage("Status",
                                        accepted ? qsTr("You have been accepted into the ‘%1’ community").arg(communityName) :
                                                    qsTr("Your request to join the ‘%1’ community was declined").arg(communityName),
                                        SystemTrayIcon.NoIcon,
                                        Constants.notificationPopupTTL)
                }

                onMembershipRequestPushed: function (communityId, communityName, pubKey) {
                    chatColumnLayout.currentNotificationChatId = null
                    chatColumnLayout.currentNotificationCommunityId = communityId
                    systemTray.showMessage(qsTr("New membership request"),
                                        qsTr("%1 asks to join ‘%2’").arg(Utils.getDisplayName(pubKey)).arg(communityName),
                                        SystemTrayIcon.NoIcon,
                                        Constants.notificationPopupTTL)
                }
            }

            property var loadMsgs : Backpressure.oneInTime(chatLogView, 500, function() {
                if(loadingMessages) return;
                loadingMessages = true;
                chatsModel.messageView.loadMoreMessages();
            });

            onContentYChanged: {
                scrollDownButton.visible = (contentHeight - (scrollY + height) > 400)
                if(scrollY < 500){
                    loadMsgs();
                }
            }


            model: messageListDelegate
            section.property: "sectionIdentifier"
            section.criteria: ViewSection.FullString

        }

        MessageDialog {
            id: sendingMsgFailedPopup
            standardButtons: StandardButton.Ok
            //% "Failed to send message."
            text: qsTrId("failed-to-send-message-")
            icon: StandardIcon.Critical
        }

        DelegateModelGeneralized {
            id: messageListDelegate
            lessThan: [
                function(left, right) { return left.clock > right.clock }
            ]

            model: messageList

            delegate: Message {
                id: msgDelegate
                fromAuthor: model.fromAuthor
                chatId: model.chatId
                userName: model.userName
                alias: model.alias
                localName: model.localName
                message: model.message
                plainText: model.plainText
                identicon: model.identicon
                isCurrentUser: model.isCurrentUser
                timestamp: model.timestamp
                sticker: model.sticker
                contentType: model.contentType
                replaces: model.replaces
                isEdited: model.isEdited
                outgoingStatus: model.outgoingStatus
                responseTo: model.responseTo
                authorCurrentMsg: msgDelegate.ListView.section
                // The previous message is actually the nextSection since we reversed the list order
                authorPrevMsg: msgDelegate.ListView.nextSection
                imageClick: imagePopup.openPopup.bind(imagePopup)
                messageId: model.messageId
                emojiReactions: model.emojiReactions
                linkUrls: model.linkUrls
                communityId: model.communityId
                hasMention: model.hasMention
                stickerPackId: model.stickerPackId
                pinnedMessage: model.isPinned
                pinnedBy: model.pinnedBy
                gapFrom: model.gapFrom
                gapTo: model.gapTo

                // This is used in order to have access to the previous message and determine the timestamp
                // we can't rely on the index because the sequence of messages is not ordered on the nim side
                prevMessageIndex: {
                    // This is used in order to have access to the previous message and determine the timestamp
                    // we can't rely on the index because the sequence of messages is not ordered on the nim side
                    if (msgDelegate.DelegateModel.itemsIndex < messageListDelegate.items.count - 1) {
                        return messageListDelegate.items.get(msgDelegate.DelegateModel.itemsIndex + 1).model.index
                    }
                    return -1;
                }
                nextMessageIndex: {
                    if (msgDelegate.DelegateModel.itemsIndex <= 1) {
                        return -1
                    }
                    return messageListDelegate.items.get(msgDelegate.DelegateModel.itemsIndex - 1).model.index
                }
                scrollToBottom: chatLogView.scrollToBottom
                timeout: model.timeout
            }
        }
    }

    Loader {
        property int defaultWidth: 250
        SplitView.preferredWidth: active ? defaultWidth : 0
        SplitView.minimumWidth: active ? 50 : 0
        active: showUsers && chatsModel.channelView.activeChannel.chatType !== Constants.chatTypeOneToOne
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        sourceComponent:appSettings.communitiesEnabled && chatsModel.communities.activeCommunity.active ? communityUserListComponent : userListComponent
    }

    Component {
        id: communityUserListComponent
        CommunityUserList { }
    }

    Component {
        id: userListComponent
        UserList { }
    }
    

    
}

/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/
