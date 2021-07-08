import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Dialogs 1.3
import "../imports"
import "../shared"
import "../shared/status"

ModalPopup {
    property bool loading: false
    property bool firstPasswordFieldValid: false
    property bool repeatPasswordFieldValid: false
    property string passwordValidationError: ""
    property string repeatPasswordValidationError: ""

    id: popup
    //% "Create a password"
    title: qsTrId("intro-wizard-title-alt4")
    height: 500

    onOpened: {
        firstPasswordField.text = "";
        firstPasswordField.forceActiveFocus(Qt.MouseFocusReason)
    }

    Input {
        id: firstPasswordField
        anchors.rightMargin: 56
        anchors.leftMargin: 56
        anchors.top: parent.top
        anchors.topMargin: 88
        //% "New password..."
        placeholderText: qsTrId("new-password...")
        textField.echoMode: TextInput.Password
        onTextChanged: {
            [firstPasswordFieldValid, passwordValidationError] =
                Utils.validatePasswords("first", firstPasswordField, repeatPasswordField);
        }
    }

    Input {
        id: repeatPasswordField
        enabled: firstPasswordFieldValid
        anchors.rightMargin: 0
        anchors.leftMargin: 0
        anchors.right: firstPasswordField.right
        anchors.left: firstPasswordField.left
        anchors.top: firstPasswordField.bottom
        anchors.topMargin: Style.current.xlPadding
        //% "Confirm password…"
        placeholderText: qsTrId("confirm-password…")
        textField.echoMode: TextInput.Password
        Keys.onReturnPressed: {
            submitBtn.clicked()
        }
        onTextChanged: {
            [repeatPasswordFieldValid, repeatPasswordValidationError] =
                Utils.validatePasswords("repeat", firstPasswordField, repeatPasswordField);
        }
    }

    StyledText {
        id: validationError
        text: {
            if (passwordValidationError !== "") return passwordValidationError;
            if (repeatPasswordValidationError !== "") return repeatPasswordValidationError;
            return "";
        }
        anchors.top: repeatPasswordField.bottom
        anchors.topMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: Style.current.xlPadding
        anchors.left: parent.left
        anchors.leftMargin: Style.current.xlPadding
        horizontalAlignment: Text.AlignHCenter
        color: Style.current.danger
        font.pixelSize: 11
    }

    StyledText {
        //% "At least 6 characters. You will use this password to unlock status on this device & sign transactions."
        text: qsTrId("at-least-6-characters-you-will-use-this-password-to-unlock-status-on-this-device-sign-transactions.")
        wrapMode: Text.WordWrap
        anchors.right: parent.right
        anchors.rightMargin: Style.current.xlPadding
        anchors.left: parent.left
        anchors.leftMargin: Style.current.xlPadding
        horizontalAlignment: Text.AlignHCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        color: Style.current.secondaryText
        font.pixelSize: 12
    }

    footer: Item {
        width: parent.width
        height: submitBtn.height

        StatusButton {
            id: submitBtn
            anchors.bottom: parent.bottom
            anchors.topMargin: Style.current.padding
            anchors.right: parent.right
            state: loading ? "pending" : "default"
            //% "Create password"
            text: qsTrId("create-password")

            enabled: firstPasswordFieldValid && repeatPasswordFieldValid && !loading

            MessageDialog {
                id: importError
                //% "Error importing account"
                title: qsTrId("error-importing-account")
                //% "An error occurred while importing your account: "
                text: qsTrId("an-error-occurred-while-importing-your-account:-")
                icon: StandardIcon.Critical
                standardButtons: StandardButton.Ok
                onVisibilityChanged: {
                    loading = false
                }
            }

            MessageDialog {
                id: importLoginError
                //% "Login failed"
                title: qsTrId("login-failed")
                //% "Login failed. Please re-enter your password and try again."
                text: qsTrId("login-failed.-please-re-enter-your-password-and-try-again.")
                icon: StandardIcon.Critical
                standardButtons: StandardButton.Ok
                onVisibilityChanged: {
                    loading = false
                }
            }

            Connections {
                target: onboardingModel
                ignoreUnknownSignals: true
                function onLoginResponseChanged(error) {
                    if (error) {
                        loading = false
                        importLoginError.open()
                    }
                }
            }

            onClicked: {
                loading = true
                loginModel.isCurrentFlow = false;
                onboardingModel.isCurrentFlow = true;
                const result = onboardingModel.storeDerivedAndLogin(repeatPasswordField.text);
                const error = JSON.parse(result).error
                if (error) {
                    importError.text += error
                    return importError.open()
                }
                onboardingModel.firstTimeLogin = true
            }
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";height:500;width:400}
}
##^##*/
