import QtQuick 2.13
import QtQuick.Controls 2.13
import "../../imports"
import "../../shared"
import "../../shared/status"

Item {
    id: root

    property string chatId
    property string chatName
    property int chatType
    property string identicon
    property int identiconSize: 40
    property bool isCompact: false

    property string profileImage: chatType === Constants.chatTypeOneToOne ? chatView.getProfileImage(chatId) || ""  : ""

    height: 48
    width: nameAndInfo.width + chatIdenticon.width + Style.current.smallPadding

    Connections {
        enabled: chatType === Constants.chatTypeOneToOne
        target: profileModel.contacts.list
        onContactChanged: {
            if (pubkey === root.chatId) {
                root.profileImage = chatView.getProfileImage(root.chatId)
            }
        }
    }

    StatusIdenticon {
        id: chatIdenticon
        chatType: root.chatType
        chatName: root.chatName
        identicon: root.profileImage || root.identicon
        width: root.isCompact ? 20 : root.identiconSize
        height: root.isCompact ? 20 : root.identiconSize
        anchors.verticalCenter: parent.verticalCenter
    }

    Item {
        id: nameAndInfo
        height: chatName.height + chatInfo.height
        width: (chatName.width > chatInfo.width ? chatName.width : chatInfo.width) 
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: chatIdenticon.right
        anchors.leftMargin: Style.current.smallPadding

        StyledText {
            id: chatName
            text: {
                switch(root.chatType) {
                    case Constants.chatTypePublic: return "#" + root.chatName;
                    case Constants.chatTypeOneToOne: return Utils.removeStatusEns(root.chatName)
                    default: return root.chatName
                }
            }

            font.weight: Font.Medium
            font.pixelSize: 15
        }


        Connections {
            target: profileModel.contacts
            onContactChanged: {
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
            color: Style.current.darkGrey
            text: {
                switch(root.chatType){
                    //% "Public chat"
                    case Constants.chatTypePublic: return qsTrId("public-chat")
                    case Constants.chatTypeOneToOne: return (profileModel.contacts.isAdded(root.chatId) ?
                    //% "Contact"
                    qsTrId("chat-is-a-contact") :
                    //% "Not a contact"
                    qsTrId("chat-is-not-a-contact"))
                    case Constants.chatTypePrivateGroupChat: 
                        let cnt = chatsModel.activeChannel.members.rowCount();
                        //% "%1 members"
                        if(cnt > 1) return qsTrId("%1-members").arg(cnt);
                        //% "1 member"
                        return qsTrId("1-member");
                    default: return "...";
                }
            }
            font.pixelSize: 12
            anchors.top: chatName.bottom
        }
    }
}

