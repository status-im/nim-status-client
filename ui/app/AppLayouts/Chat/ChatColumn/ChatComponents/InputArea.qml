import QtQuick 2.13
import "../../../../../imports"
import "../../../../../shared"
import "../../../../../shared/status"
import "../../components"

Item {
    property alias chatInput: chatInput

    id: inputArea
    height: chatInput.height

    Connections {
        target: chatsModel.messageView
        function onLoadingMessagesChanged(value) {
            if(value){
                loadingMessagesIndicator.active = true
            } else {
                 timer.setTimeout(function(){
                    loadingMessagesIndicator.active = false;
                }, 5000);
            }
        }
    }

    Loader {
        id: loadingMessagesIndicator
        active: chatsModel.messageView.loadingMessages
        sourceComponent: loadingIndicator
        anchors.right: parent.right
        anchors.bottom: chatInput.top
        anchors.rightMargin: Style.current.padding
        anchors.bottomMargin: Style.current.padding
    }

    Component {
        id: loadingIndicator
        LoadingAnimation {}
    }

    StatusChatInput {
        id: chatInput
        visible: {
            const community = chatsModel.communities.activeCommunity
            if (chatsModel.channelView.activeChannel.chatType === Constants.chatTypePrivateGroupChat) {
                return chatsModel.channelView.activeChannel.isMember
            }
            return !community.active ||
                    community.access === Constants.communityChatPublicAccess ||
                    community.admin ||
                    chatsModel.channelView.activeChannel.canPost
        }
        enabled: !isBlocked
        chatInputPlaceholder: isBlocked ?
                //% "This user has been blocked."
                qsTrId("this-user-has-been-blocked-") :
                //% "Type a message."
                qsTrId("type-a-message-")
        anchors.bottom: parent.bottom
        recentStickers: chatsModel.stickers.recent
        stickerPackList: chatsModel.stickers.stickerPacks
        chatType: chatsModel.channelView.activeChannel.chatType
        onSendTransactionCommandButtonClicked: {
            if (chatsModel.channelView.activeChannel.ensVerified) {
                txModalLoader.sourceComponent = cmpSendTransactionWithEns
            } else {
                txModalLoader.sourceComponent = cmpSendTransactionNoEns
            }
            txModalLoader.item.open()
        }
        onReceiveTransactionCommandButtonClicked: {
            txModalLoader.sourceComponent = cmpReceiveTransaction
            txModalLoader.item.open()
        }
        onStickerSelected: {
            chatsModel.stickers.send(hashId, packId)
        }
        onSendMessage: {
            if (chatInput.fileUrls.length > 0){
                chatsModel.sendImages(JSON.stringify(fileUrls));
            }
            let msg = chatsModel.plainText(Emoji.deparse(chatInput.textInput.text))
            if (msg.length > 0){
                msg = chatInput.interpretMessage(msg)
                chatsModel.messageView.sendMessage(msg, chatInput.isReply ? SelectedMessage.messageId : "", Utils.isOnlyEmoji(msg) ? Constants.emojiType : Constants.messageType, false, JSON.stringify(suggestionsObj));
                if(event) event.accepted = true
                sendMessageSound.stop();
                Qt.callLater(sendMessageSound.play);

                chatInput.textInput.clear();
                chatInput.textInput.textFormat = TextEdit.PlainText;
                chatInput.textInput.textFormat = TextEdit.RichText;
            }
        }
    }
}
