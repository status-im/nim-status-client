import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"

ModalPopup {
    id: popup
    title: qsTr("Sync history for")

    property int defaultSyncPeriod: profileModel.mailservers.DefaultSyncPeriod 
    
    Column {
        id: column
        anchors.fill: parent
        anchors.rightMargin: Style.current.padding
        anchors.leftMargin: Style.current.padding

        spacing: 0

        ButtonGroup { id: syncSettings }

        StatusRadioButtonRow {
            text: qsTr("One day")
            buttonGroup: syncSettings
            checked: defaultSyncPeriod === Constants.fetchRangeLast24Hours
            onRadioCheckedChanged: {
                if (checked) {
                    profileModel.mailservers.setDefaultSyncPeriod(Constants.fetchRangeLast24Hours)
                }
            }
        }

        StatusRadioButtonRow {
            text: qsTr("Three days")
            buttonGroup: syncSettings
            checked: defaultSyncPeriod === Constants.fetchRangeLast3Days
            onRadioCheckedChanged: {
                if (checked) {
                    profileModel.mailservers.setDefaultSyncPeriod(Constants.fetchRangeLast3Days)
                }
            }
        }

        StatusRadioButtonRow {
            text: qsTr("One week")
            buttonGroup: syncSettings
            checked: defaultSyncPeriod === Constants.fetchRangeLast7Days
            onRadioCheckedChanged: {
                if (checked) {
                    profileModel.mailservers.setDefaultSyncPeriod(Constants.fetchRangeLast7Days)
                }
            }
        }

        StatusRadioButtonRow {
            text: qsTr("One month")
            buttonGroup: syncSettings
            checked: defaultSyncPeriod === Constants.fetchRangeLast31Days
            onRadioCheckedChanged: {
                if (checked) {
                    profileModel.mailservers.setDefaultSyncPeriod(Constants.fetchRangeLast31Days)
                }
            }
        }

    }
}
