import QtQuick 2.13
import "../../../../shared"
import "../../../../shared/status"
import "../../../../shared/status/core"
import "../../../../imports"
import "./MessageComponents"
import "../components"

Item {
    property string fromAuthor: "0x0011223344556677889910"
    property string userName: "Jotaro Kujo"
    property string alias: ""
    property string localName: ""
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
    property int nextMessageIndex: -1
    property bool timeout: false
    property bool hasMention: false
    property string linkUrls: ""
    property bool placeholderMessage: false
    property bool activityCenterMessage: false
    property bool pinnedMessage: false
    property bool read: true
    property string pinnedBy
    property bool forceHoverHandler: false // Used to force the HoverHandler to be active (useful for messages in popups)
    property string communityId: ""
    property int stickerPackId: -1
    property int gapFrom: 0
    property int gapTo: 0
    property bool isEdit: false
    property string replaces: ""
    property bool isEdited: false
    property bool showEdit: true

    z: {
        if (typeof chatLogView === "undefined") {
            return 1
        }

        return chatLogView.count - index
    }

    property string displayUserName: {
        if (isCurrentUser) {
            //% "You"
            return qsTrId("You")
        }

        if (localName !== "") {
            return localName
        }

        if (userName !== "") {
            return Utils.removeStatusEns(userName)
        }
        return Utils.removeStatusEns(alias)
    }

    property string authorCurrentMsg: "authorCurrentMsg"
    property string authorPrevMsg: "authorPrevMsg"

    property string prevMsgTimestamp: chatsModel.messageView.messageList.getMessageData(prevMessageIndex, "timestamp")
    property string nextMsgTimestamp: chatsModel.messageView.messageList.getMessageData(nextMessageIndex, "timestamp")

    property bool shouldRepeatHeader: ((parseInt(timestamp, 10) - parseInt(prevMsgTimestamp, 10)) / 60 / 1000) > Constants.repeatHeaderInterval

    property bool isEmoji: contentType === Constants.emojiType
    property bool isImage: contentType === Constants.imageType
    property bool isAudio: contentType === Constants.audioType
    property bool isStatusMessage: contentType === Constants.systemMessagePrivateGroupType
    property bool isSticker: contentType === Constants.stickerType
    property bool isText: contentType === Constants.messageType || contentType === Constants.editType
    property bool isMessage: isEmoji || isImage || isSticker || isText || isAudio
                             || contentType === Constants.communityInviteType || contentType === Constants.transactionType

    property bool isExpired: (outgoingStatus === "sending" && (Math.floor(timestamp) + 180000) < Date.now())
    property bool isStatusUpdate: false

    property int replyMessageIndex: chatsModel.messageView.messageList.getMessageIndex(responseTo);
    property string repliedMessageAuthor: replyMessageIndex > -1 ? chatsModel.messageView.messageList.getMessageData(replyMessageIndex, "userName") : "";
    property string repliedMessageAuthorPubkey: replyMessageIndex > -1 ? chatsModel.messageView.messageList.getMessageData(replyMessageIndex, "publicKey") : "";
    property bool repliedMessageAuthorIsCurrentUser: replyMessageIndex > -1 ? repliedMessageAuthorPubkey === profileModel.profile.pubKey : "";
    property bool repliedMessageIsEdited: replyMessageIndex > -1 ? chatsModel.messageView.messageList.getMessageData(replyMessageIndex, "isEdited") === "true" : false;
    property string repliedMessageContent: replyMessageIndex > -1 ? chatsModel.messageView.messageList.getMessageData(replyMessageIndex, "message") : "";
    property int repliedMessageType: replyMessageIndex > -1 ? parseInt(chatsModel.messageView.messageList.getMessageData(replyMessageIndex, "contentType")) : 0;
    property string repliedMessageImage: replyMessageIndex > -1 ? chatsModel.messageView.messageList.getMessageData(replyMessageIndex, "image") : "";
    property string repliedMessageUserIdenticon: replyMessageIndex > -1 ? chatsModel.messageView.messageList.getMessageData(replyMessageIndex, "identicon") : "";
    property string repliedMessageUserImage: replyMessageIndex > -1 ? appMain.getProfileImage(repliedMessageAuthorPubkey, repliedMessageAuthorIsCurrentUser , false) || "" : "";

    property var imageClick: function () {}
    property var scrollToBottom: function () {}
    property string userPubKey: {
        if (contentType === Constants.chatIdentifier) {
            return chatId
        }
        return fromAuthor
    }
    property bool useLargeImage: contentType === Constants.chatIdentifier

    property string profileImageSource: !placeholderMessage && appMain.getProfileImage(userPubKey, isCurrentUser, useLargeImage) || ""

    property var emojiReactionsModel: {
        if (!emojiReactions) {
            return []
        }

        try {
            // group by id
            var allReactions = Object.values(JSON.parse(emojiReactions))
            var byEmoji = {}
            allReactions.forEach(function (reaction) {
                if (!byEmoji[reaction.emojiId]) {
                    byEmoji[reaction.emojiId] = {
                        emojiId: reaction.emojiId,
                        fromAccounts: [],
                        count: 0,
                        currentUserReacted: false
                    }
                }
                byEmoji[reaction.emojiId].count++;
                byEmoji[reaction.emojiId].fromAccounts.push(chatsModel.userNameOrAlias(reaction.from));
                if (!byEmoji[reaction.emojiId].currentUserReacted && reaction.from === profileModel.profile.pubKey) {
                    byEmoji[reaction.emojiId].currentUserReacted = true
                }

            })
            return Object.values(byEmoji)
        } catch (e) {
            console.error('Error parsing emoji reactions', e)
            return []
        }
    }

    Connections {
        enabled: !placeholderMessage
        target: profileModel.contacts.list
        onContactChanged: {
            if (pubkey === fromAuthor) {
                const img = appMain.getProfileImage(userPubKey, isCurrentUser, useLargeImage)
                if (img) {
                    profileImageSource = img
                }
            } else if (replyMessageIndex > -1 && pubkey === repliedMessageAuthorPubkey) {
                const imgReply = appMain.getProfileImage(repliedMessageAuthorPubkey, repliedMessageAuthorIsCurrentUser, false)
                if (imgReply) {
                    repliedMessageUserImage = imgReply
                }
            }
        }
    }

    Connections {
        target: profileModel.contacts
        onContactBlocked: {
            // This hack is used because removeMessagesByUserId sometimes does not remove the messages
            if(publicKey === fromAuthor){
                root.visible = 0;
                root.height = 0;
            }
        }
    }

    Connections {
        target: chatsModel.messageView
        onHideMessage: {
            // This hack is used because message_list deleteMessage sometimes does not remove the messages (there might be an issue with the delegate model)
            if(mId === messageId){
                root.visible = 0;
                root.height = 0;
            }
        }
    }

    id: root
    width: parent.width
    anchors.right: !isCurrentUser ? undefined : parent.right
    height: {
        switch(contentType) {
            case Constants.chatIdentifier:
                return childrenRect.height + 50
            default: return childrenRect.height
        }
    }

    property var clickMessage: function(isProfileClick, isSticker = false, isImage = false, image = null, emojiOnly = false, hideEmojiPicker = false) {
        if (placeholderMessage || activityCenterMessage) {
            return
        }

        if (isImage) {
            imageClick(image);
            return;
        }

        if (!isProfileClick) {
            SelectedMessage.set(messageId, fromAuthor);
        }

        // Get contact nickname
        let nickname = appMain.getUserNickname(fromAuthor)
        messageContextMenu.messageId = root.messageId
        messageContextMenu.linkUrls = root.linkUrls
        messageContextMenu.isProfile = !!isProfileClick
        messageContextMenu.isSticker = isSticker
        messageContextMenu.emojiOnly = emojiOnly
        messageContextMenu.hideEmojiPicker = hideEmojiPicker
        messageContextMenu.pinnedMessage = pinnedMessage
        messageContextMenu.show(userName, fromAuthor, root.profileImageSource || identicon, plainText, nickname, emojiReactionsModel)
        // Position the center of the menu where the mouse is
        if (messageContextMenu.x + messageContextMenu.width + Style.current.padding < root.width) {
            messageContextMenu.x = messageContextMenu.x - messageContextMenu.width / 2
        }
    }

    Loader {
        width: parent.width
        sourceComponent: {
            switch(contentType) {
                case Constants.chatIdentifier:
                    return channelIdentifierComponent
                case Constants.fetchMoreMessagesButton:
                    return fetchMoreMessagesButtonComponent
                case Constants.systemMessagePrivateGroupType:
                    return privateGroupHeaderComponent
                case Constants.gapType:
                    return gapComponent
                default:
                    return isStatusUpdate ? statusUpdateComponent :
                                            (appSettings.useCompactMode ? compactMessageComponent : messageComponent)

            }
        }
    }

    Timer {
        id: timer
    }

    Component {
        id: gapComponent
        Item {
            id: wrapper
            height: childrenRect.height + Style.current.smallPadding * 2
            anchors.left: parent.left
            anchors.right: parent.right
            Separator {
                id: sep1
            }
            StyledText {
                id: fetchMoreButton
                font.weight: Font.Medium
                font.pixelSize: Style.current.primaryTextFontSize
                color: Style.current.blue
                //% "↓ "
                text: qsTr("Fetch messages")
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: sep1.bottom
                anchors.topMargin: Style.current.smallPadding
                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: {
                        chatsModel.messageView.fillGaps(messageId)
                        root.visible = false;
                        root.height = 0;
                    }
                }
            }
            StyledText {
                id: fetchDate
                anchors.top: fetchMoreButton.bottom
                anchors.topMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                color: Style.current.secondaryText
                //% "before %1"
                text: qsTr("Between %1 and %2").arg(new Date(root.gapFrom*1000)).arg(new Date(root.gapTo*1000))
            }
            Separator {
                anchors.top: fetchDate.bottom
                anchors.topMargin: Style.current.smallPadding
            }
        }
    }

    Component {
        id: fetchMoreMessagesButtonComponent
        Item {
            id: wrapper
            readonly property int gapNowAndOldest: nextMessageIndex > -1 ? (Date.now() / 1000 - nextMsgTimestamp / 1000) : 0
            readonly property int gapNowAndJoined: Date.now() / 1000 - +chatsModel.channelView.activeChannel.joined / 1000
            readonly property int maxGapInSeconds: Constants.maxNbDaysToFetch * Constants.fetchRangeLast24Hours

            visible: {
                if (!chatsModel.activeChannel) {
                    return false
                }
                return gapNowAndOldest < maxGapInSeconds
                        && gapNowAndJoined > maxGapInSeconds
                        && (chatsModel.channelView.activeChannel.chatType !== Constants.chatTypePrivateGroupChat || chatsModel.channelView.activeChannel.isMember)
            }
            height: childrenRect.height + Style.current.smallPadding * 2
            anchors.left: parent.left
            anchors.right: parent.right
            Separator {
                id: sep1
            }
            Loader {
                id: fetchLoaderIndicator
                anchors.top: sep1.bottom
                anchors.topMargin: Style.current.padding
                anchors.left: parent.left
                anchors.right: parent.right
                active: false
                sourceComponent: StatusLoadingIndicator {
                    width: 12
                    height: 12
                }
            }
            StyledText {
                id: fetchMoreButton
                font.weight: Font.Medium
                font.pixelSize: Style.current.primaryTextFontSize
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
                        chatsModel.requestMoreMessages(Constants.fetchRangeLast24Hours);
                        fetchLoaderIndicator.active = true;
                        fetchMoreButton.visible = false;
                        fetchDate.visible = false;
                        timer.setTimeout(function(){
                            chatsModel.messageView.hideLoadingIndicator();
                            fetchLoaderIndicator.active = false;
                            fetchMoreButton.visible = true;
                            fetchDate.visible = true;
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
                color: Style.current.secondaryText
                //% "before %1"
                text: qsTrId("before--1").arg((nextMessageIndex > -1 ? new Date(nextMsgTimestamp * 1) : new Date()).toLocaleString(Qt.locale(globalSettings.locale)))
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
            authorCurrentMsg: root.authorCurrentMsg
            profileImage: profileImageSource
        }
    }

    // Private group Messages
    Component {
        id: privateGroupHeaderComponent
        StyledText {
            wrapMode: Text.Wrap
            text: {
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
            topPadding: root.prevMessageIndex === 1 ? Style.current.bigPadding : 0
        }
    }

    Component {
        id: messageComponent
        NormalMessage {
            clickMessage: root.clickMessage
            linkUrls: root.linkUrls
            isCurrentUser: root.isCurrentUser
            contentType: root.contentType
            container: root
        }
    }

    Component {
        id: statusUpdateComponent
        StatusUpdate {
            clickMessage: root.clickMessage
            container: root
        }
    }

    Component {
        id: compactMessageComponent
        CompactMessage {
            clickMessage: root.clickMessage
            linkUrls: root.linkUrls
            isCurrentUser: root.isCurrentUser
            contentType: root.contentType
            showEdit: root.showEdit
            container: root
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";formeditorZoom:1.75;height:80;width:800}
}
##^##*/
