import QtQuick 2.12
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3
import QtQml.Models 2.3
import QtGraphicalEffects 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"

ModalPopup {
    property string name: "Community name"
    property string description: "Description"
    // TODO get the real image once it's available
    property string source: "../../../img/ens-header-dark@2x.png"
    // TODO set real nb of members
    property int nbMembers: 12

    id: popup

    header: Item {
        height: childrenRect.height
        width: parent.width

        RoundedImage {
            id: communityImg
            source: popup.source
            width: 40
            height: 40
        }

        StyledTextEdit {
            id: communityName
            text:  popup.name
            anchors.top: parent.top
            anchors.topMargin: 2
            anchors.left: communityImg.right
            anchors.leftMargin: Style.current.smallPadding
            font.bold: true
            font.pixelSize: 17
            readOnly: true
        }

        StyledText {
            // TODO get this from access property
            text: qsTr("Public community")
            anchors.left: communityName.left
            anchors.top: communityName.bottom
            anchors.topMargin: 2
            font.pixelSize: 15
            font.weight: Font.Thin
            color: Style.current.secondaryText
        }
    }

    StyledText {
        id: descriptionText
        text: popup.description
        wrapMode: Text.WrapAnywhere
        width: parent.width
        font.pixelSize: 15
        font.weight: Font.Thin
    }

    Item {
        id: memberContainer
        width: parent.width
        height: memberImage.height
        anchors.top: descriptionText.bottom
        anchors.topMargin: Style.current.padding

        SVGImage {
            id: memberImage
            source: "../../../img/member.svg"
            width: 16
            height: 16
        }


        StyledText {
            text: qsTr("%1 members").arg(popup.nbMembers)
            wrapMode: Text.WrapAnywhere
            width: parent.width
            anchors.left: memberImage.right
            anchors.leftMargin: 4
            font.pixelSize: 15
            font.weight: Font.Medium
        }
    }


    Separator {
        id: sep1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: memberContainer.bottom
        anchors.topMargin: Style.current.smallPadding
        anchors.leftMargin: -Style.current.padding
        anchors.rightMargin: -Style.current.padding
    }

    
    footer: StatusButton {
        // TODO use real name
        text: qsTr("Join ‘%1’").arg(popup.name)
        anchors.right: parent.right
        onClicked: {
            console.log('JOIN')
        }
    }
}

