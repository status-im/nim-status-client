import QtQuick 2.13
import QtQuick.Controls 2.13
import QtGraphicalEffects 1.13
import QtQml.Models 2.13
import QtQuick.Layouts 1.13
import "../../../imports"
import "../../../shared"
import "../../../shared/status"
import "../Chat/data"
import "../Chat/ChatColumn"
import "../Chat/components"

ScrollView {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentHeight: chatLogView.contentHeight + 140
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    
    property var onActivated: function () {
        chatsModel.setActiveChannelToTimeline()
        statusUpdateInput.textInput.forceActiveFocus(Qt.MouseFocusReason)
    }

    Component.onCompleted: {
        statusUpdateInput.textInput.forceActiveFocus(Qt.MouseFocusReason)
    }

    function openProfilePopup(userNameParam, fromAuthorParam, identiconParam, textParam, nicknameParam, parentPopup){
        var popup = profilePopupComponent.createObject(root);
        if(parentPopup){
            popup.parentPopup = parentPopup;
        }
        popup.openPopup(profileModel.profile.pubKey !== fromAuthorParam, userNameParam, fromAuthorParam, identiconParam, textParam, nicknameParam);
    }


    MessageContextMenu {
        id: messageContextMenu
    }

    StatusImageModal {
        id: imagePopup
    }

    EmojiReactions {
        id: reactionModel
    }

    property Component profilePopupComponent: ProfilePopup {
        id: profilePopup
        height: 450
        onClosed: {
            if(profilePopup.parentPopup){
                profilePopup.parentPopup.close();
            }
            destroy()
        }
    }

    Item {
        id: timelineContainer
        width: 624
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        StatusChatInput {
            id: statusUpdateInput
            anchors.top: parent.top
            anchors.topMargin: 40
            chatType: Constants.chatTypeStatusUpdate
            imageErrorMessageLocation: StatusChatInput.ImageErrorMessageLocation.Bottom
            z: 1
            onSendMessage: {
                if (statusUpdateInput.fileUrls.length > 0){
                    statusUpdateInput.fileUrls.forEach(url => {
                        chatsModel.sendImage(url, true);
                    })
                }
                var msg = chatsModel.plainText(Emoji.deparse(statusUpdateInput.textInput.text))
                if (msg.length > 0){
                    msg = statusUpdateInput.interpretMessage(msg)
                    chatsModel.messageView.sendMessage(msg, "", Utils.isOnlyEmoji(msg) ? Constants.emojiType : Constants.messageType, true, "");
                    statusUpdateInput.textInput.text = "";
                    if(event) event.accepted = true
                    sendMessageSound.stop()
                    Qt.callLater(sendMessageSound.play);
                }
            }
        }

        EmptyTimeline {
            id: emptyTimeline
            anchors.top: statusUpdateInput.bottom
            anchors.topMargin: 40
            anchors.horizontalCenter: parent.horizontalCenter
            visible: chatsModel.messageView.messageList.rowCount() === 0
        }

        ListView {
            id: chatLogView
            anchors.top: statusUpdateInput.bottom
            anchors.topMargin: Style.current.bigPadding
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: Style.current.halfPadding
            flickDeceleration: 10000
            interactive: false

            model: messageListDelegate
            section.property: "sectionIdentifier"
            section.criteria: ViewSection.FullString

            Connections {
                target: chatsModel.messageView
                onMessagesLoaded: {
                    Qt.callLater(chatLogView.positionViewAtBeginning)
                }
            }
        }

        DelegateModelGeneralized {
            id: messageListDelegate
            lessThan: [
                function(left, right) { return left.clock > right.clock }
            ]

            model: chatsModel.messageView.messageList
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
                outgoingStatus: model.outgoingStatus
                responseTo: model.responseTo
                authorCurrentMsg: msgDelegate.ListView.section
                authorPrevMsg: msgDelegate.ListView.previousSection
                imageClick: imagePopup.openPopup.bind(imagePopup)
                messageId: model.messageId
                emojiReactions: model.emojiReactions
                isStatusUpdate: true
                // This is used in order to have access to the previous message and determine the timestamp
                // we can't rely on the index because the sequence of messages is not ordered on the nim side
                prevMessageIndex: {
                    // This is used in order to have access to the previous message and determine the timestamp
                    // we can't rely on the index because the sequence of messages is not ordered on the nim side
                    if(msgDelegate.DelegateModel.itemsIndex > 0){
                        return messageListDelegate.items.get(msgDelegate.DelegateModel.itemsIndex - 1).model.index
                    }
                    return -1;
                }
                timeout: model.timeout
            }
        }
    }
}
