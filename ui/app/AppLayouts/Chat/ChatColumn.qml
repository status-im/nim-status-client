import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtGraphicalEffects 1.0

import StatusQ.Core.Theme 0.1
import StatusQ.Components 0.1
import StatusQ.Controls 0.1
import StatusQ.Popups 0.1

import "../../../shared"
import "../../../shared/status"
import "../../../imports"
import "./components"
import "./ChatColumn"
import "./ChatColumn/ChatComponents"
import "./data"
import "../Wallet"

StackLayout {
    id: chatColumnLayout

    property alias pinnedMessagesPopupComponent: pinnedMessagesPopupComponent

    property int chatGroupsListViewCount: 0
    
    property bool isReply: false
    property bool isImage: false

    property bool isExtendedInput: isReply || isImage

    property bool isConnected: false
    property string contactToRemove: ""

    property var doNotShowAddToContactBannerToThose: ([])

    property var onActivated: function () {
        chatInput.textInput.forceActiveFocus(Qt.MouseFocusReason)
    }

    property string activeChatId: chatsModel.channelView.activeChannel.id
    property bool isBlocked: profileModel.contacts.isContactBlocked(activeChatId)
    property bool isContact: profileModel.contacts.isAdded(activeChatId)
    property bool contactRequestReceived: profileModel.contacts.contactRequestReceived(activeChatId)
    
    property string currentNotificationChatId
    property string currentNotificationCommunityId
    property alias input: chatInput

    property string hoveredMessage
    property string activeMessage

    function setHovered(messageId, hovered) {
        if (hovered) {
            hoveredMessage = messageId
        } else if (hoveredMessage === messageId) {
            hoveredMessage = ""
        }
    }

    function setMessageActive(messageId, active) {
        if (active) {
            activeMessage = messageId
        } else if (activeMessage === messageId) {
            activeMessage = ""
        }
    }

    Component.onCompleted: {
        chatInput.textInput.forceActiveFocus(Qt.MouseFocusReason)
    }

    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.minimumWidth: 300

    currentIndex:  chatsModel.channelView.activeChannelIndex > -1 && chatGroupsListViewCount > 0 ? 0 : 1

    Component {
        id: pinnedMessagesPopupComponent
        PinnedMessagesPopup {
            id: pinnedMessagesPopup
            onClosed: destroy()
        }
    }

    MessageContextMenu {
        id: messageContextMenu
    }

    StatusImageModal {
        id: imagePopup
    }

    property var idMap: ({})
    property var suggestionsObj: ([])

    function addSuggestionFromMessageList(i){
        const contactAddr = chatsModel.messageView.messageList.getMessageData(i, "publicKey");
        if(idMap[contactAddr]) return;
        suggestionsObj.push({
                                alias: chatsModel.messageView.messageList.getMessageData(i, "alias"),
                                ensName: chatsModel.messageView.messageList.getMessageData(i, "ensName"),
                                address: contactAddr,
                                identicon: chatsModel.messageView.messageList.getMessageData(i, "identicon"),
                                localNickname: chatsModel.messageView.messageList.getMessageData(i, "localName")
                            })
        chatInput.suggestionsList.append(suggestionsObj[suggestionsObj.length - 1]);
        idMap[contactAddr] = true;
    }

    function populateSuggestions() {
        chatInput.suggestionsList.clear()
        const len = chatsModel.suggestionList.rowCount()

        idMap = {}

        for (let i = 0; i < len; i++) {
            const contactAddr = chatsModel.suggestionList.rowData(i, "address");
            if(idMap[contactAddr]) continue;
            suggestionsObj.push({
                                    alias: chatsModel.suggestionList.rowData(i, "alias"),
                                    ensName: chatsModel.suggestionList.rowData(i, "ensName"),
                                    address: contactAddr,
                                    identicon: getProfileImage(contactAddr, false, false) || chatsModel.suggestionList.rowData(i, "identicon"),
                                    localNickname: chatsModel.suggestionList.rowData(i, "localNickname")
                                })

            chatInput.suggestionsList.append(suggestionsObj[suggestionsObj.length - 1]);
            idMap[contactAddr] = true;
        }
        const len2 = chatsModel.messageView.messageList.rowCount();
        for (let f = 0; f < len2; f++) {
            addSuggestionFromMessageList(f);
        }
    }

    function showReplyArea() {
        isReply = true;
        isImage = false;
        let replyMessageIndex = chatsModel.messageView.messageList.getMessageIndex(SelectedMessage.messageId);
        if (replyMessageIndex === -1) return;
        
        let userName = chatsModel.messageView.messageList.getMessageData(replyMessageIndex, "userName")
        let message = chatsModel.messageView.messageList.getMessageData(replyMessageIndex, "message")
        let identicon = chatsModel.messageView.messageList.getMessageData(replyMessageIndex, "identicon")

        chatInput.showReplyArea(userName, message, identicon)
    }

    function requestAddressForTransaction(address, amount, tokenAddress, tokenDecimals = 18) {
        amount =  utilsModel.eth2Wei(amount.toString(), tokenDecimals)
        chatsModel.transactions.requestAddress(activeChatId,
                                               address,
                                               amount,
                                               tokenAddress)
        txModalLoader.close()
    }
    function requestTransaction(address, amount, tokenAddress, tokenDecimals = 18) {
        amount =  utilsModel.eth2Wei(amount.toString(), tokenDecimals)
        chatsModel.transactions.request(activeChatId,
                                        address,
                                        amount,
                                        tokenAddress)
        txModalLoader.close()
    }

    Connections {
        target: profileModel.contacts
        onContactListChanged: {
            isBlocked = profileModel.contacts.isContactBlocked(activeChatId);
        }
        onContactBlocked: {
            chatsModel.messageView.removeMessagesByUserId(publicKey)
        }
    }

    Connections {
        target: chatsModel.channelView
        onActiveChannelChanged: {
            chatsModel.messageView.hideLoadingIndicator()
            SelectedMessage.reset();
            chatColumn.isReply = false;
        }
    }

    function clickOnNotification() {
        applicationWindow.show()
        applicationWindow.raise()
        applicationWindow.requestActivate()
        appMain.changeAppSection(Constants.chat)
        if (currentNotificationChatId) {
            chatsModel.channelView.setActiveChannel(currentNotificationChatId)
        } else if (currentNotificationCommunityId) {
            chatsModel.communities.setActiveCommunity(currentNotificationCommunityId)
        }
    }

    Connections {
        target: systemTray
        onMessageClicked: function () {
            clickOnNotification()
        }
    }

    Timer {
        id: timer
    }

    function positionAtMessage(messageId) {
        stackLayoutChatMessages.children[stackLayoutChatMessages.currentIndex].item.scrollToMessage(messageId)
    }
    
    ColumnLayout {
        spacing: 0

        StatusChatToolBar {
            id: topBar
            Layout.fillWidth: true

            property string chatId: chatsModel.channelView.activeChannel.id
            property string profileImage: appMain.getProfileImage(chatId) || ""

            chatInfoButton.title: {
              if (chatsModel.channelView.activeChannel.chatType === Constants.chatTypeOneToOne) {
                  return Utils.removeStatusEns(chatsModel.userNameOrAlias(chatsModel.channelView.activeChannel.id))
              }
              return chatsModel.channelView.activeChannel.name
            }
            chatInfoButton.subTitle: {
                switch (chatsModel.channelView.activeChannel.chatType) {
                    case Constants.chatTypeOneToOne:
                        return (profileModel.contacts.isAdded(topBar.chatId) ?
                            profileModel.contacts.contactRequestReceived(topBar.chatId) ?
                                qsTr("Contact") :
                                qsTr("Contact request pending") :
                            qsTr("Not a contact"))
                        break;
                    case Constants.chatTypePublic:
                        return qsTr("Public chat")
                    case Constants.chatTypePrivateGroupChat:
                        let cnt = chatsModel.channelView.activeChannel.members.rowCount();
                        if(cnt > 1) return qsTr("%1 members").arg(cnt);
                        return qsTr("1 member");
                        break;
                    case Constants.chatTypeCommunity:
                    default:
                        return ""
                        break;
                }
            }
            chatInfoButton.image.source: profileImage || chatsModel.channelView.activeChannel.identicon
            chatInfoButton.image.isIdenticon: !!!profileImage && chatsModel.channelView.activeChannel.identicon
            chatInfoButton.icon.color: chatsModel.channelView.activeChannel.color
            chatInfoButton.type: chatsModel.channelView.activeChannel.chatType
            chatInfoButton.pinnedMessagesCount: chatsModel.messageView.pinnedMessagesList.count
            chatInfoButton.muted: chatsModel.channelView.activeChannel.muted

            chatInfoButton.onPinnedMessagesCountClicked: openPopup(pinnedMessagesPopupComponent)
            chatInfoButton.onUnmute: chatsModel.channelView.unmuteChatItem(chatsModel.channelView.activeChannel.id)

            chatInfoButton.sensor.enabled: chatsModel.channelView.activeChannel.chatType !== Constants.chatTypePublic &&
                                           chatsModel.channelView.activeChannel.chatType !== Constants.chatTypeCommunity
            chatInfoButton.onClicked: {
                switch (chatsModel.channelView.activeChannel.chatType) {
                    case Constants.chatTypePrivateGroupChat:
                        openPopup(groupInfoPopupComponent, {channelType: GroupInfoPopup.ChannelType.ActiveChannel})
                        break;
                    case Constants.chatTypeOneToOne:
                        openProfilePopup(chatsModel.userNameOrAlias(chatsModel.channelView.activeChannel.id),
                                        chatsModel.channelView.activeChannel.id, profileImage || chatsModel.channelView.activeChannel.identicon,
                                        "", chatsModel.channelView.activeChannel.nickname)
                        break;
                }
            }

            notificationButton.visible: appSettings.isActivityCenterEnabled
            notificationCount: chatsModel.activityNotificationList.unreadCount

            onNotificationButtonClicked: activityCenter.open()

            popupMenu: ChatContextMenu {
                openHandler: {
                    chatItem = chatsModel.channelView.activeChannel
                }
            }
        }

        Rectangle {
            Component.onCompleted: {
                isConnected = chatsModel.isOnline
                if(!isConnected){
                    connectedStatusRect.visible = true
                }
            }

            id: connectedStatusRect
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            z: 60
            height: 40
            color: isConnected ? Style.current.green : Style.current.darkGrey
            visible: false
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                color: Style.current.white
                id: connectedStatusLbl
                text: isConnected ?
                          //% "Connected"
                          qsTrId("connected") :
                          //% "Disconnected"
                          qsTrId("disconnected")
            }

            Connections {
                target: chatsModel
                onOnlineStatusChanged: {
                    if (connected == isConnected) return;
                    isConnected = connected;
                    if(isConnected){
                        timer.setTimeout(function(){
                            connectedStatusRect.visible = false;
                        }, 5000);
                    } else {
                        connectedStatusRect.visible = true;
                    }
                }
            }
        }

        AddToContactBanner {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
        }

        StackLayout {
            id: stackLayoutChatMessages
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Repeater {
                model: chatsModel.messageView
                Loader {
                    active: false
                    sourceComponent: ChatMessages {
                        id: chatMessages
                        messageList: model.messages
                    }
                }
            }

            Connections {
                target: chatsModel.channelView
                onActiveChannelChanged: {
                    stackLayoutChatMessages.currentIndex = chatsModel.messageView.getMessageListIndex(chatsModel.channelView.activeChannelIndex)
                    if(stackLayoutChatMessages.currentIndex > -1 && !stackLayoutChatMessages.children[stackLayoutChatMessages.currentIndex].active){
                        stackLayoutChatMessages.children[stackLayoutChatMessages.currentIndex].active = true;
                    }
                }
            }
        }

        EmojiReactions {
            id: reactionModel
        }

        Connections {
            target: chatsModel.channelView
            onActiveChannelChanged: {
                chatInput.suggestions.hide();
                chatInput.textInput.forceActiveFocus(Qt.MouseFocusReason)
                populateSuggestions();
            }
        }

        Connections {
            target: chatsModel.messageView
            onMessagePushed: {
                addSuggestionFromMessageList(messageIndex);
            }
        }

        Connections {
            target: profileModel
            onContactsChanged: {
                populateSuggestions();
            }
        }

        ChatRequestMessage {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
            Layout.fillWidth: true
            Layout.bottomMargin: Style.current.bigPadding
        }

        Item {
            id: inputArea
            Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
            Layout.fillWidth: true
            Layout.preferredWidth: parent.width
            height: chatInput.height
            Layout.preferredHeight: height

            Connections {
                target: chatsModel.messageView
                onLoadingMessagesChanged:
                    if(value){
                        loadingMessagesIndicator.active = true
                    } else {
                         timer.setTimeout(function(){ 
                            loadingMessagesIndicator.active = false;
                        }, 5000);
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
                    if (chatsModel.channelView.activeChannel.chatType === Constants.chatTypePrivateGroupChat) {
                        return chatsModel.channelView.activeChannel.isMember
                    }
                    if (chatsModel.channelView.activeChannel.chatType === Constants.chatTypeOneToOne) {
                        return isContact && contactRequestReceived
                    }
                    const community = chatsModel.communities.activeCommunity
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
    }

    EmptyChat {}

    Loader {
        id: txModalLoader
        function close() {
            if (!this.item) {
                return
            }
            this.item.close()
            this.closed()
        }
        function closed() {
            this.sourceComponent = undefined
        }
    }
    Component {
        id: cmpSendTransactionNoEns
        ChatCommandModal {
            id: sendTransactionNoEns
            onClosed: {
                txModalLoader.closed()
            }
            sendChatCommand: chatColumnLayout.requestAddressForTransaction
            isRequested: false
            //% "Send"
            commandTitle: qsTrId("command-button-send")
            title: commandTitle
            //% "Request Address"
            finalButtonLabel: qsTrId("request-address")
            selectRecipient.selectedRecipient: {
                return {
                    address: Constants.zeroAddress, // Setting as zero address since we don't have the address yet
                    alias: chatsModel.channelView.activeChannel.alias,
                    identicon: chatsModel.channelView.activeChannel.identicon,
                    name: chatsModel.channelView.activeChannel.name,
                    type: RecipientSelector.Type.Contact
                }
            }
            selectRecipient.selectedType: RecipientSelector.Type.Contact
            selectRecipient.readOnly: true
        }
    }
    Component {
        id: cmpReceiveTransaction
        ChatCommandModal {
            id: receiveTransaction
            onClosed: {
                txModalLoader.closed()
            }
            sendChatCommand: chatColumnLayout.requestTransaction
            isRequested: true
            //% "Request"
            commandTitle: qsTrId("wallet-request")
            title: commandTitle
            //% "Request"
            finalButtonLabel: qsTrId("wallet-request")
            selectRecipient.selectedRecipient: {
                return {
                    address: Constants.zeroAddress, // Setting as zero address since we don't have the address yet
                    alias: chatsModel.channelView.activeChannel.alias,
                    identicon: chatsModel.channelView.activeChannel.identicon,
                    name: chatsModel.channelView.activeChannel.name,
                    type: RecipientSelector.Type.Contact
                }
            }
            selectRecipient.selectedType: RecipientSelector.Type.Contact
            selectRecipient.readOnly: true
        }
    }
    Component {
        id: cmpSendTransactionWithEns
        SendModal {
            id: sendTransactionWithEns
            onOpened: {
                walletModel.gasView.getGasPricePredictions()
            }
            onClosed: {
                txModalLoader.closed()
            }
            selectRecipient.readOnly: true
            selectRecipient.selectedRecipient: {
                return {
                    address: "",
                    alias: chatsModel.channelView.activeChannel.alias,
                    identicon: chatsModel.channelView.activeChannel.identicon,
                    name: chatsModel.channelView.activeChannel.name,
                    type: RecipientSelector.Type.Contact,
                    ensVerified: true
                }
            }
            selectRecipient.selectedType: RecipientSelector.Type.Contact
        }
    }

    ActivityCenter {
        id: activityCenter
        height: chatColumnLayout.height - (topBar.height * 2) // TODO get screen size
        y: topBar.height
    }
}

/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";height:770;width:800}
}
##^##*/
