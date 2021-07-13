import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"

Item {
    id: syncContainer
    Layout.fillHeight: true
    Layout.fillWidth: true
    property string activeMailserver: ""

    Connections {
        target: profileModel.mailservers
        onActiveMailserverChanged: (activeMailserver) => {
            syncContainer.activeMailserver = activeMailserver
        }
    }

    Component {
        id: syncHistoryModalComponent
        SyncHistoryModal {
            onClosed: {
                destroy()
            }
        }
    }

     Column {
        id: containerColumn
        anchors.top: parent.top
        anchors.topMargin: topMargin
        width: profileContainer.profileContentWidth

        anchors.horizontalCenter: parent.horizontalCenter

        StatusSettingsLineButton {
            id: syncHistoryBtn
            text: qsTr("Sync history for")
            currentValue: {
                switch(profileModel.mailservers.DefaultSyncPeriod){
                    case Constants.fetchRangeLast24Hours: return qsTr("One day")
                    case Constants.fetchRangeLast3Days: return qsTr("Three days")
                    case Constants.fetchRangeLast7Days: return qsTr("One week")
                    case Constants.fetchRangeLast31Days: return qsTr("One month")
                }
            }
            onClicked: openPopup(syncHistoryModalComponent)
        }

        Item {
            anchors.top: syncHistoryBtn.bottom
            anchors.topMargin: Style.current.padding
            
            Component {
                id: mailserversList
                
                StatusRadioButton {
                    id: rbSetMailsever
                    text: name
                    checked: name === activeMailserver.activeMailserver
                    onClicked: {
                        if (checked) {
                            profileModel.mailservers.setMailserver(name);
                        }
                    }
                }
            }

            Item {
                id: addMailserver
                width: parent.width
                height: addButton.height
                anchors.top: parent.top
                anchors.topMargin: 24
                anchors.left: parent.left
                anchors.leftMargin: 24

                StatusRoundButton {
                    id: addButton
                    icon.name: "plusSign"
                    size: "medium"
                    type: "secondary"
                    anchors.verticalCenter: parent.verticalCenter
                }

                        
                StyledText {
                    id: usernameText
                    //% "Add mailserver"
                    text: qsTrId("add-mailserver")
                    color: Style.current.blue
                    anchors.left: addButton.right
                    anchors.leftMargin: Style.current.padding
                    anchors.verticalCenter: addButton.verticalCenter
                    font.pixelSize: 15
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: addMailserverPopup.open()
                }

                ModalPopup {
                    id: addMailserverPopup
                    //% "Add mailserver"
                    title: qsTrId("add-mailserver")

                    property string nameValidationError: ""
                    property string enodeValidationError: ""
                    
                    function validate() {
                        nameValidationError = ""
                        enodeValidationError = ""
                        
                        if (nameInput.text === "") {
                            //% "You need to enter a name"
                            nameValidationError = qsTrId("you-need-to-enter-a-name")
                        }

                        if (enodeInput.text === "") {
                            //% "You need to enter the enode address"
                            enodeValidationError = qsTrId("you-need-to-enter-the-enode-address")
                        }
                        return !nameValidationError && !enodeValidationError
                    }

                    onOpened: {
                        nameInput.text = "";
                        enodeInput.text = "";
            
                        nameValidationError = "";
                        enodeValidationError = "";
                    }

                    footer: StatusButton {
                        anchors.right: parent.right
                        anchors.rightMargin: Style.current.smallPadding
                        //% "Save"
                        text: qsTrId("save")
                        anchors.bottom: parent.bottom
                        enabled: nameInput.text !== "" && enodeInput.text !== ""
                        onClicked: {
                            if (!addMailserverPopup.validate()) {
                                return;
                            }
                            profileModel.mailservers.save(nameInput.text, enodeInput.text)
                            addMailserverPopup.close()
                        }
                    }

                    Input {
                        id: nameInput
                        //% "Name"
                        label: qsTrId("name")
                        //% "Specify a name"
                        placeholderText: qsTrId("specify-name")
                        validationError: addMailserverPopup.nameValidationError
                    }

                    Input {
                        id: enodeInput
                        //% "History node address"
                        label: qsTrId("history-node-address")
                        //% "enode://{enode-id}:{password}@{ip-address}:{port-number}"
                        placeholderText: qsTrId("enode----enode-id---password---ip-address---port-number-")
                        validationError: addMailserverPopup.enodeValidationError
                        anchors.top: nameInput.bottom
                        anchors.topMargin: Style.current.bigPadding
                    }

                }
            }

            StyledText {
                id: switchLbl
                //% "Automatic mailserver selection"
                text: qsTrId("automatic-mailserver-selection")
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.top: addMailserver.bottom
                anchors.topMargin: 24
            }

            StatusSwitch {
                id: automaticSelectionSwitch
                checked: profileModel.mailservers.automaticSelection
                onCheckedChanged: profileModel.mailservers.enableAutomaticSelection(checked)
                anchors.top: addMailserver.bottom
                anchors.topMargin: Style.current.padding
                anchors.left: switchLbl.right
                anchors.leftMargin: Style.current.padding

            }

            StyledText {
                //% "..."
                text: profileModel.mailservers.activeMailserver || qsTrId("---")
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.top: switchLbl.bottom
                anchors.topMargin: 24
                visible: automaticSelectionSwitch.checked
            }

            ListView {
                id: mailServersListView
                anchors.topMargin: 200
                anchors.top: automaticSelectionSwitch.bottom
                anchors.fill: parent
                model: profileModel.mailservers.list
                delegate: mailserversList
                visible: !automaticSelectionSwitch.checked

                Component.onCompleted: {
                    profileModel.mailservers.getActiveMailserver()
                }
            }
        }
    }
}
