import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"

Item {
    id: aboutContainer
    Layout.fillHeight: true
    Layout.fillWidth: true
    clip: true

    Column {
        id: generalColumn
        spacing: Style.current.bigPadding
        anchors.top: parent.top
        anchors.topMargin: 46
        width: profileContainer.profileContentWidth
        anchors.horizontalCenter: parent.horizontalCenter

        StatusSectionDescItem {
            //% "App version"
            name: qsTrId("version")
            //% "Version: %1"
            description: qsTrId("version---1").arg(utilsModel.getCurrentVersion())
            tooltipUnder: true
        }

        StatusSectionDescItem {
            //% "Node version "
            name: qsTrId("node-version-")
            description: profileModel.nodeVersion()
        }

        StyledText {
            //% "Check for updates"
            text: qsTrId("check-for-updates")
            font.pixelSize: 15
            color: Style.current.blue

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: {
                    parent.font.underline = true
                }
                onExited: {
                    parent.font.underline = false
                }
                onClicked: {
                    utilsModel.checkForUpdates();
                    openPopup(downloadModalComponent, {newVersionAvailable: newVersionJSON.available, downloadURL: newVersionJSON.url})
                }
            }
        }

        StyledText {
            //% "Privacy Policy"
            text: qsTrId("privacy-policy")
            font.pixelSize: 15
            color: Style.current.blue

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: {
                    parent.font.underline = true
                }
                onExited: {
                    parent.font.underline = false
                }
                onClicked: {
                    appMain.openLink("https://status.im/privacy-policy/")
                }
            }
        }
    }
}

/*##^##
Designer {
    D{i:0;height:600;width:800}
}
##^##*/
