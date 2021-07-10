import QtQuick 2.13
import QtQuick.Controls 2.13
import "../../../../shared"
import "../../../../shared/status"
import "../../../../imports"
import "../components"

Item {
    property string publicKey: ""
    property string name: "channelName"
    property string lastSeen: ""
    property string identicon
    property int statusType: Constants.statusType_Online
    property bool hovered: false
    property bool enableMouseArea: true
    property var currentTime
    property color color: {
        if (wrapper.hovered) {
            return Style.current.menuBackgroundHover
        }
        return Style.current.transparent
    }

    property string profileImage: appMain.getProfileImage(publicKey) || ""
    property bool isCurrentUser: publicKey === profileModel.profile.pubKey
    id: wrapper
    anchors.right: parent.right
    anchors.top: applicationWindow.top
    anchors.left: parent.left
    height: rectangle.height + 4

    Rectangle {
        Connections {
            target: profileModel.contacts.list
            onContactChanged: {
                if (pubkey === wrapper.publicKey) {
                    wrapper.profileImage = appMain.getProfileImage(wrapper.publicKey)
                }
            }
        }

        id: rectangle
        color: wrapper.color
        radius: 8
        height: 40
        width: parent.width

        StatusIdenticon {
            id: contactImage
            height: 28
            width: 28
            chatId: wrapper.publicKey
            chatName: wrapper.name
            chatType: Constants.chatTypeOneToOne
            identicon: wrapper.profileImage || wrapper.identicon
            anchors.left: parent.left
            anchors.leftMargin: Style.current.smallPadding
            anchors.verticalCenter: parent.verticalCenter
        }


        StyledText {
            id: contactInfo
            text: Emoji.parse(Utils.removeStatusEns(Utils.filterXSS(wrapper.name))) + (isCurrentUser ? " " + qsTrId("(you)") : "")
            anchors.right: parent.right
            anchors.rightMargin: Style.current.smallPadding
            elide: Text.ElideRight
            color: Style.current.textColor
            font.weight: Font.Medium
            font.pixelSize: 15
            anchors.left: contactImage.right
            anchors.leftMargin: Style.current.halfPadding
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            anchors.left: contactImage.right
            anchors.leftMargin: -Style.current.smallPadding
            anchors.bottom: contactImage.bottom
            height: 10
            width: 10
            radius: 20
            color: {
                let lastSeenMinutesAgo = (currentTime/1000 - parseInt(lastSeen)) / 60
                
                if (!chatsModel.isOnline) {
                    return Style.current.darkGrey 
                }

                if (isCurrentUser || lastSeenMinutesAgo < 5){
                    return statusType == Constants.statusType_DoNotDisturb ? Style.current.red : Style.current.green;
                } else if (lastSeenMinutesAgo < 20) {
                    return statusType == Constants.statusType_DoNotDisturb ? Style.current.red : Style.current.orange;
                }

                return Style.current.darkGrey
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
                console.log("TODO: do something")
            }
        }

    }
}



/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";height:64;width:640}
}
##^##*/
