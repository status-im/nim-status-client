import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../imports"
import "../../../shared"
import "./components"

Item {
    property var currentAccount: walletModel.currentAccount
    property var changeSelectedAccount

    id: walletHeader
    height: walletAddress.y + walletAddress.height
    anchors.right: parent.right
    anchors.rightMargin: 0
    anchors.left: parent.left
    anchors.leftMargin: 0
    anchors.top: parent.top
    anchors.topMargin: 0
    Layout.fillHeight: true
    Layout.fillWidth: true

    StyledText {
        id: title
        text: currentAccount.name
        anchors.top: parent.top
        anchors.topMargin: 56
        anchors.left: parent.left
        anchors.leftMargin: 24
        font.weight: Font.Medium
        font.pixelSize: 28
    }

    Rectangle {
        id: separatorDot
        width: 8
        height: 8
        color: Style.current.blue
        anchors.top: title.verticalCenter
        anchors.topMargin: -3
        anchors.left: title.right
        anchors.leftMargin: 8
        radius: 50
    }

    StyledText {
        id: walletBalance
        text: currentAccount.balance.toUpperCase()
        anchors.left: separatorDot.right
        anchors.leftMargin: 8
        anchors.verticalCenter: title.verticalCenter
        font.pixelSize: 22
    }

    Address {
        id: walletAddress
        text: currentAccount.address
        font.pixelSize: 13
        anchors.right: title.right
        anchors.rightMargin: 0
        anchors.top: title.bottom
        anchors.topMargin: 0
        anchors.left: title.left
        anchors.leftMargin: 0
        color: Style.current.secondaryText
    }

    SendModal{
        id: sendModal
        onOpened: {
          walletModel.getGasPricePredictions()
        }
    }

    ReceiveModal{
        id: receiveModal
        address: currentAccount.address
    }

    SetCurrencyModal{
        id: setCurrencyModal
    }

    TokenSettingsModal{
        id: tokenSettingsModal
    }

    AccountSettingsModal {
        id: accountSettingsModal
        changeSelectedAccount: walletHeader.changeSelectedAccount
    }

    AddCustomTokenModal {
        id: addCustomTokenModal
    }

    Item {
        property int btnMargin: 8
        property int btnOuterMargin: Style.current.bigPadding
        id: walletMenu
        width: sendBtn.width + receiveBtn.width + settingsBtn.width
               + walletMenu.btnOuterMargin * 2
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16

        HeaderButton {
            id: sendBtn
            imageSource: "../../img/send.svg"
            text: qsTr("Send")
            onClicked: function () {
                sendModal.open()
            }
        }

        HeaderButton {
            id: receiveBtn
            imageSource: "../../img/send.svg"
            flipImage: true
            text: qsTr("Receive")
            onClicked: function () {
                receiveModal.open()
            }
            anchors.left: sendBtn.right
            anchors.leftMargin: walletMenu.btnOuterMargin
        }

        HeaderButton {
            id: settingsBtn
            imageSource: "../../img/settings.svg"
            flipImage: true
            text: ""
            onClicked: function () {
                // FIXME the button is too much on the right, so the arrow can never align
                let x = settingsBtn.x + settingsBtn.width / 2 - newSettingsMenu.width / 2
                newSettingsMenu.popup(x, settingsBtn.height)
            }
            anchors.left: receiveBtn.right
            anchors.leftMargin: walletMenu.btnOuterMargin

            PopupMenu {
                id: newSettingsMenu
                width: 280
                Action {
                    //% "Account Settings"
                    text: qsTrId("account-settings")
                    icon.source: "../../img/walletIcon.svg"
                    onTriggered: {
                        accountSettingsModal.open()
                    }
                }
                Action {
                    //% "Add/Remove Tokens"
                    text: qsTrId("add/remove-tokens")
                    icon.source: "../../img/add_remove_token.svg"
                    onTriggered: {
                        tokenSettingsModal.open()
                    }
                }
                Action {
                    //% "Set Currency"
                    text: qsTrId("set-currency")
                    icon.source: "../../img/globe.svg"
                    onTriggered: {
                        setCurrencyModal.open()
                    }
                }
            }
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff"}
}
##^##*/
