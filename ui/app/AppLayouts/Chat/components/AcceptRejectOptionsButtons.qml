import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"

Row {
    signal acceptClicked()
    signal declineClicked()
    signal blockClicked()
    signal profileClicked()

    id: root
    height: acceptBtn.height
    spacing: Style.current.halfPadding

    StatusIconButton {
        id: acceptBtn
        icon.name: "check-circle"
        onClicked: root.acceptClicked()
        width: 32
        height: 32
        padding: 6
        iconColor: Style.current.success
        hoveredIconColor: Style.current.success
        highlightedBackgroundColor: Utils.setColorAlpha(Style.current.success, 0.1)
        anchors.verticalCenter: parent.verticalCenter
    }

    StatusIconButton {
        id: declineBtn
        icon.name: "close"
        onClicked: root.declineClicked()
        width: 32
        height: 32
        padding: 6
        iconColor: Style.current.danger
        hoveredIconColor: Style.current.danger
        highlightedBackgroundColor: Utils.setColorAlpha(Style.current.danger, 0.1)
        anchors.verticalCenter: parent.verticalCenter
    }

    StatusContextMenuButton {
        property int iconSize: 14
        id: menuButton
        anchors.verticalCenter: parent.verticalCenter

        MouseArea {
            id: mouseArea
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent

            onClicked: {
                contactContextMenu.popup()
            }
        }

        PopupMenu {
            id: contactContextMenu
            hasArrow: false
            Action {
                icon.source: "../../../img/profileActive.svg"
                icon.width: menuButton.iconSize
                icon.height: menuButton.iconSize
                //% "View Profile"
                text: qsTrId("view-profile")
                onTriggered: root.profileClicked()
                enabled: true
            }
            Separator {}
            Action {
                icon.source: "../../../img/block-icon.svg"
                icon.width: menuButton.iconSize
                icon.height: menuButton.iconSize
                icon.color: Style.current.danger
                text: qsTr("Decline and block")
                onTriggered: root.blockClicked()
            }
        }
    }
}
