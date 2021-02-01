import QtQuick 2.13
import QtQuick.Controls 2.13
//import QtQuick.Layouts 1.13
//import Qt.labs.platform 1.1
import "../../../imports"
import "../../../shared"
import "../../../shared/status"
import "./components"

Item {
    function open() {
        popup.open()
        setCurrencyModalContent.currency = walletModel.defaultCurrency
    }

    function close() {
        popup.close()
    }

    ModalPopup {
        id: popup
        width: 480
        height: 510

        title: qsTr("Set Currency")

        SetCurrencyModalContent {
            id: setCurrencyModalContent
        }

        footer: StatusButton {
            anchors.right: parent.right
            //% "Save"
            text: qsTrId("save")
            onClicked: {
                console.log("TODO: apply all accounts")
                popup.close()
            }
        }
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/
