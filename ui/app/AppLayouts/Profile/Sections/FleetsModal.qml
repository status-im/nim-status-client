import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"

ModalPopup {
    id: popup
    //% "Fleet"
    title: qsTrId("fleet")

    property string newFleet: "";
    
    Column {
        id: column
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: Style.current.padding
        anchors.leftMargin: Style.current.padding

        spacing: 0

        ButtonGroup { id: fleetSettings }

        FleetRadioSelector {
            fleetName: Constants.eth_prod
        }

        FleetRadioSelector {
            fleetName: Constants.eth_staging
        }

        FleetRadioSelector {
            fleetName: Constants.eth_test
        }

        FleetRadioSelector {
            fleetName: Constants.waku_prod
        }

        FleetRadioSelector {
            fleetName: Constants.waku_test
        }
    }
}
