import QtQuick 2.3
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.11
import QtQuick.Window 2.11
import QtQuick.Dialogs 1.3
import "../shared"

SwipeView {
    id: swipeView
    anchors.fill: parent
    currentIndex: 0

    onCurrentItemChanged: {
        currentItem.txtPassword.focus = true;
    }

    Item {
        id: wizardStep2
        property int selectedIndex: 0
        width: 620
        height: 427

        Text {
            id: title
            text: "Generated accounts"
            font.pointSize: 36
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Item {
            anchors.top: title.bottom
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: 20


                ButtonGroup {
                    id: accountGroup
                }

                Component {
                    id: addressViewDelegate

                    Item {
                        height: 56
                        anchors.right: parent.right
                        anchors.rightMargin: 0
                        anchors.left: parent.left
                        anchors.leftMargin: 0

                        Row {
                            RadioButton {
                                checked: index == 0 ? true : false
                                ButtonGroup.group: accountGroup
                                onClicked: {
                                    wizardStep2.selectedIndex = index
                                }
                            }
                            Column {
                                Image {
                                    source: identicon
                                }
                            }
                            Column {
                                Text {
                                    text: username
                                }
                                Text {
                                    text: key
                                    width: 160
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: addressesView
                    contentWidth: 200
                    model: onboardingModel
                    delegate: addressViewDelegate
                    anchors.fill: parent
                }

            StyledButton {
                label: "Select"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                onClicked: {
                    swipeView.incrementCurrentIndex();
                }
            }

        }
    }

    Item {
        id: wizardStep3
        property Item txtPassword: txtPassword

        Text {
            text: "Enter password"
            font.pointSize: 36
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            color: "#EEEEEE"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.centerIn: parent
            height: 32
            width: parent.width - 40
            TextInput {
                id: txtPassword
                anchors.fill: parent
                focus: true
                echoMode: TextInput.Password
                selectByMouse: true
            }
        }

        StyledButton {
            label: "Next"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            onClicked: {
                swipeView.incrementCurrentIndex();
            }
        }
    }

    Item {
        id: wizardStep4
        property Item txtPassword: txtConfirmPassword

        Text {
            text: "Confirm password"
            font.pointSize: 36
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            color: "#EEEEEE"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.centerIn: parent
            height: 32
            width: parent.width - 40

            TextInput {
                id: txtConfirmPassword
                anchors.fill: parent
                focus: true
                echoMode: TextInput.Password
                selectByMouse: true
            }
        }

        MessageDialog {
            id: passwordsDontMatchError
            title: "Error"
            text: "Passwords don't match"
            icon: StandardIcon.Warning
            standardButtons: StandardButton.Ok
            onAccepted: {
                txtConfirmPassword.clear();
                swipeView.currentIndex = 1;
                txtPassword.focus = true;
            }
        }

        MessageDialog {
            id: storeAccountAndLoginError
            title: "Error storing account and logging in"
            text: "An error occurred while storing your account and logging in: "
            icon: StandardIcon.Critical
            standardButtons: StandardButton.Ok
        }

        Connections {
            target: onboardingModel
            onLoginResponseChanged: {
              const loginResponse = JSON.parse(response);
              if(loginResponse.error){
                storeAccountAndLoginError.text += loginResponse.error;
                storeAccountAndLoginError.open()
              }
            }
        }

        StyledButton {
            label: "Finish"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            onClicked: {
                if (txtConfirmPassword.text != txtPassword.text) {
                    return passwordsDontMatchError.open();
                }
                const selectedAccountIndex = wizardStep2.selectedIndex
                onboardingModel.storeAccountAndLogin(selectedAccountIndex, txtPassword.text)
            }
        }
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;formeditorColor:"#ffffff";height:480;width:640}
}
##^##*/

