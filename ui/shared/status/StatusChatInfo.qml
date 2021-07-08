import QtQuick 2.13
import QtQuick.Controls 2.13
import QtGraphicalEffects 1.13
import "../../imports"
import "../../shared"
import "../../shared/status"

Item {
    id: root

    property string chatId
    property string chatName
    property int chatType
    property int realChatType: {
        if (chatType === Constants.chatTypeCommunity) {
            // TODO add a check for private community chats once it is created
            return Constants.chatTypePublic
        }
        return chatType
    }
    property string identicon
    property int identiconSize: 40
    property bool isCompact: false
    property bool muted: false

    property string profileImage: realChatType === Constants.chatTypeOneToOne ? appMain.getProfileImage(chatId) || ""  : ""

    height: 48

    Connections {
        enabled: realChatType === Constants.chatTypeOneToOne
        target: profileModel.contacts.list
        function onContactChanged(pubkey) {
            if (pubkey === root.chatId) {
                root.profileImage = appMain.getProfileImage(root.chatId) || ""
            }
        }
    }

    StatusIdenticon {
        id: chatIdenticon
        chatType: root.realChatType
        chatId: root.chatId
        chatName: root.chatName
        identicon: root.profileImage || root.identicon
        width: root.isCompact ? 20 : root.identiconSize
        height: root.isCompact ? 20 : root.identiconSize
        anchors.verticalCenter: parent.verticalCenter
    }

    Item {
        id: nameAndInfo
        height: chatName.height + chatInfo.height
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: chatIdenticon.right
        anchors.leftMargin: Style.current.smallPadding

        StyledText {
            id: chatName
            text: {
                switch(root.realChatType) {
                    case Constants.chatTypePublic: return "#" + root.chatName;
                    case Constants.chatTypeOneToOne: return Utils.removeStatusEns(root.chatName)
                    default: return root.chatName
                }
            }

            font.weight: Font.Medium
            font.pixelSize: 15
        }

        SVGImage {
            property bool hovered: false

            id: bellImg
            visible: root.muted
            source: "../../app/img/bell-disabled.svg"
            anchors.verticalCenter: chatName.verticalCenter
            anchors.left: chatName.right
            anchors.leftMargin: 4
            width: 12.5
            height: 12.5

            ColorOverlay {
                anchors.fill: parent
                source: parent
                color: bellImg.hovered ? Style.current.textColor : Style.current.darkGrey
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: bellImg.hovered = true
                onExited: bellImg.hovered = false
                onClicked: {
                    chatsModel.channelView.unmuteCurrentChannel()
                }
            }
        }

        Connections {
            target: profileModel.contacts
            function onContactChanged(publicKey) {
                if(root.chatId === publicKey){
                    // Hack warning: Triggering reload to avoid changing the current text binding
                    var tmp = chatId;
                    chatId = "";
                    chatId = tmp;
                }
            }
        }

        StyledText {
            id: chatInfo
            color: Style.current.secondaryText
            width: topBar.childrenRect.width - 200
            elide: Text.ElideRight
            text: {
                if (root.chatType === Constants.chatTypeCommunity) {
                    return chatsModel.channelView.activeChannel.description
                }
                switch(root.realChatType){
                    //% "Public chat"
                case Constants.chatTypePublic: return qsTrId("public-chat")
                case Constants.chatTypeOneToOne: return (profileModel.contacts.isAdded(root.chatId) ?
                                                             profileModel.contacts.contactRequestReceived(root.chatId) ?
                                                                 //% "Contact"
                                                                 qsTrId("chat-is-a-contact") :
                                                                 qsTr("Contact request pending") :

                                                         //% "Not a contact"
                                                         qsTrId("chat-is-not-a-contact"))
                case Constants.chatTypePrivateGroupChat:
                    let cnt = chatsModel.channelView.activeChannel.members.rowCount();
                    //% "%1 members"
                    if(cnt > 1) return qsTrId("%1-members").arg(cnt);
                    //% "1 member"
                    return qsTrId("1-member");
                default: return "...";
                }
            }
            font.pixelSize: 12
            anchors.top: chatName.bottom
            anchors.topMargin: 2
            anchors.left: chatName.left
        }

        Item {
            property bool hovered: false

            id: pinnedMessagesGroup
            visible: chatType !== Constants.chatTypePublic && chatsModel.messageView.pinnedMessagesList.count > 0
            width: childrenRect.width
            height: vertiSep.height
            anchors.left: chatInfo.right
            anchors.leftMargin: 4
            anchors.verticalCenter: chatInfo.verticalCenter

            Rectangle {
                id: vertiSep
                height: 12
                width: 1
                color: Style.current.border
            }

            SVGImage {
                id: pinImg
                source: "../../app/img/pin.svg"
                height: 14
                width: 14
                anchors.left: vertiSep.right
                anchors.leftMargin: 4
                anchors.verticalCenter: vertiSep.verticalCenter

                ColorOverlay {
                    anchors.fill: parent
                    source: parent
                    color: pinnedMessagesGroup.hovered ? Style.current.textColor : Style.current.secondaryText
                }
            }

            StyledText {
                id: nbPinnedMessagesText
                color: pinnedMessagesGroup.hovered ? Style.current.textColor : Style.current.secondaryText
                text: chatsModel.messageView.pinnedMessagesList.count
                font.pixelSize: 12
                font.underline: pinnedMessagesGroup.hovered
                anchors.left: pinImg.right
                anchors.verticalCenter: vertiSep.verticalCenter
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: pinnedMessagesGroup.hovered = true
                onExited: pinnedMessagesGroup.hovered = false
                onClicked: openPopup(pinnedMessagesPopupComponent)
            }
        }
    }
}

