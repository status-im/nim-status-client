import QtQuick 2.3
import "../../../../shared"
import "../../../../imports"
import "./MessageComponents"
import "../components"

Item {
    property string fromAuthor: "0x0011223344556677889910"
    property string userName: "Jotaro Kujo"
    property string message: "That's right. We're friends...  Of justice, that is."
    property string plainText: "That's right. We're friends...  Of justice, that is."
    property string identicon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAZAAAAGQAQMAAAC6caSPAAAABlBMVEXMzMz////TjRV2AAAAAWJLR0QB/wIt3gAAACpJREFUGBntwYEAAAAAw6D7Uw/gCtUAAAAAAAAAAAAAAAAAAAAAAAAAgBNPsAABAjKCqQAAAABJRU5ErkJggg=="
    property bool isCurrentUser: false
    property string timestamp: "1234567"
    property string sticker: "Qme8vJtyrEHxABcSVGPF95PtozDgUyfr1xGjePmFdZgk9v"
    property int contentType: 2 // constants don't work in default props
    property string chatId: "chatId"
    property string outgoingStatus: ""
    property string responseTo: ""
    property string messageId: ""
    property string emojiReactions: ""
    property int prevMessageIndex: -1
    property bool timeout: false

    property string authorCurrentMsg: "authorCurrentMsg"
    property string authorPrevMsg: "authorPrevMsg"

    property bool isEmoji: contentType === Constants.emojiType
    property bool isImage: contentType === Constants.imageType
    property bool isAudio: contentType === Constants.audioType
    property bool isStatusMessage: contentType === Constants.systemMessagePrivateGroupType
    property bool isSticker: contentType === Constants.stickerType
    property bool isText: contentType === Constants.messageType
    property bool isMessage: isEmoji || isImage || isSticker || isText || isAudio

    property bool isExpired: (outgoingStatus == "sending" && (Math.floor(timestamp) + 180000) < Date.now())

    property int replyMessageIndex: chatsModel.messageList.getMessageIndex(responseTo);
    property string repliedMessageAuthor: replyMessageIndex > -1 ? chatsModel.messageList.getMessageData(replyMessageIndex, "userName") : "";
    property string repliedMessageContent: replyMessageIndex > -1 ? chatsModel.messageList.getMessageData(replyMessageIndex, "message") : "";
    property int repliedMessageType: replyMessageIndex > -1 ? parseInt(chatsModel.messageList.getMessageData(replyMessageIndex, "contentType")) : 0;
    property string repliedMessageImage: replyMessageIndex > -1 ? chatsModel.messageList.getMessageData(replyMessageIndex, "image") : "";

    property var imageClick: function () {}
    property var scrollToBottom: function () {}

    visible: false

    function delay(delayTime, cb) {
        timer.interval = delayTime;
        timer.repeat = false;
        timer.triggered.connect(cb);
        timer.start();
    }

    Component.onCompleted: {
        const request = {
            type: "isUserAllowed",
            payload: [utilsModel.channelHash(chatId), utilsModel.derivedAnUserAddress(fromAuthor)]
        }

        if(userAllowedDictionary[fromAuthor] !== undefined){
            messageItem.visible = userAllowedDictionary[fromAuthor];
            return;
        }

        ethersChannel.postMessage(request, (message) => {
            userAllowedDictionary[fromAuthor] = message;
            messageItem.visible = message;
        });
        
        // delay(1000, function() {
        //   if(Math.random() < 0.5) {
            // console.log("making message visible")
            // messageItem.visible = true
        //   }
        // })*/
    }

    id: messageItem
    width: parent.width
    anchors.right: !isCurrentUser ? undefined : parent.right
    height: {
        switch(contentType) {
            case Constants.chatIdentifier:
                return childrenRect.height + 50
            default: return childrenRect.height
        }
    }

    function clickMessage(isProfileClick, isSticker = false, isImage = false, image = null) {
        if (isImage) {
            imageClick(image);
            return;
        }

        if (!isProfileClick) {
            SelectedMessage.set(messageId, fromAuthor);
        }
        // Get contact nickname
        const contactList = profileModel.contactList
        const contactCount = contactList.rowCount()
        let nickname = ""
        for (let i = 0; i < contactCount; i++) {
            if (contactList.rowData(i, 'pubKey') === fromAuthor) {
                nickname = contactList.rowData(i, 'localNickname')
                break;
            }
        }
        messageContextMenu.isProfile = !!isProfileClick
        messageContextMenu.isSticker = isSticker
        messageContextMenu.show(userName, fromAuthor, identicon, "", nickname)
        // Position the center of the menu where the mouse is
        messageContextMenu.x = messageContextMenu.x - messageContextMenu.width / 2
    }

    Loader {
        active :true
        width: parent.width
        sourceComponent: {
            switch(contentType) {
                case Constants.chatIdentifier:
                    return channelIdentifierComponent
                case Constants.fetchMoreMessagesButton:
                    return fetchMoreMessagesButtonComponent
                case Constants.systemMessagePrivateGroupType:
                    return privateGroupHeaderComponent
                case Constants.transactionType:
                    return transactionBubble
                default:
                    return appSettings.compactMode ? compactMessageComponent : messageComponent
            }
        }
    }

    Timer {
        id: timer
    }

    Component {
        id: fetchMoreMessagesButtonComponent
        Item {
            visible: chatsModel.activeChannel.chatType !== Constants.chatTypePrivateGroupChat || chatsModel.activeChannel.isMember
            id: wrapper
            height: wrapper.visible ? fetchMoreButton.height + fetchDate.height + 3 + Style.current.smallPadding*2 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            Separator {
                id: sep1
            }
            StyledText {
                id: fetchMoreButton
                font.weight: Font.Medium
                font.pixelSize: 15
                color: Style.current.blue
                //% "↓ Fetch more messages"
                text: qsTrId("load-more-messages")
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: sep1.bottom
                anchors.topMargin: Style.current.smallPadding
                MouseArea {
                  cursorShape: Qt.PointingHandCursor
                  anchors.fill: parent
                  onClicked: {
                    chatsModel.requestMoreMessages()
                    timer.setTimeout(function(){ 
                        chatsModel.hideLoadingIndicator()
                    }, 3000);
                  }
                }
            }
            StyledText {
                id: fetchDate
                anchors.top: fetchMoreButton.bottom
                anchors.topMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                color: Style.current.darkGrey
                //% "before %1"
                text: qsTrId("before--1").arg(new Date(chatsModel.oldestMsgTimestamp*1000).toDateString())
            }
            Separator {
                anchors.top: fetchDate.bottom
                anchors.topMargin: Style.current.smallPadding
            }
        }
    }

    Component {
        id: channelIdentifierComponent
        ChannelIdentifier {
            authorCurrentMsg: messageItem.authorCurrentMsg
        }
    }

    // Private group Messages
    Component {
        id: privateGroupHeaderComponent
        StyledText {
            wrapMode: Text.Wrap
            text:  {
                return `<html>`+
                `<head>`+
                    `<style type="text/css">`+
                    `a {`+
                        `color: ${Style.current.textColor};`+
                        `text-decoration: none;`+
                    `}`+
                    `</style>`+
                `</head>`+
                `<body>`+
                    `${message}`+
                `</body>`+
            `</html>`;
            }
            visible: isStatusMessage
            font.pixelSize: 14
            color: Style.current.secondaryText
            width:  parent.width - 120
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.RichText
        }
    }

    // Normal message
    Component {
        id: messageComponent
        NormalMessage {
            clickMessage: messageItem.clickMessage
        }
    }

    // Compact Messages
    Component {
        id: compactMessageComponent
        CompactMessage {
            clickMessage: messageItem.clickMessage
        }
    }

    // Transaction bubble
    Component {
        id: transactionBubble
        TransactionBubble {}
    }
}

/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";formeditorZoom:1.75;height:80;width:800}
}
##^##*/
