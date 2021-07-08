import QtQuick 2.13
import Qt.labs.platform 1.1
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13

import "../../../imports"
import "../../../shared"
import "../../../shared/status"
import "./components"
import "./ContactsColumn"
import "./CommunityComponents"

Rectangle {
    property alias chatGroupsListViewCount: channelList.channelListCount
    property alias searchStr: searchBox.text

    id: contactsColumn
    Layout.fillHeight: true
    color: Style.current.secondaryMenuBackground

    StyledText {
        id: title
        //% "Chat"
        text: qsTrId("chat")
        anchors.top: parent.top
        anchors.topMargin: Style.current.padding
        anchors.horizontalCenter: parent.horizontalCenter
        font.weight: Font.Bold
        font.pixelSize: 17
    }

    Component {
        id: publicChatPopupComponent
        PublicChatPopup {
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: groupChatPopupComponent
        GroupChatPopup {
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: privateChatPopupComponent
        PrivateChatPopup {
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: communitiesPopupComponent
        CommunitiesPopup {
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: createCommunitiesPopupComponent
        CreateCommunityPopup {
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: importCommunitiesPopupComponent
        AccessExistingCommunityPopup {
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: communityDetailPopup
        CommunityDetailPopup {
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: contactRequestsPopup
        ContactRequestsPopup {
            onClosed: {
                destroy()
            }
        }
    }

    SearchBox {
        id: searchBox
        anchors.top: title.bottom
        anchors.topMargin: Style.current.padding
        anchors.right: addChat.left
        anchors.rightMargin: Style.current.padding
        anchors.left: parent.left
        anchors.leftMargin: Style.current.padding
    }

    AddChat {
        id: addChat
        anchors.right: parent.right
        anchors.rightMargin: Style.current.padding
        anchors.top: title.bottom
        anchors.topMargin: Style.current.padding
    }

    Connections {
        target: profileModel.contacts
        function onContactRequestAdded(name, address) {
            if (!appSettings.notifyOnNewRequests) {
                return
            }
            const isContact = profileModel.contacts.isAdded(address)
            systemTray.showMessage(isContact ? qsTr("Contact request accepted") :
                                               qsTr("New contact request"),
                                   isContact ? qsTr("You can now chat with %1").arg(Utils.removeStatusEns(name)) :
                                               qsTr("%1 requests to become contacts").arg(Utils.removeStatusEns(name)),
                                   SystemTrayIcon.NoIcon,
                                   Constants.notificationPopupTTL)
        }
    }

    StatusSettingsLineButton {
        property int nbRequests: profileModel.contacts.contactRequests.count

        id: contactRequest
        anchors.top: searchBox.bottom
        anchors.topMargin: visible ? Style.current.padding : 0
        anchors.left: parent.left
        anchors.leftMargin: Style.current.halfPadding
        anchors.right: parent.right
        anchors.rightMargin: Style.current.halfPadding
        visible: nbRequests > 0
        height: visible ? implicitHeight : 0
        text: qsTr("Contact requests")
        isBadge: true
        badgeText: nbRequests.toString()
        onClicked: openPopup(contactRequestsPopup)
    }

    ScrollView {
        id: chatGroupsContainer
        anchors.top: contactRequest.bottom
        anchors.topMargin: Style.current.padding
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        leftPadding: Style.current.halfPadding
        rightPadding: Style.current.halfPadding
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        contentHeight: channelList.height + 2 * Style.current.padding + emptyViewAndSuggestions.height
        clip: true

        ChannelList {
            id: channelList
            searchStr: contactsColumn.searchStr.toLowerCase()
            channelModel: chatsModel.channelView.chats
        }

        EmptyView {
            id: emptyViewAndSuggestions
            width: parent.width
            anchors.top: channelList.bottom
            anchors.topMargin: Style.current.smallPadding
        }
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;formeditorColor:"#ffffff";height:480;width:640}
}
##^##*/
