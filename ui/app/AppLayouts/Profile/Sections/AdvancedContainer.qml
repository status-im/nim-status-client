import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtGraphicalEffects 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"

Item {
    id: advancedContainer
    Layout.fillHeight: true
    Layout.fillWidth: true
    clip: true

    Column {
        id: generalColumn
        anchors.top: parent.top
        anchors.topMargin: topMargin
        width: profileContainer.profileContentWidth

        anchors.horizontalCenter: parent.horizontalCenter

        StatusSettingsLineButton {
            //% "Network"
            text: qsTrId("network")
            currentValue: utilsModel.getNetworkName()
            onClicked: networksModal.open()
        }

        StatusSettingsLineButton {
            //% "Fleet"
            text: qsTrId("fleet")
            currentValue: profileModel.fleets.fleet
            onClicked: fleetModal.open()
        }

        StatusSettingsLineButton {
            text: qsTr("Minimize on close")
            isSwitch: true
            switchChecked: !appSettings.quitOnClose
            onClicked: function (checked) {
                appSettings.quitOnClose = !checked
            }
        }

        Item {
            id: spacer1
            height: Style.current.bigPadding
            width: parent.width
        }

        Separator {
            anchors.topMargin: Style.current.bigPadding
            anchors.left: parent.left
            anchors.leftMargin: -Style.current.padding
            anchors.right: parent.right
            anchors.rightMargin: -Style.current.padding
        }

        StatusSectionHeadline {
            //% "Experimental features"
            text: qsTrId("experimental-features")
            topPadding: Style.current.bigPadding
            bottomPadding: Style.current.padding
        }

        StatusSettingsLineButton {
            //% "Wallet"
            text: qsTrId("wallet")
            isSwitch: true
            switchChecked: appSettings.isWalletEnabled
            onClicked: {
                if (!appSettings.isWalletEnabled) {
                    confirmationPopup.settingsProp = "isWalletEnabled"
                    confirmationPopup.open()
                } else {
                    appSettings.isWalletEnabled = false
                }
            }
        }

        StatusSettingsLineButton {
            //% "Dapp Browser"
            text: qsTrId("dapp-browser")
            isSwitch: true
            switchChecked: appSettings.isBrowserEnabled
            onClicked: {
                if (!appSettings.isBrowserEnabled) {
                    confirmationPopup.settingsProp = "isBrowserEnabled"
                    confirmationPopup.open()
                } else {
                    appSettings.isBrowserEnabled = false
                }
            }
        }

        StatusSettingsLineButton {
            //% "Communities"
            text: qsTrId("communities")
            isSwitch: true
            switchChecked: appSettings.communitiesEnabled
            onClicked: {
                if (!appSettings.communitiesEnabled) {
                    confirmationPopup.settingsProp = "communitiesEnabled"
                    confirmationPopup.open()
                } else {
                    appSettings.communitiesEnabled = false
                }
            }
        }

        StatusSettingsLineButton {
            text: qsTr("Activity Center")
            isSwitch: true
            switchChecked: appSettings.isActivityCenterEnabled
            onClicked: {
                if (!appSettings.isActivityCenterEnabled) {
                    confirmationPopup.settingsProp = "isActivityCenterEnabled"
                    confirmationPopup.open()
                } else {
                    appSettings.isActivityCenterEnabled = false
                }
            }
        }

        StatusSettingsLineButton {
            id: onlineUsers
            text: qsTr("Online users")
            isSwitch: true
            switchChecked: appSettings.showOnlineUsers
            onClicked: {
                appSettings.showOnlineUsers = !appSettings.showOnlineUsers
            }
        }

        Loader {
            active: onlineUsers.switchChecked
            anchors.left: parent.left
            anchors.right: parent.right
            sourceComponent: StatusSettingsLineButton {
                text: qsTr("Broadcast user status")
                isSwitch: true
                switchChecked: profileModel.profile.sendUserStatus
                onClicked: function (checked) {
                    if (profileModel.profile.sendUserStatus !== checked) {
                        profileModel.setSendUserStatus(checked)
                    }
                }
            }
        }
        

        // StatusSettingsLineButton {
        //     //% "Node Management"
        //     text: qsTrId("node-management")
        //     isSwitch: true
        //     switchChecked: appSettings.nodeManagementEnabled
        //     onClicked: {
        //         if (!appSettings.nodeManagementEnabled) {
        //             confirmationPopup.settingsProp = "nodeManagementEnabled"
        //             confirmationPopup.open()
        //         } else {
        //             appSettings.nodeManagementEnabled = false
        //         }
        //     }
        // }
    }

    NetworksModal {
        id: networksModal
    }

    FleetsModal {
        id: fleetModal
    }

    ConfirmationDialog {
        id: confirmationPopup
        property string settingsProp: ""
        height: 310
        showCancelButton: true
        confirmationText: qsTr("This feature is experimental and is meant for testing purposes by core contributors and the community. It's not meant for real use and makes no claims of security or integrity of funds or data. Use at your own risk.")
        confirmButtonLabel: qsTr("I understand")
        onConfirmButtonClicked: {
            appSettings[settingsProp] = true
            settingsProp = ""
            close()
        }

        onCancelButtonClicked: {
            close()
        }
    }
}

/*##^##
Designer {
    D{i:0;height:400;width:700}
}
##^##*/
