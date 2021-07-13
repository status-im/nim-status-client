import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtGraphicalEffects 1.13
import "../components"
import "../data/channelList.js" as ChannelJSON
import "../../../../shared"
import "../../../../shared/status"
import "../../../../imports"

Rectangle {
    id: emptyView
    Layout.fillHeight: true
    Layout.fillWidth: true

    height: suggestionContainer.height + inviteFriendsContainer.height + Style.current.padding * 2
    border.color: Style.current.secondaryMenuBorder
    radius: 16
    color: Style.current.transparent

    anchors.right: parent.right
    anchors.left: parent.left
    anchors.leftMargin: Style.current.padding
    anchors.rightMargin: Style.current.padding

    Item {
        id: inviteFriendsContainer
        height: visible ? 190 : 0
        anchors.top: parent.top
        anchors.topMargin: 0
        anchors.right: parent.right
        anchors.rightMargin: 0
        anchors.left: parent.left
        anchors.leftMargin: 0

        SVGImage {
            anchors.top: parent.top
            anchors.topMargin: -6
            anchors.horizontalCenter: parent.horizontalCenter
            source: "../../../img/chatEmptyHeader.svg"
            width: 66
            height: 50
        }

        StatusIconButton {
            icon.name: "close"
            id: closeImg
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            icon.height: 20
            icon.width: 20
            iconColor: Style.current.midGrey
        }

        MouseArea {
            anchors.fill: closeImg
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                appSettings.hideChannelSuggestions = true
            }
        }

        StyledText {
            id: chatAndTransactText
            //% "Chat and transact privately with your friends"
            text: qsTrId("chat-and-transact-privately-with-your-friends")
            anchors.top: parent.top
            anchors.topMargin: 56
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 15
            wrapMode: Text.WordWrap
            anchors.right: parent.right
            anchors.rightMargin: Style.current.xlPadding
            anchors.left: parent.left
            anchors.leftMargin: Style.current.xlPadding
        }

        StatusButton {
            //% "Invite friends"
            text: qsTrId("invite-friends")
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.current.xlPadding
            onClicked: {
                inviteFriendsPopup.open()
            }
        }

        InviteFriendsPopup {
            id: inviteFriendsPopup
        }
    }

    Separator {
        anchors.topMargin: 0
        anchors.top: inviteFriendsContainer.bottom
        color: Style.current.border
    }

    Item {
        id: suggestionContainer
        anchors.top: inviteFriendsContainer.bottom
        anchors.right: parent.right
        anchors.left: parent.left
        anchors.leftMargin: Style.current.padding
        anchors.rightMargin: Style.current.padding

        height: {
            if (!visible) return 0
            var totalHeight = 0
            for (let i = 0; i < sectionRepeater.count; i++) {
                totalHeight += sectionRepeater.itemAt(i).height + Style.current.padding
            }
            return suggestionsText.height + totalHeight + Style.current.smallPadding
        }

        StyledText {
            id: suggestionsText
            width: parent.width
            //% "Follow your interests in one of the many Public Chats."
            text: qsTrId("follow-your-interests-in-one-of-the-many-public-chats.")
            anchors.top: parent.top
            anchors.topMargin: Style.current.xlPadding
            font.pointSize: 15
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignTop
            horizontalAlignment: Text.AlignHCenter
            fontSizeMode: Text.FixedSize
            renderType: Text.QtRendering
            anchors.right: parent.right
            anchors.rightMargin: Style.current.xlPadding
            anchors.left: parent.left
            anchors.leftMargin: Style.current.xlPadding
        }

        Item {
            anchors.top: suggestionsText.bottom
            anchors.topMargin: Style.current.smallPadding
            width: parent.width

            SuggestedChannels {
                id: sectionRepeater
            }
        }
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;formeditorColor:"#ffffff";formeditorZoom:1.25;height:500;width:300}
}
##^##*/
