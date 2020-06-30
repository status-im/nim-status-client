import QtQuick 2.13
import QtQuick.Dialogs 1.3
import "../../../../imports"
import "../../../../shared"
import "../../../../sounds"

ModalPopup {
    id: popup
    height: 600

    property int marginBetweenInputs: 38
    property string selectedColor: Constants.accountColors[0]
    property string passwordValidationError: ""
    property string seedValidationError: ""
    property string accountNameValidationError: ""
    property bool loading: false

    function validate() {
        if (passwordInput.text === "") {
            passwordValidationError = qsTr("You need to enter a password")
        } else if (passwordInput.text.length < 4) {
            passwordValidationError = qsTr("Password needs to be 4 characters or more")
        } else {
            passwordValidationError = ""
        }

        if (accountNameInput.text === "") {
            accountNameValidationError = qsTr("You need to enter an account name")
        } else {
            accountNameValidationError = ""
        }

        if (accountSeedInput.text === "") {
            seedValidationError = qsTr("You need to enter a seed phrase")
        } else if (!Utils.isMnemonic(accountSeedInput.text)) {
            seedValidationError = qsTr("Enter a valid mnemonic")
        } else {
            seedValidationError = ""
        }

        return passwordValidationError === "" && seedValidationError === "" && accountNameValidationError === ""
    }

    onOpened: {
        passwordInput.text = ""
        passwordInput.forceActiveFocus(Qt.MouseFocusReason)
    }

    title: qsTr("Add account with a seed phrase")

    Item {
        ErrorSound {
            id: errorSound
        }
    }

    Input {
        id: passwordInput
        placeholderText: qsTr("Enter your password…")
        label: qsTr("Password")
        textField.echoMode: TextInput.Password
        validationError: popup.passwordValidationError
    }


    StyledTextArea {
        id: accountSeedInput
        anchors.top: passwordInput.bottom
        anchors.topMargin: marginBetweenInputs
        placeholderText: qsTr("Enter your seed phrase, separate words with commas or spaces...")
        label: qsTr("Seed phrase")
        customHeight: 88
        validationError: popup.seedValidationError
    }

    Input {
        id: accountNameInput
        anchors.top: accountSeedInput.bottom
        anchors.topMargin: marginBetweenInputs
        placeholderText: qsTr("Enter an account name...")
        label: qsTr("Account name")
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

    footer: StyledButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding
        label: loading ? qsTr("Loading...") : qsTr("Add account >")

        disabled: loading || passwordInput.text === "" || accountNameInput.text === "" || accountSeedInput.text === ""

        MessageDialog {
            id: accountError
            title: "Adding the account failed"
            icon: StandardIcon.Critical
            standardButtons: StandardButton.Ok
        }

        onClicked : {
            // TODO the loaidng doesn't work because the function freezes th eview. Might need to use threads
            loading = true
            if (!validate()) {
                errorSound.play()
                return loading = false
            }

            const error = walletModel.addAccountsFromSeed(accountSeedInput.text, passwordInput.text, accountNameInput.text, selectedColor)
            loading = false
            if (error) {
                errorSound.play()
                accountError.text = error
                return accountError.open()
            }

            popup.close();
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";height:500;width:400}
}
##^##*/
