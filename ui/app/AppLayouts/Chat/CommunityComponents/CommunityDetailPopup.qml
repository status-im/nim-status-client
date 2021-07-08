import QtQuick 2.12
import QtQuick.Dialogs 1.3
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"
import "../ContactsColumn"

ModalPopup {
    property QtObject community: chatsModel.communities.observedCommunity
    property string communityId: community.id
    property string name: community.name
    property string description: community.description
    property int access: community.access
    property string source: community.thumbnailImage
    property int nbMembers: community.nbMembers
    property bool ensOnly: community.ensOnly
    property bool canJoin: community.canJoin
    property bool canRequestAccess: community.canRequestAccess
    property bool isMember: community.isMember
    property string communityColor: community.communityColor || Style.current.blue

    id: popup

    header: Item {
        height: childrenRect.height
        width: parent.width


        Loader {
            id: communityImg
            sourceComponent: !!popup.source ? commmunityImgCmp : letterIdenticonCmp
        }

        Component {
            id: commmunityImgCmp
            RoundedImage {
                source: popup.source
                width: 40
                height: 40
            }
        }

        Component {
            id: letterIdenticonCmp
            StatusLetterIdenticon {
                width: 40
                height: 40
                chatName: popup.name
                color: popup.communityColor
            }
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
            id: accessText
            text: {
                switch(access) {
                //% "Public community"
                case Constants.communityChatPublicAccess: return qsTrId("public-community");
                //% "Invitation only community"
                case Constants.communityChatInvitationOnlyAccess: return qsTrId("invitation-only-community");
                //% "On request community"
                case Constants.communityChatOnRequestAccess: return qsTrId("on-request-community");
                //% "Unknown community"
                default: return qsTrId("unknown-community");
                }
            }
            anchors.left: communityName.left
            anchors.top: communityName.bottom
            anchors.topMargin: 2
            font.pixelSize: 15
            font.weight: Font.Thin
            color: Style.current.secondaryText
        }

        StyledText {
            visible: popup.ensOnly
            text: qsTr(" - ENS Only")
            anchors.left: accessText.right
            anchors.verticalCenter: accessText.verticalCenter
            anchors.topMargin: 2
            font.pixelSize: 15
            font.weight: Font.Thin
            color: Style.current.secondaryText
        }
    }

    StyledText {
        id: descriptionText
        text: popup.description
        wrapMode: Text.Wrap
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
            text: nbMembers === 1 ? 
                  //% "1 member"
                  qsTrId("1-member") : 
                  //% "%1 members"
                  qsTrId("-1-members").arg(popup.nbMembers)
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

    StyledText {
        id: chatsTitle
        //% "Chats"
        text: qsTrId("chats")
        anchors.top: sep1.bottom
        anchors.topMargin: Style.current.bigPadding
        font.pixelSize: 15
        font.weight: Font.Thin
    }


    ListView {
        id: chatsList
        width: parent.width
        anchors.top: chatsTitle.bottom
        anchors.topMargin: 4
        anchors.bottom: parent.bottom
        clip: true
        model: community.chats
        boundsBehavior: Flickable.StopAtBounds
        delegate: Channel {
            id: channelItem
            anchors.left: parent.left
            anchors.right: parent.right
            unviewedMessagesCount: ""
            width: parent.width
            name: model.name
            lastMessage: model.description
            contentType: Constants.messageType
            color: Style.current.transparent
            enableMouseArea: false
        }
    }

    footer: Item {
        width: parent.width
        height: backButton.height

        StatusIconButton {
            id: backButton
            icon.name: "leave_chat"
            width: 44
            height: 44
            iconColor: Style.current.primary
            highlighted: true
            icon.color: Style.current.primary
            icon.width: 28
            icon.height: 28
            radius: width / 2
            onClicked: {
                openPopup(communitiesPopupComponent)
                popup.close()
            }
        }

        StatusButton {
            property bool isPendingRequest: {
                if (access !== Constants.communityChatOnRequestAccess) {
                    return false
                }
                return chatsModel.communities.isCommunityRequestPending(communityId)
            }
            text: {
                if (ensOnly && !profileModel.profile.ensVerified) {
                    return qsTr("Membership requires an ENS username")
                }
                if (canJoin) {
                    return qsTr("Join ‘%1’").arg(popup.name);
                }
                if (isPendingRequest) {
                     return qsTr("Pending")
                }
                switch(access) {
                case Constants.communityChatPublicAccess: return qsTr("Join ‘%1’").arg(popup.name);
                case Constants.communityChatInvitationOnlyAccess: return qsTr("You need to be invited");
                case Constants.communityChatOnRequestAccess: return qsTr("Request to join ‘%1’").arg(popup.name);
                default: return qsTr("Unknown community");
                }
            }
            enabled: {
                if (ensOnly && !profileModel.profile.ensVerified) {
                    return false
                }
                if (access === Constants.communityChatInvitationOnlyAccess || isPendingRequest) {
                    return false
                }
                if (canJoin) {
                    return true
                }
                return true
            }

            anchors.right: parent.right
            onClicked: {
                let error
                if (access === Constants.communityChatOnRequestAccess && !popup.isMember) {
                    error = chatsModel.communities.requestToJoinCommunity(popup.communityId,
                                                              profileModel.profile.ensVerified ? profileModel.profile.username : "")
                    if (!error) {
                        enabled = false
                        text = qsTr("Pending")
                    }
                } else {
                    error = chatsModel.communities.joinCommunity(popup.communityId, true)
                }

                if (error) {
                    joiningError.text = error
                    return joiningError.open()
                }

                popup.close()
            }
        }

        MessageDialog {
            id: joiningError
            //% "Error joining the community"
            title: qsTrId("error-joining-the-community")
            icon: StandardIcon.Critical
            standardButtons: StandardButton.Ok
        }
    }
}

