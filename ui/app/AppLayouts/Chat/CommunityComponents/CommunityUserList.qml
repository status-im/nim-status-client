import QtQuick 2.13
import Qt.labs.platform 1.1
import QtQuick.Controls 2.13
import QtQuick.Window 2.13
import QtQuick.Layouts 1.13
import QtQml.Models 2.13
import QtGraphicalEffects 1.13
import QtQuick.Dialogs 1.3
import "../../../../shared"
import "../../../../shared/status"
import "../../../../imports"
import "../components"
import "../ChatColumn/MessageComponents"
import "../ChatColumn/"
import "../ContactsColumn"

Rectangle {
    property QtObject community: chatsModel.communities.activeCommunity

    id: root

    color: Style.current.secondaryMenuBackground

    ListView {
        id: userListView
        anchors.fill: parent
        anchors.bottomMargin: Style.current.bigPadding
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds
        model: userListDelegate
    }
    
    DelegateModelGeneralized {
        id: userListDelegate
        lessThan: [
            function(left, right) { 
                return left.lastSeen > right.lastSeen 
            }
        ]
        model: community.members
        delegate: User {
            property string nickname: appMain.getUserNickname(model.pubKey)

            publicKey: model.pubKey
            name: !model.userName.endsWith(".eth") && !!nickname ? nickname : Utils.removeStatusEns(model.userName)
            identicon: model.identicon
            lastSeen: chatsModel.communities.activeCommunity.memberLastSeen(model.pubKey)
            currentTime: svRoot.currentTime
            statusType: chatsModel.communities.activeCommunity.memberStatus(model.pubKey)
        }
    }
}