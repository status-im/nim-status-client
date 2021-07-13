import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"
import "./"

ModalPopup {
    function doJoin(pk, ensName) {
        chatsModel.channelView.joinPrivateChat(pk, Utils.isChatKey(pk) ? "" : ensName);
        popup.close();
    }

    id: popup
    //% "New chat"
    title: qsTrId("new-chat")

    onOpened: {
        contactFieldAndList.chatKey.text = ""
        contactFieldAndList.pubKey = ""
        contactFieldAndList.ensUsername = ""
        contactFieldAndList.chatKey.forceActiveFocus(Qt.MouseFocusReason)
        contactFieldAndList.existingContacts.visible = profileModel.contacts.list.hasAddedContacts()
        contactFieldAndList.noContactsRect.visible = !contactFieldAndList.existingContacts.visible
    }

    ContactsListAndSearch {
        id: contactFieldAndList
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        addContactEnabled: false
        onUserClicked: function (isContact, pubKey, ensName) {
            chatsModel.channelView.joinPrivateChat(pubKey, Utils.isChatKey(pubKey) ? "" : ensName);
            popup.close();
        }
    }
}

/*##^##
Designer {
    D{i:0;height:300;width:300}
}
##^##*/
