import QtQuick 2.12
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3
import QtQml.Models 2.3
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"
import "./"

PopupMenu {
    property string messageId
    property bool isProfile: false
    property bool isSticker: false
    property bool emojiOnly: false
    property bool hideEmojiPicker: false
    property bool pinnedMessage: false
    property bool isText: false
    property bool isCurrentUser: false
    property string linkUrls: ""
    property alias emojiContainer: emojiContainer

    id: messageContextMenu
    width: messageContextMenu.isProfile ? profileHeader.width : emojiContainer.width

    property var identicon: ""
    property var userName: ""
    property string nickname: ""
    property var fromAuthor: ""
    property var text: ""
    property var emojiReactionsReactedByUser: []
    property var onClickEdit: function(){}

    subMenuIcons: [
        {
            source: Qt.resolvedUrl("../../../../shared/img/copy-to-clipboard-icon"),
            width: 16,
            height: 16
        }
    ]

    function show(userNameParam, fromAuthorParam, identiconParam, textParam, nicknameParam, emojiReactionsModel) {
        userName = userNameParam || ""
        nickname = nicknameParam || ""
        fromAuthor = fromAuthorParam || ""
        identicon = identiconParam || ""
        text = textParam || ""
        let newEmojiReactions = []
        if (!!emojiReactionsModel) {
            emojiReactionsModel.forEach(function (emojiReaction) {
                newEmojiReactions[emojiReaction.emojiId] = emojiReaction.currentUserReacted
            })
        }
        emojiReactionsReactedByUser = newEmojiReactions

        const numLinkUrls = messageContextMenu.linkUrls.split(" ").length
        copyLinkMenu.enabled = numLinkUrls > 1
        copyLinkAction.enabled = !!messageContextMenu.linkUrls && numLinkUrls === 1 && !emojiOnly && !messageContextMenu.isProfile
        popup();
    }

    Item {
        id: emojiContainer
        visible: !hideEmojiPicker && (messageContextMenu.emojiOnly || !messageContextMenu.isProfile)
        width: emojiRow.width
        height: visible ? emojiRow.height : 0

        Row {
            id: emojiRow
            spacing: Style.current.smallPadding
            leftPadding: Style.current.smallPadding
            rightPadding: Style.current.smallPadding
            bottomPadding: messageContextMenu.emojiOnly ? 0 : Style.current.padding

            Repeater {
                model: reactionModel
                delegate: EmojiReaction {
                    source: "../../../img/" + filename
                    emojiId: model.emojiId
                    reactedByUser: !!messageContextMenu.emojiReactionsReactedByUser[model.emojiId]
                    closeModal: function () {
                        messageContextMenu.close()
                    }
                }
            }
        }
    }

    Rectangle {
        property bool hovered: false

        id: profileHeader
        visible: messageContextMenu.isProfile
        width: 200
        height: visible ? profileImage.height + username.height + Style.current.padding : 0
        color: hovered ? Style.current.backgroundHover : Style.current.transparent

        StatusImageIdenticon {
            id: profileImage
            source: identicon
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            id: username
            text: Utils.removeStatusEns(userName)
            elide: Text.ElideRight
            maximumLineCount: 3
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            anchors.top: profileImage.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.leftMargin: Style.current.smallPadding
            anchors.right: parent.right
            anchors.rightMargin: Style.current.smallPadding
            font.weight: Font.Medium
            font.pixelSize: 15
        }

        MouseArea {
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                profileHeader.hovered = true
            }
            onExited: {
                profileHeader.hovered = false
            }
            onClicked: {
                openProfilePopup(userName, fromAuthor, identicon);
                messageContextMenu.close()
            }
        }
    }

    Separator {
        anchors.bottom: viewProfileAction.top
        visible: !messageContextMenu.emojiOnly && !messageContextMenu.hideEmojiPicker
    }

    Action {
        id: pinAction
        text: pinnedMessage ? qsTr("Unpin") :
                              qsTr("Pin")
        onTriggered: {
            if (pinnedMessage) {
                chatsModel.messageView.unPinMessage(messageId, chatsModel.channelView.activeChannel.id)
                return
            }

            chatsModel.messageView.pinMessage(messageId, chatsModel.channelView.activeChannel.id)
            messageContextMenu.close()
        }
        icon.source: "../../../img/pin"
        icon.width: 16
        icon.height: 16
        enabled: {
            switch (chatsModel.channelView.activeChannel.chatType) {
            case Constants.chatTypePublic: return false
            case Constants.chatTypeStatusUpdate: return false
            case Constants.chatTypeOneToOne: return true
            case Constants.chatTypePrivateGroupChat: return chatsModel.channelView.activeChannel.isAdmin(profileModel.profile.pubKey)
            case Constants.chatTypeCommunity: return chatsModel.communities.activeCommunity.admin
            }

            return false
        }
    }

    Action {
        id: copyAction
        enabled: !emojiOnly
        text: qsTr("Copy")
        onTriggered: {
            chatsModel.copyToClipboard(messageContextMenu.text)
            messageContextMenu.close()
        }
        icon.source: "../../../../shared/img/copy-to-clipboard-icon"
        icon.width: 16
        icon.height: 16
    }

    Action {
        id: copyLinkAction
        text: qsTr("Copy link")
        onTriggered: {
            chatsModel.copyToClipboard(linkUrls.split(" ")[0])
            messageContextMenu.close()
        }
        icon.source: "../../../../shared/img/copy-to-clipboard-icon"
        icon.width: 16
        icon.height: 16
        enabled: false
    }

    PopupMenu {
        id: copyLinkMenu
        title: qsTr("Copy link")

        Repeater {
            id: linksRepeater
            model: messageContextMenu.linkUrls.split(" ")
            delegate: MenuItem {
                id: popupMenuItem
                text: modelData
                onTriggered: {
                    chatsModel.copyToClipboard(modelData)
                    messageContextMenu.close()
                }
                contentItem: StyledText {
                    text: popupMenuItem.text
                    font: popupMenuItem.font
                    color: Style.current.textColor
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    implicitWidth: 220
                    implicitHeight: 34
                    color: popupMenuItem.highlighted ? Style.current.backgroundHover: Style.current.transparent
                }
            }
        }
    }

    Action {
        id: viewProfileAction
        //% "View Profile"
        text: qsTrId("view-profile")
        onTriggered: {
            openProfilePopup(userName, fromAuthor, identicon, "", nickname);
            messageContextMenu.close()
        }
        icon.source: "../../../img/profileActive.svg"
        icon.width: 16
        icon.height: 16
        enabled: !emojiOnly && !copyLinkAction.enabled
    }

    Action {
        id: editMessageAction
        text: qsTr("Edit message")
        onTriggered: {
            onClickEdit();
        }
        icon.source: "../../../img/edit-message.svg"
        icon.width: 16
        icon.height: 16
        enabled: isCurrentUser && isText
    }

    Action {
        text: messageContextMenu.isProfile ?
                  //% "Send message"
                  qsTrId("send-message") :
                  //% "Reply to"
                  qsTrId("reply-to")
        onTriggered: {
            if (messageContextMenu.isProfile) {
                appMain.changeAppSection(Constants.chat)
                chatsModel.channelView.joinPrivateChat(fromAuthor, "")
            } else {
              showReplyArea()
            }
            messageContextMenu.close()
        }
        icon.source: "../../../img/messageActive.svg"
        icon.width: 16
        icon.height: 16
        enabled: !isSticker && !emojiOnly
    }

    Action {
        id: deleteMessageAction
        text: qsTr("Delete message")
        onTriggered: {
            console.log("delete", messageId);
            chatsModel.messageView.deleteMessage(messageId)
        }
        icon.source: "../../../img/delete.svg"
        icon.width: 16
        icon.height: 16
        enabled: isCurrentUser
    }
}
