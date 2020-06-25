import QtQuick 2.13
import QtQuick.Layouts 1.13
import "../../../imports"
import "../../../shared"
import "./LeftTab"

ColumnLayout {
    property alias currentTab: profileMenu.profileCurrentIndex

    id: profileInfoContainer
    spacing: 0
    anchors.left: parent.left
    anchors.leftMargin: 0
    anchors.top: parent.top
    anchors.topMargin: 0
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 0

    RowLayout {
        id: profileHeader
        height: 240
        Layout.fillWidth: true

        Profile {
            username: profileModel.profile.username
            identicon: profileModel.profile.identicon
            pubkey: profileModel.profile.id
        }
    }

    RowLayout {
        height: profileMenu.btnheight * 10
        Layout.fillHeight: true
        Layout.fillWidth: true

        Menu {
            id: profileMenu
        }
    }
}
