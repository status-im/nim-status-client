import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../shared"
import "../../../../shared/status"
import "../../../../imports"
import "../components"
import "./"

Button {
    implicitWidth: Math.max(communityImage.width + communityName.width + Style.current.padding, 200)
    implicitHeight: communityImage.height + Style.current.padding

    background: Rectangle {
        id: btnBackground
        radius: Style.current.radius
        color: Style.current.transparent
    }
    
    contentItem: Item {
        id: content
        Loader {
            id: communityImage
            anchors.verticalCenter: parent.verticalCenter
            active: true
            sourceComponent: !chatsModel.communities.activeCommunity.thumbnailImage ? letterIdenticon : imageIcon
        }

        Component {
            id: imageIcon
            RoundedImage {
                width: 40
                height: 40
                source: chatsModel.communities.activeCommunity.thumbnailImage
                noMouseArea: true
            }
        }

        Component {
            id: letterIdenticon
            StatusLetterIdenticon {
                width: 40
                height: 40
                chatName: chatsModel.communities.activeCommunity.name
                color: chatsModel.communities.activeCommunity.communityColor || Style.current.blue
            }
        }


        Item { 
            height: childrenRect.height
            width: childrenRect.width
            anchors.left: communityImage.right
            anchors.leftMargin: Style.current.halfPadding
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                id: communityName
                text: chatsModel.communities.activeCommunity.name
                font.pixelSize: 15
                font.weight: Font.Bold
            }

            StyledText {
                id: communityNbMember
                text: chatsModel.communities.activeCommunity.nbMembers === 1 ? 
                    qsTr("1 member") : 
                    qsTr("%1 members").arg(chatsModel.communities.activeCommunity.nbMembers)
                anchors.left: communityName.left
                anchors.top: communityName.bottom
                font.pixelSize: 14
                color: Style.current.secondaryText
            }
        }
    }

    MouseArea {
        id: mouseAreaBtn
        cursorShape: Qt.PointingHandCursor
        anchors.fill: parent
        onPressed: {
          communityProfilePopup.open();
        }
        hoverEnabled: true
        onExited: {
            btnBackground.color = Style.current.transparent
        }
        onEntered: {
            btnBackground.color = Style.current.backgroundHover
        }
    }
}
