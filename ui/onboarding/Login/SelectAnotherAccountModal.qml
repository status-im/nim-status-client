import QtQuick 2.12
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3
import "../../imports"
import "../../shared"

ModalPopup {
    property var onAccountSelect: function () {}
    property var onOpenModalClick: function () {}
    id: popup
    title: qsTr("Your accounts")

    AccountList {
        id: accountList
        anchors.fill: parent

        accounts: loginModel
        isSelected: function (index, address) {
            return loginModel.currentAccount.address === address
        }

        onAccountSelect: function(index) {
            popup.onAccountSelect(index)
            popup.close()
        }
    }

    footer: StyledButton {
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.padding
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding
        label: "Add another existing key"

        onClicked : {
           onOpenModalClick()
           popup.close()
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";height:500;width:400}
}
##^##*/
