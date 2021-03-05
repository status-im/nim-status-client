import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtQuick.Dialogs 1.3
import QtGraphicalEffects 1.13
import "../shared"
import "../shared/status"
import "../imports"
import "./Login"

Item {
    property var onGenKeyClicked: function () {}
    property var onExistingKeyClicked: function () {}
    property bool loading: false

    id: loginView
    anchors.fill: parent

    function setCurrentFlow(isLogin) {
        loginModel.isCurrentFlow = isLogin;
        onboardingModel.isCurrentFlow = !isLogin;
    }

    Component.onCompleted: {
        txtPassword.forceActiveFocus(Qt.MouseFocusReason)
    }

    Item {
        id: element
        width: 360
        height: 200
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter

        StatusImageIdenticon {
            id: userImage
            anchors.horizontalCenter: parent.horizontalCenter
            source: loginModel.currentAccount.thumbnailImage
        }

        StyledText {
            id: usernameText
            text: loginModel.currentAccount.username
            font.weight: Font.Bold
            font.pixelSize: 17
            anchors.top: userImage.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
        }

        ConfirmAddExistingKeyModal {
            id: confirmAddExstingKeyModal
            onOpenModalClick: function () {
                setCurrentFlow(false);
                onExistingKeyClicked()
            }
        }

        SelectAnotherAccountModal {
            id: selectAnotherAccountModal
            onAccountSelect: function (index) {
                loginModel.setCurrentAccount(index)
            }
            onOpenModalClick: function () {
                setCurrentFlow(true);
                onExistingKeyClicked()
            }
        }

        Rectangle {
            property bool isHovered: false
            id: changeAccountBtn
            width: 24
            height: 24
            anchors.left: usernameText.right
            anchors.leftMargin: 4
            anchors.verticalCenter: usernameText.verticalCenter

            color: isHovered ? Style.current.backgroundHover : Style.current.transparent

            radius: 4

            SVGImage {
                id: caretImg
                width: 10
                height: 6
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                source: "../app/img/caret.svg"
                fillMode: Image.PreserveAspectFit
            }
            ColorOverlay {
                anchors.fill: caretImg
                source: caretImg
                color: Style.current.secondaryText
            }
            MouseArea {
                hoverEnabled: true
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    changeAccountBtn.isHovered = true
                }
                onExited: {
                    changeAccountBtn.isHovered = false
                }
                onClicked: {
                    if (loginModel.rowCount() > 1) {
                        selectAnotherAccountModal.open()
                    } else {
                        confirmAddExstingKeyModal.open()
                    }
                }
            }
        }

        Address {
            id: addressText
            width: 90
            text: loginModel.currentAccount.address
            font.pixelSize: 15
            anchors.top: usernameText.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Input {
            id: txtPassword
            anchors.top: addressText.bottom
            anchors.topMargin: Style.current.padding * 2
            //% "Enter password"
            placeholderText: qsTrId("enter-password")
            textField.echoMode: TextInput.Password
            textField.focus: true
            Keys.onReturnPressed: {
                submitBtn.clicked()
            }
            onTextEdited: {
                errMsg.visible = false
                loading = false
            }
        }
        StatusRoundButton {
            id: submitBtn
            size: "medium"
            icon.name: "arrow-right"
            icon.width: 18
            icon.height: 14
            visible: txtPassword.text.length > 0
            anchors.left: txtPassword.right
            anchors.leftMargin: Style.current.padding
            anchors.verticalCenter: txtPassword.verticalCenter
            state: loading ? "pending" : "default"
            onClicked: {
                if (loading) {
                    return;
                }
                setCurrentFlow(true);
                loading = true
                loginModel.login(txtPassword.textField.text)
            }
        }

        Connections {
            target: loginModel
            ignoreUnknownSignals: true
            onLoginResponseChanged: {
                if (error) {
                    errorSound.play()
                    errMsg.visible = true;

                }
            }
        }

        StatusButton {
            id: generateKeysLinkText
            //% "Generate new keys"
            text: qsTrId("generate-new-keys")
            anchors.top: txtPassword.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 13
            type: "secondary"
            onClicked: {
                setCurrentFlow(false);
                onGenKeyClicked()
            }
        }

        StyledText {
            id: errMsg
            anchors.top: generateKeysLinkText.bottom
            anchors.topMargin: Style.current.smallPadding
            anchors.horizontalCenter: parent.horizontalCenter
            visible: false
            //% "Login failed. Please re-enter your password and try again."
            text: qsTrId("login-failed--please-re-enter-your-password-and-try-again-")
            font.pixelSize: 13
            color: Style.current.danger
        }
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;formeditorColor:"#ffffff";formeditorZoom:0.75;height:480;width:640}
}
##^##*/
