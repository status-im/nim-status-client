import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../shared"
import "../components"
AddButton {
    id: btnAdd
    width: 36
    height: 36

    onClicked: {
        let x = btnAdd.icon.x + btnAdd.icon.width / 2 - newChatMenu.width / 2
        newChatMenu.popup(x, btnAdd.icon.height + 10)
    }
    
    PopupMenu {
        id: newChatMenu
        Action {
            text: qsTr("Start new chat")
            icon.source: "../../../img/new_chat.svg"
            onTriggered: privateChatPopup.open()
        }
        Action {
            text: qsTr("Start group chat")
            icon.source: "../../../img/group_chat.svg"
            onTriggered: groupChatPopup.open()
        }
        Action {
            text: qsTr("Join public chat")
            icon.source: "../../../img/public_chat.svg"
            onTriggered: publicChatPopup.open()
        }
        onAboutToHide: {
            btnAdd.icon.state = "default"
        }
    }
}
