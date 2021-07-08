import QtQuick 2.13
import QtQuick.Controls 2.13
import "../../../../shared"
import "../../../../shared/status"
import "../../../../imports"
import "../components"

Item {
    property string chatId: ""
    property string categoryId: ""
    property string name: "channelName"
    property string lastMessage: "My latest message\n with a return"
    property string timestamp: "1605212622434"
    property string unviewedMessagesCount: "2"
    property string identicon
    property int mentionsCount: 0
    property int chatType: Constants.chatTypePublic
    property int realChatType: {
        if (chatType === Constants.chatTypeCommunity) {
            // TODO add a check for private community chats once it is created
            return Constants.chatTypePublic
        }
        return chatType
    }

    property string filterCategory: ""
    property string searchStr: ""
    property bool isCompact: appSettings.useCompactMode
    property int contentType: 1
    property bool muted: false
    property bool hovered: false
    property bool enableMouseArea: true
    property color color: {
        if (ListView.isCurrentItem) {
            return Style.current.menuBackgroundActive
        }
        if (wrapper.hovered) {
            return Style.current.menuBackgroundHover
        }
        return Style.current.transparent
    }

    property string profileImage: realChatType === Constants.chatTypeOneToOne ? appMain.getProfileImage(chatId) || ""  : ""

    // Hide the box if it is filtered out
    property bool isVisible: categoryId === filterCategory && (searchStr === "" || name.includes(searchStr))
    
    id: wrapper
    anchors.top: applicationWindow.top
    visible: isVisible ? true : false
    height: isVisible ? rectangle.height + (isCompact ? 4 : Style.current.halfPadding) : 0

    Rectangle {
        Connections {
            enabled: realChatType === Constants.chatTypeOneToOne
            target: profileModel.contacts.list
            function onContactChanged(pubkey) {
                if (pubkey === wrapper.chatId) {
                    wrapper.profileImage = appMain.getProfileImage(wrapper.chatId)
                }
            }
        }

        id: rectangle
        color: wrapper.color
        radius: 8
        height: !isCompact ? 64 : 40
        width: parent.width

        StatusIdenticon {
            id: contactImage
            height: !isCompact ? 40 : 28
            width: !isCompact ? 40 : 28
            chatId: wrapper.chatId
            chatName: wrapper.name
            chatType: wrapper.realChatType
            identicon: wrapper.profileImage || wrapper.identicon
            anchors.left: parent.left
            anchors.leftMargin: !isCompact ? Style.current.padding : Style.current.smallPadding
            anchors.verticalCenter: parent.verticalCenter
        }

        SVGImage {
            id: channelIcon
            width: 16
            height: 16
            fillMode: Image.PreserveAspectFit
            source: "../../../img/channel-icon-" + (wrapper.realChatType === Constants.chatTypePublic ? "public-chat.svg" : "group.svg")
            anchors.left: contactImage.right
            anchors.leftMargin: !isCompact ? Style.current.padding : Style.current.smallPadding
            anchors.top: !isCompact ? parent.top : undefined
            anchors.topMargin: !isCompact ? Style.current.smallPadding : 0
            anchors.verticalCenter: !isCompact ? undefined : parent.verticalCenter
            visible: wrapper.realChatType !== Constants.chatTypeOneToOne
        }

        StyledText {
            id: contactInfo
            text: wrapper.realChatType !== Constants.chatTypePublic ?
                      Emoji.parse(Utils.removeStatusEns(Utils.filterXSS(wrapper.name))) :
                      "#" + Utils.filterXSS(wrapper.name)
            anchors.right: contactTime.visible ? contactTime.left : parent.right
            anchors.rightMargin: Style.current.smallPadding
            elide: Text.ElideRight
            color: muted ? Style.current.secondaryText : Style.current.textColor
            font.weight: Font.Medium
            font.pixelSize: 15
            anchors.left: channelIcon.visible ? channelIcon.right : contactImage.right
            anchors.leftMargin: channelIcon.visible ? 2 :
                                                      (!isCompact ? Style.current.padding : Style.current.halfPadding)
            anchors.top: !isCompact ? parent.top : undefined
            anchors.topMargin: !isCompact ? Style.current.smallPadding : 0
            anchors.verticalCenter: !isCompact ? undefined : parent.verticalCenter
        }

        StyledText {
            id: lastChatMessage
            visible: !isCompact
            text: {
                switch(contentType){
                    //% "Image"
                case Constants.imageType: return qsTrId("image");
                    //% "Sticker"
                case Constants.stickerType: return qsTrId("sticker");
                    //% "No messages"
                default: return lastMessage ? Emoji.parse(Utils.filterXSS(lastMessage)).replace(/\n|\r/g, ' ') : qsTrId("no-messages")
                }
            }
            textFormat: Text.RichText
            clip: true // This is needed because emojis don't ellide correctly
            anchors.right: contactNumberChatsCircle.left
            anchors.rightMargin: Style.current.smallPadding
            elide: Text.ElideRight
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.current.smallPadding
            font.pixelSize: 15
            anchors.left: contactImage.right
            anchors.leftMargin: Style.current.padding
            color: Style.current.secondaryText
        }

        StyledText {
            id: contactTime
            visible: !isCompact
            text: Utils.formatDateTime(wrapper.timestamp, globalSettings.locale)
            anchors.right: parent.right
            anchors.rightMargin: Style.current.padding
            anchors.top: parent.top
            anchors.topMargin: Style.current.smallPadding
            font.pixelSize: 11
            color: Style.current.secondaryText
        }
        Rectangle {
            id: contactNumberChatsCircle
            width: 22
            height: 22
            radius: 50
            anchors.right: parent.right
            anchors.rightMargin: !isCompact ? Style.current.padding : Style.current.smallPadding
            anchors.bottom: !isCompact ? parent.bottom : undefined
            anchors.bottomMargin: !isCompact ? Style.current.smallPadding : 0
            anchors.verticalCenter: !isCompact ? undefined : parent.verticalCenter
            color: Style.current.blue
            visible: (unviewedMessagesCount > 0) || wrapper.mentionsCount > 0
            StyledText {
                id: contactNumberChats
                text: wrapper.mentionsCount > 0 ? '@' : (wrapper.unviewedMessagesCount < 100 ? wrapper.unviewedMessagesCount : "99+")
                font.pixelSize: 12
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                color: Style.current.white
            }
        }

        MouseArea {
            enabled: enableMouseArea
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                wrapper.hovered = true
            }
            onExited: {
                wrapper.hovered = false
            }
            onClicked: {
                if (mouse.button & Qt.RightButton) {
                    chatsModel.channelView.setContextChannel(chatId)
                    channelContextMenu.openMenu(chatsModel.channelView.contextChannel, index)
                    return;
                }
                chatGroupsListView.currentIndex = index
                chatsModel.channelView.setActiveChannelByIndex(index)
            }
        }

    }
}



/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";height:64;width:640}
}
##^##*/
