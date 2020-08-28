import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13

import "../../../imports"
import "../../../shared"
import "./components"
import "./ContactsColumn"

Item {
    property alias chatGroupsListViewCount: channelList.channelListCount
    property alias searchStr: searchBox.text

    id: contactsColumn
    Layout.fillHeight: true

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

    Button {
        text: "START"
        onClicked: {
            chatsModel.startRecording()
        }
        anchors.top: parent.top
        anchors.left: parent.left
    }

    Button {
        text: "STOP"
        onClicked: {
            chatsModel.stopRecording()
        }
        anchors.top: parent.top
        anchors.right: parent.right
    }


    PublicChatPopup {
        id: publicChatPopup
    }

    GroupChatPopup {
        id: groupChatPopup
    }

    PrivateChatPopup {
        id: privateChatPopup
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

    StackLayout {
        id: contactsStackView
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchBox.bottom
        anchors.topMargin: Style.current.padding

        function getCurrentIndex() {
            return channelList.channelListCount > 0 ? 1 : 0
        }

        currentIndex: getCurrentIndex()

        EmptyView {
            onCloseButtonPressed: function () {
                contactsStackView.currentIndex = 2
            }
        }

        ChannelList {
            id: channelList
            searchStr: contactsColumn.searchStr
            onChannelListCountChanged: {
                contactsStackView.currentIndex = contactsStackView.getCurrentIndex()
            }
        }

        ClosedEmptyView {}
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;formeditorColor:"#ffffff";height:480;width:640}
}
##^##*/
