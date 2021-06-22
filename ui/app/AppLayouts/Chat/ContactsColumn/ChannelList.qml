import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../shared"
import "../../../../imports"
import "../components"
import "./"

Item {
    property var channelModel
    property alias channelListCount: chatGroupsListView.count
    property string searchStr: ""
    property string categoryId: ""
    id: channelListContent
    width: parent.width
    height: childrenRect.height

    Timer {
        id: timer
    }

    ListView {
        id: chatGroupsListView
        spacing: 0
        anchors.top: parent.top
        height: childrenRect.height
        visible: height > (appSettings.useCompactMode ? 30 : 50)
        anchors.right: parent.right
        anchors.left: parent.left
        interactive: false
        model: channelListContent.channelModel
        delegate: Channel {
            name: model.name
            muted: model.muted
            lastMessage: model.lastMessage
            timestamp: model.timestamp
            chatType: model.chatType
            identicon: model.identicon
            unviewedMessagesCount: model.unviewedMessagesCount
            hasMentions: model.hasMentions
            contentType: model.contentType
            searchStr: channelListContent.searchStr
            categoryId: model.categoryId
            filterCategory: channelListContent.categoryId
            chatId: model.id
        }
        onCountChanged: {
            if (count > 0 && chatsModel.channelView.activeChannelIndex > -1) {
                currentIndex = chatsModel.channelView.activeChannelIndex;
            } else {
                if (chatsModel.channelView.activeChannelIndex > -1) {
                    chatGroupsListView.currentIndex = 0;
                } else {
                    // Initial state. No chat has been selected yet
                    chatGroupsListView.currentIndex = -1;
                }
            }
        }
    }

    Item {
        id: noSearchResults
        anchors.top: parent.top
        height: visible ? 300 : 0
        visible: !chatGroupsListView.visible && channelListContent.searchStr !== ""
        anchors.left: parent.left
        anchors.right: parent.right

        StyledText {
            font.pixelSize: 15
            color: Style.current.secondaryText
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            //% "No search results"
            text: qsTrId("no-search-results")
        }
    }

    ChannelContextMenu {
        id: channelContextMenu
    }

    Connections {
        target: chatsModel.channelView.chats
        onDataChanged: {
            // If the current active channel receives messages and changes its position,
            // refresh the currentIndex accordingly
            if(chatsModel.channelView.activeChannelIndex !== chatGroupsListView.currentIndex){
                chatGroupsListView.currentIndex = chatsModel.channelView.activeChannelIndex
            }
        }
    }

    Connections {
        target: chatsModel.channelView
        onActiveChannelChanged: {
            chatsModel.messageView.hideLoadingIndicator()
            chatGroupsListView.currentIndex = chatsModel.channelView.activeChannelIndex
            SelectedMessage.reset();
            chatColumn.isReply = false;
        }
    }
}


/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/
