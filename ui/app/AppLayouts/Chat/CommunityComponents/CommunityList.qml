import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../shared"
import "../../../../imports"
import "../components"
import "./"

Item {
    property string searchStr: ""
    id: root
    width: parent.width
    height: Math.max(communityListView.height, noSearchResults.height)
    ListView {
        id: communityListView
        spacing: Style.current.halfPadding
        anchors.top: parent.top
        height: childrenRect.height
        visible: height > 10
        width:parent.width
        interactive: false
        model: chatsModel.communities.joinedCommunities
        delegate: CommunityButton {
            communityId: model.id
            name: model.name
            description: model.description
            searchStr: root.searchStr
            image: model.thumbnailImage
        }
    }

    Item {
        id: noSearchResults
        anchors.top: parent.top
        height: visible ? 200 : 0
        visible: !communityListView.visible && root.searchStr !== ""
        width: parent.width

        StyledText {
            font.pixelSize: 15
            color: Style.current.darkGrey
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            //% "No search results in Communities"
            text: qsTrId("no-search-results-in-communities")
        }
    }
}


/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/
