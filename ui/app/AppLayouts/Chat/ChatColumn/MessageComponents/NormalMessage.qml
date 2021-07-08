import QtQuick 2.13
import "../../../../../shared"
import "../../../../../imports"

Item {
    property var clickMessage: function () {}
    property string linkUrls: ""
    property bool isCurrentUser: false
    property int contentType: 2
    property var container
    property bool headerRepeatCondition: (authorCurrentMsg != authorPrevMsg || shouldRepeatHeader || dateGroupLbl.visible)

    id: root
    anchors.top: parent.top
    anchors.topMargin: authorCurrentMsg !== authorPrevMsg ? Style.current.smallPadding : 0
    height: childrenRect.height + this.anchors.topMargin + (dateGroupLbl.visible ? dateGroupLbl.height : 0)
    width: parent.width

    DateGroup {
        id: dateGroupLbl
        previousMessageIndex: prevMessageIndex
        previousMessageTimestamp: prevMsgTimestamp
        messageTimestamp: timestamp
        isActivityCenterMessage: activityCenterMessage
    }

    UserImage {
        id: chatImage
        active: chatsModel.channelView.activeChannel.chatType !== Constants.chatTypeOneToOne && isMessage && headerRepeatCondition && !root.isCurrentUser
        anchors.left: parent.left
        anchors.leftMargin: Style.current.padding
        anchors.top:  dateGroupLbl.visible ? dateGroupLbl.bottom : parent.top
        anchors.topMargin: 20
    }

    UsernameLabel {
        id: chatName
        visible: chatsModel.channelView.activeChannel.chatType !== Constants.chatTypeOneToOne && isMessage && headerRepeatCondition && !root.isCurrentUser
        anchors.leftMargin: 20
        anchors.top: dateGroupLbl.visible ? dateGroupLbl.bottom : parent.top
        anchors.topMargin: 0
        anchors.left: chatImage.right
    }

    Rectangle {
        readonly property int defaultMessageWidth: 400
        readonly property int defaultMaxMessageChars: 54
        readonly property int messageWidth: Math.max(defaultMessageWidth, parent.width / 1.4)
        readonly property int maxMessageChars: (defaultMaxMessageChars * messageWidth) / defaultMessageWidth
        property int chatVerticalPadding: isImage ? 4 : 6
        property int chatHorizontalPadding: isImage ? 0 : 12
        property bool longReply: chatReply.active && repliedMessageContent.length > maxMessageChars
        property bool longChatText: chatsModel.plainText(message).split('\n').some(function (messagePart) {
            return messagePart.length > maxMessageChars
        })

        id: chatBox
        color: {
            if (isSticker) {
                return Style.current.background 
            }
            if (isImage) {
                return "transparent"
            }
            return root.isCurrentUser ? Style.current.primary : Style.current.secondaryBackground
        }
        border.color: isSticker ? Style.current.border : Style.current.transparent
        border.width: 1
        height: {
           let h = (3 * chatVerticalPadding)
           switch(contentType){
                case Constants.stickerType:
                    h += stickerId.height;
                    break;
                case Constants.audioType:
                    h += audioPlayerLoader.height;
                    break;
                default:
                    if (!chatImageContent.active && !chatReply.active) {
                        h -= chatVerticalPadding
                    }

                    h += chatText.visible ? chatText.height : 0;
                    h += chatImageContent.active ? chatImageContent.height: 0;
                    h += chatReply.active ? chatReply.height : 0;
           }
           return h;
        }
        width: {
            switch(contentType) {
                case Constants.stickerType:
                    return stickerId.width + (2 * chatBox.chatHorizontalPadding);
                case Constants.imageType:
                    return chatImageContent.width
                default:
                    if (longChatText || longReply) {
                        return messageWidth;
                    }
                    let baseWidth = chatText.width;
                    if (chatReply.visible && chatText.width < chatReply.textFieldWidth) {
                        baseWidth = chatReply.textFieldWidth
                    }

                    if (chatReply.visible && chatText.width < chatReply.authorWidth) {
                        if(chatReply.authorWidth > baseWidth){
                            baseWidth = chatReply.authorWidth + 20
                        }
                    }

                    return baseWidth + 2 * chatHorizontalPadding
            }
        }

        radius: 16
        anchors.left: !root.isCurrentUser ? chatImage.right : undefined
        anchors.leftMargin: !root.isCurrentUser ? 8 : 0
        anchors.right: !root.isCurrentUser ? undefined : parent.right
        anchors.rightMargin: !root.isCurrentUser ? 0 : Style.current.padding
        anchors.top: headerRepeatCondition && !root.isCurrentUser ? chatImage.top : (dateGroupLbl.visible ? dateGroupLbl.bottom : parent.top)
        anchors.topMargin: 0
        visible: isMessage && contentType !== Constants.transactionType

        ChatReply {
            id: chatReply
            longReply: chatBox.longReply
            anchors.top: parent.top
            anchors.topMargin: chatReply.visible ? chatBox.chatVerticalPadding : 0
            anchors.left: parent.left
            anchors.leftMargin: Style.current.padding
            anchors.right: parent.right
            anchors.rightMargin: chatBox.chatHorizontalPadding
            container: root.container
            chatHorizontalPadding: chatBox.chatHorizontalPadding
        }

        ChatText {
            id: chatText
            longChatText: chatBox.longChatText
            anchors.top: chatReply.bottom
            anchors.topMargin: chatReply.active ? chatBox.chatVerticalPadding : 0
            anchors.left: parent.left
            anchors.leftMargin: chatBox.chatHorizontalPadding
            anchors.right: chatBox.longChatText ? parent.right : undefined
            anchors.rightMargin: chatBox.longChatText ? chatBox.chatHorizontalPadding : 0
            textField.color: !root.isCurrentUser ? Style.current.textColor : Style.current.currentUserTextColor
            Connections {
                target: appSettings.useCompactMode ? null : chatBox
                function onLongChatTextChanged() {
                    chatText.setWidths()
                }
            }
        }

        Loader {
            id: chatImageContent
            active: isImage && !!image
            anchors.top: parent.top
            anchors.topMargin: Style.current.smallPadding
            anchors.left: parent.left
            anchors.leftMargin: chatBox.chatHorizontalPadding
            z: 51

            sourceComponent: Component {
                Item {
                    width: chatImageComponent.width + 2 * chatBox.chatHorizontalPadding
                    height: chatImageComponent.height

                    ChatImage {
                        id: chatImageComponent
                        imageSource: image
                        imageWidth: 250
                        isCurrentUser: root.isCurrentUser
                        onClicked: root.clickMessage(false, false, true, image)
                        container: root.container
                    }
                }
            }
        }

        Loader {
            id: audioPlayerLoader
            active: isAudio
            sourceComponent: audioPlayer
            anchors.verticalCenter: parent.verticalCenter
        }

        Component {
            id: audioPlayer
            AudioPlayer {
                audioSource: audio
            }
        }

        Sticker {
            id: stickerId
            anchors.left: parent.left
            anchors.leftMargin: chatBox.chatHorizontalPadding
            anchors.top: parent.top
            anchors.topMargin: chatBox.chatVerticalPadding
            color: Style.current.transparent
            container: root.container
            contentType: root.contentType
        }

        MessageMouseArea {
            anchors.fill: parent
        }

        RectangleCorner {
            // TODO find a way to show the corner for stickers since they have a border
            visible: isMessage
        }
    }

    Loader {
        id: transactionBubbleLoader
        active: contentType === Constants.transactionType
        anchors.left: !isCurrentUser ? chatImage.right : undefined
        anchors.leftMargin: isCurrentUser ? 0 : Style.current.halfPadding
        anchors.right: isCurrentUser ? parent.right : undefined
        anchors.rightMargin: Style.current.padding
        sourceComponent: Component {
            TransactionBubble {}
        }
    }

    Rectangle {
        id: dateTimeBackground
        visible: isImage
        height: visible ? chatTime.height + Style.current.halfPadding : 0
        width: chatTime.width + 2 * chatTime.anchors.rightMargin +
               (retry.visible ? retry.width + retry.anchors.rightMargin : sentMessage.width + sentMessage.anchors.rightMargin)
        color: Utils.setColorAlpha(Style.current.black, 0.66)
        radius: Style.current.radius
        anchors.bottom: chatBox.bottom
        anchors.bottomMargin: Style.current.halfPadding
        anchors.right: chatBox.right
        anchors.rightMargin: 6
    }

    ChatTime {
        id: chatTime
        visible: isMessage && !emojiReactionLoader.active
        anchors.top: isImage ? undefined : (linksLoader.active ? linksLoader.bottom : chatBox.bottom)
        anchors.topMargin: isImage ? 0 : 4
        anchors.verticalCenter: isImage ? dateTimeBackground.verticalCenter : undefined
        anchors.right: isImage ? dateTimeBackground.right : (linksLoader.active ? linksLoader.right : chatBox.right)
        anchors.rightMargin: isImage ? 6 : (root.isCurrentUser ? 5 : Style.current.padding)
    }

    SentMessage {
        id: sentMessage
        visible: root.isCurrentUser && !timeout && !isExpired && isMessage && outgoingStatus === "sent"
        anchors.verticalCenter: chatTime.verticalCenter
        anchors.right: chatTime.left
        anchors.rightMargin: 5
    }

    Retry {
        id: retry
        anchors.verticalCenter: chatTime.verticalCenter
        anchors.right: chatTime.left
        anchors.rightMargin: 5
    }

    Loader {
        id: linksLoader
        active: !!root.linkUrls
        anchors.left: !root.isCurrentUser ? chatImage.right : undefined
        anchors.leftMargin: !root.isCurrentUser ? 8 : 0
        anchors.right: !root.isCurrentUser ? undefined : parent.right
        anchors.rightMargin: !root.isCurrentUser ? 0 : Style.current.padding
        anchors.top: chatBox.bottom
        anchors.topMargin: Style.current.halfPadding
        anchors.bottomMargin: Style.current.halfPadding

        sourceComponent: Component {
            LinksMessage {
                linkUrls: root.linkUrls
                container: root.container
                isCurrentUser: root.isCurrentUser
            }
        }
    }

    Loader {
        id: emojiReactionLoader
        active: emojiReactions !== ""
        sourceComponent: emojiReactionsComponent
        anchors.left: root.isCurrentUser ? undefined : chatBox.left
        anchors.right: root.isCurrentUser ? chatBox.right : undefined
        anchors.leftMargin: root.isCurrentUser ? Style.current.halfPadding : 1
        anchors.top: chatBox.bottom
        anchors.topMargin: 2
    }

    Component {
        id: emojiReactionsComponent
        EmojiReactions {}
    }
}
