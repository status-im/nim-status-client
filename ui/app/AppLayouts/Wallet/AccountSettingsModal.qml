import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtQuick.Dialogs 1.3
import "../../../imports"
import "../../../shared"
import "../../../sounds"

ModalPopup {
    property var currentAccount: walletModel.currentAccount
    property var changeSelectedAccount
    id: popup
    // TODO add icon when we have that feature
    title: qsTr("Status account settings")
    height: 635

    property int marginBetweenInputs: 35
    property string selectedColor: currentAccount.iconColor
    property string accountNameValidationError: ""

    function validate() {
        if (accountNameInput.text === "") {
            accountNameValidationError = qsTr("You need to enter an account name")
        } else {
            accountNameValidationError = ""
        }

        return accountNameValidationError === ""
    }

    onOpened: {
        accountNameInput.forceActiveFocus(Qt.MouseFocusReason)
    }

    Item {
        ErrorSound {
            id: errorSound
        }
    }

    Input {
        id: accountNameInput
        placeholderText: qsTr("Enter an account name...")
        label: qsTr("Account name")
        text: currentAccount.name
        validationError: popup.accountNameValidationError
    }

    Select {
        id: accountColorInput
        anchors.top: accountNameInput.bottom
        anchors.topMargin: marginBetweenInputs
        bgColor: selectedColor
        label: qsTr("Account color")
        selectOptions: Constants.accountColors.map(color => {
            return {
                text: "",
                bgColor: color,
                height: 52,
                onClicked: function () {
                    selectedColor = color
                }
           }
        })
    }

    TextWithLabel {
        id: typeText
        label: qsTr("Type")
        text: {
            var result = ""
            switch (currentAccount.walletType) {
                case Constants.watchWalletType: result = qsTr("Watch-only"); break;
                case Constants.keyWalletType:
                case Constants.seedWalletType: result = qsTr("Off Status tree"); break;
                default: result = qsTr("On Status tree")
            }
            return result
        }
        anchors.top: accountColorInput.bottom
        anchors.topMargin: marginBetweenInputs
    }

    TextWithLabel {
        id: addressText
        label: qsTr("Wallet address")
        text: currentAccount.address
        fontFamily: Style.current.fontHexRegular.name
        anchors.top: typeText.bottom
        anchors.topMargin: marginBetweenInputs
    }

    TextWithLabel {
        id: pathText
        label: qsTr("Derivation path")
        text: currentAccount.path
        anchors.top: addressText.bottom
        anchors.topMargin: marginBetweenInputs
    }

    TextWithLabel {
        id: storageText
        visible: currentAccount.walletType !== Constants.watchWalletType
        label: qsTr("Storage")
        text: qsTr("This device")
        anchors.top: pathText.bottom
        anchors.topMargin: marginBetweenInputs
    }

    footer: Item {
        anchors.fill: parent
        StyledButton {
            anchors.top: parent.top
            anchors.right: saveBtn.left
            anchors.rightMargin: Style.current.padding
            label: qsTr("Delete account")
            btnColor: Style.current.white
            textColor: Style.current.red

            MessageDialog {
                id: deleteError
                title: "Deleting account failed"
                icon: StandardIcon.Critical
                standardButtons: StandardButton.Ok

            }

            MessageDialog {
                id: confirmationDialog
                title: qsTr("Are you sure?")
                text: qsTr("A deleted account cannot be retrieved later. Only press yes if you backed up your key/seed or don't care about this account anymore")
                icon: StandardIcon.Warning
                standardButtons: StandardButton.Yes |  StandardButton.No
                onAccepted: {
                    const error = walletModel.deleteAccount(currentAccount.address);
                    if (error) {
                        errorSound.play()
                        deleteError.text = error
                        deleteError.open()
                        return
                    }

                    // Change active account to the first
                    changeSelectedAccount(0)
                    popup.close();
                }
            }

            onClicked : {
                confirmationDialog.open()
            }
        }
        StyledButton {
            id: saveBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: Style.current.padding
            label: qsTr("Save changes")

            disabled: accountNameInput.text === ""

            MessageDialog {
                id: changeError
                title: "Changing settings failed"
                icon: StandardIcon.Critical
                standardButtons: StandardButton.Ok
            }

            onClicked : {
                if (!validate()) {
                    return
                }

                const error = walletModel.changeAccountSettings(currentAccount.address, accountNameInput.text, selectedColor);

                if (error) {
                    errorSound.play()
                    changeError.text = error
                    changeError.open()
                    return
                }
                popup.close();
            }
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";height:500;width:400}
}
##^##*/
