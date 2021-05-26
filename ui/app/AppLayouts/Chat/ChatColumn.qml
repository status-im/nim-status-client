import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtGraphicalEffects 1.0
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
        inputArea.chatInput.textInput.forceActiveFocus(Qt.MouseFocusReason)
    }

    property string activeChatId: chatsModel.activeChannel.id
    property bool isBlocked: profileModel.contacts.isContactBlocked(activeChatId)
    property bool isContact: profileModel.contacts.isAdded(activeChatId)
    
    property alias input: inputArea.chatInput

    property string currentNotificationChatId
    property string currentNotificationCommunityId

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
        inputArea.chatInput.textInput.forceActiveFocus(Qt.MouseFocusReason)
    }

    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.minimumWidth: 300

    currentIndex:  chatsModel.activeChannelIndex > -1 && chatGroupsListViewCount > 0 ? 0 : 1

    Component {
        id: pinnedMessagesPopupComponent
        PinnedMessagesPopup {
            id: pinnedMessagesPopup
            onClosed: destroy()
        }
    }

    StatusImageModal {
        id: imagePopup
    }

    MessageContextMenu {
        id: messageContextMenu
    }

    property var idMap: ({})
    property var suggestionsObj: ([])

    function addSuggestionFromMessageList(i){
        const contactAddr = chatsModel.messageList.getMessageData(i, "publicKey");
        if(idMap[contactAddr]) return;
        suggestionsObj.push({
                                alias: chatsModel.messageList.getMessageData(i, "alias"),
                                ensName: chatsModel.messageList.getMessageData(i, "ensName"),
                                address: contactAddr,
                                identicon: chatsModel.messageList.getMessageData(i, "identicon"),
                                localNickname: chatsModel.messageList.getMessageData(i, "localName")
                            })
        inputArea.chatInput.suggestionsList.append(suggestionsObj[suggestionsObj.length - 1]);
        idMap[contactAddr] = true;
    }

    function populateSuggestions() {
        inputArea.chatInput.suggestionsList.clear()
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

            inputArea.chatInput.suggestionsList.append(suggestionsObj[suggestionsObj.length - 1]);
            idMap[contactAddr] = true;
        }
        const len2 = chatsModel.messageList.rowCount();
        for (let f = 0; f < len2; f++) {
            addSuggestionFromMessageList(f);
        }
    }

    function showReplyArea() {
        isReply = true;
        isImage = false;
        let replyMessageIndex = chatsModel.messageList.getMessageIndex(SelectedMessage.messageId);
        if (replyMessageIndex === -1) return;
        
        let userName = chatsModel.messageList.getMessageData(replyMessageIndex, "userName")
        let message = chatsModel.messageList.getMessageData(replyMessageIndex, "message")
        let identicon = chatsModel.messageList.getMessageData(replyMessageIndex, "identicon")

        inputArea.chatInput.showReplyArea(userName, message, identicon)
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
            chatsModel.removeMessagesByUserId(publicKey)
        }
    }

    function clickOnNotification() {
        applicationWindow.show()
        applicationWindow.raise()
        applicationWindow.requestActivate()
        appMain.changeAppSection(Constants.chat)
        if (currentNotificationChatId) {
            chatsModel.setActiveChannel(currentNotificationChatId)
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
    
    ColumnLayout {
        spacing: 0

        TopBar {
            id: topBar
            z: 60
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.fillWidth: true
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
                model: chatsModel
                Loader {
                    active: false
                    sourceComponent: ChatMessages {
                        id: chatMessages
                        messageList: model.messages
                    }
                }
            }

            Connections {
                target: chatsModel
                onActiveChannelChanged: {
                    stackLayoutChatMessages.currentIndex = chatsModel.getMessageListIndex(chatsModel.activeChannelIndex)
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
            target: chatsModel
            onActiveChannelChanged: {
                inputArea.chatInput.suggestions.hide();
                inputArea.chatInput.textInput.forceActiveFocus(Qt.MouseFocusReason)
                populateSuggestions();
            }
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

        InputArea {
            id: inputArea
            Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
            Layout.fillWidth: true
            Layout.preferredWidth: parent.width
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
                    alias: chatsModel.activeChannel.alias,
                    identicon: activeChatIdenticon,
                    name: chatsModel.activeChannel.name,
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
                    alias: chatsModel.activeChannel.alias,
                    identicon: activeChatIdenticon,
                    name: chatsModel.activeChannel.name,
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
                walletModel.getGasPricePredictions()
            }
            onClosed: {
                txModalLoader.closed()
            }
            selectRecipient.readOnly: true
            selectRecipient.selectedRecipient: {
                return {
                    address: "",
                    alias: chatsModel.activeChannel.alias,
                    identicon: activeChatIdenticon,
                    name: chatsModel.activeChannel.name,
                    type: RecipientSelector.Type.Contact,
                    ensVerified: true
                }
            }
            selectRecipient.selectedType: RecipientSelector.Type.Contact
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";height:770;width:800}
}
##^##*/
