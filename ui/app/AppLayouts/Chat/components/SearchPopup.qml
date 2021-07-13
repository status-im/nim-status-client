import QtQuick 2.13
import QtQuick.Controls 2.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"
import "../ChatColumn"

Popup {
    property var searchResults
    property string chatId: chatsModel.channelView.activeChannel.id

    id: popup
    modal: true

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.4)
    }
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: Overlay.overlay
    x: Math.round(((parent ? parent.width : 0) - width) / 2)
    y: Math.round(((parent ? parent.height : 0) - height) / 2)
    width: 690
    height: {
        const noResultHeight = 122
        let minHeight = 560
        const maxHeight = parent.height - 200
        if (!searchResults || !searchResults.length || !searchResultContent.visible) {
            return noResultHeight
        }

        if (minHeight > maxHeight) {
            return maxHeight
        }

        if (messageColumn.height < minHeight - noResultHeight) {
            return minHeight
        }
        if (messageColumn.height > maxHeight - noResultHeight) {
            return maxHeight
        }
    }
    background: Rectangle {
        color: Style.current.background
        radius: 16
    }
    onOpened: {
        popupOpened = true
        searchInput.forceActiveFocus(Qt.MouseFocusReason)
    }
    onClosed: {
        popupOpened = false
    }
    padding: 0

    Item {
        id: searchHeader
        width: parent.width
        height: 64

        SVGImage {
            id: searchImage
            source: "../../../img/search.svg"
            width: 40
            height: 40
            anchors.left: parent.left
            anchors.leftMargin: Style.current.padding
            anchors.verticalCenter: parent.verticalCenter
        }

        property var searchMessages: Backpressure.debounce(searchInput, 400, function (value) {
            if (value === "") {
                searchResultContent.visible = false
                return
            }

            // TODO add loading?
            const messageIdsStr = chatsModel.messageView.messageList.messageSearch(value)
            try {
                searchResultContent.visible = true
                searchResults = JSON.parse(messageIdsStr)
            } catch (e) {
                console.error ("Error parsing search result", e)
            }
        })

        StyledTextField {
            id: searchInput
            anchors.left: searchImage.right
            anchors.leftMargin: Style.current.smallPadding
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Style.current.padding
            placeholderText: qsTr("Search")
            placeholderTextColor: Style.current.secondaryText
            selectByMouse: true
            font.pixelSize: 28
            background: Rectangle {
                color: Style.current.transparent
            }
            Keys.onReleased: Qt.callLater(searchHeader.searchMessages, searchInput.text)
        }

        Separator {
            anchors.bottom: parent.bottom
            anchors.topMargin: 0
        }
    }

    Rectangle {
        id: channelBadge
        color: Style.current.inputBackground
        border.width: 0
        radius: Style.current.radius
        height: 32
        width: childrenRect.width + 2 * inText.anchors.leftMargin
        anchors.left: parent.left
        anchors.leftMargin: Style.current.padding
        anchors.top: searchHeader.bottom
        anchors.topMargin: 12

        StyledText {
            id: inText
            text: qsTr("In:")
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 15
        }

        BadgeContent {
            chatId: popup.chatId
            name: Utils.removeStatusEns(chatsModel.channelView.activeChannel.name)
            identicon: chatsModel.channelView.activeChannel.identicon
            communityId: chatsModel.channelView.activeChannel.communityId
            anchors.left: inText.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            hideSecondIcon: true
        }
    }

    Item {
        id: searchResultContent
        visible: !!popup.searchResults && popup.searchResults.length > 0
        width: parent.width
        anchors.bottom: parent.bottom
        anchors.top: channelBadge.bottom
        anchors.topMargin: visible ? 13 : 0

        Separator {
            id: sep2
            anchors.top: parent.top
            anchors.topMargin: 0
        }

        StyledText {
            id: sectionTitle
            text: qsTr("Messages")
            font.pixelSize: 15
            color: Style.current.secondaryText
            anchors.top: sep2.bottom
            anchors.topMargin: Style.current.smallPadding
            anchors.left: parent.left
            anchors.leftMargin: Style.current.bigPadding
        }

        ScrollView {
            id: scrollView
            anchors.top: sectionTitle.bottom
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.current.smallPadding
            width: parent.width
            clip: true

            Column {
                id: messageColumn
                width: parent.width
                spacing: 0

                Repeater {
                    model: popup.searchResults

                    delegate: Message {
                        property var messageItem: ({})

                        function getMessage() {
                            chatsModel.messageView.setObservedMessageItem(popup.chatId, modelData)
                            return chatsModel.messageView.observedMessageItem
                        }

                        Component.onCompleted: {
                            messageItem = getMessage()
                        }

                        anchors.right: undefined
                        messageId: messageItem.messageId
                        fromAuthor: messageItem.fromAuthor
                        chatId: messageItem.chatId
                        userName: messageItem.userName
                        alias: messageItem.alias
                        localName: messageItem.localName
                        message: messageItem.message
                        plainText: messageItem.plainText
                        identicon: messageItem.identicon
                        isCurrentUser: messageItem.isCurrentUser
                        timestamp: messageItem.timestamp
                        sticker: messageItem.sticker
                        contentType: messageItem.contentType
                        outgoingStatus: messageItem.outgoingStatus
                        responseTo: messageItem.responseTo
                        imageClick: imagePopup.openPopup.bind(imagePopup)
                        linkUrls: messageItem.linkUrls
                        communityId: messageItem.communityId
                        hasMention: messageItem.hasMention
                        stickerPackId: messageItem.stickerPackId
                        pinnedBy: messageItem.pinnedBy
                        pinnedMessage: messageItem.isPinned
                        activityCenterMessage: true
                        clickMessage: function (isProfileClick) {
                            if (isProfileClick) {
                                const pk = messageItem.fromAuthor
                                const userProfileImage = appMain.getProfileImage(pk)
                                return openProfilePopup(chatsModel.userNameOrAlias(pk), pk, userProfileImage || utilsModel.generateIdenticon(pk))
                            }

                            popup.close()

                            positionAtMessage(messageItem.messageId)
                        }

                        prevMessageIndex: -1
                        prevMsgTimestamp: ""
                    }
                }
            }
        }
    }
}
