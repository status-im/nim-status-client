import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.13
import QtGraphicalEffects 1.13
import QtQuick.Controls.Universal 2.12
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"
import "../ContactsColumn"

ModalPopup {
    property string communityId: chatsModel.communities.activeCommunity.id
    property string name: chatsModel.communities.activeCommunity.name
    property string description: chatsModel.communities.activeCommunity.description
    property int access: chatsModel.communities.activeCommunity.access
    property string source: chatsModel.communities.activeCommunity.source
    property string communityColor: chatsModel.communities.activeCommunity.communityColor
    property int nbMembers: chatsModel.communities.activeCommunity.nbMembers
    property bool isAdmin: chatsModel.communities.activeCommunity.isAdmin
    height: stack.currentItem.height + modalHeader.height + modalFooter.height + Style.current.padding * 3
    id: popup

    onClosed: {
        while (stack.depth > 1) {
            stack.pop()
        }
    }

    header: Item {
        id: modalHeader
        height: childrenRect.height
        width: parent.width

        property string title: stack.currentItem.headerTitle
        property string description: stack.currentItem.headerDescription
        property string imageSource: stack.currentItem.headerImageSource
        property bool useLetterIdenticon: !!stack.currentItem.useLetterIdenticon

        Loader {
            id: communityImg
            sourceComponent: !modalHeader.useLetterIdenticon ? commmunityImgCmp : letterIdenticonCmp
            active: !!modalHeader.imageSource || modalHeader.useLetterIdenticon
        }

        Component {
            id: commmunityImgCmp
            RoundedImage {
                source: modalHeader.imageSource
                width: 40
                height: 40
                visible: !!modalHeader.imageSource
            }
        }

        Component {
            id: letterIdenticonCmp
            StatusLetterIdenticon {
                width: 40
                height: 40
                chatName: popup.name
                color: popup.communityColor || Style.current.blue
            }
        }

        StyledTextEdit {
            id: communityName
            text: modalHeader.title
            anchors.top: parent.top
            anchors.topMargin: 2
            anchors.left: communityImg.active ? communityImg.right : parent.left
            anchors.leftMargin: communityImg.active ? Style.current.smallPadding : 0
            font.bold: true
            font.pixelSize: 17
            readOnly: true
        }

        StyledText {
            id: headerDescription
            text: modalHeader.description
            anchors.left: communityName.left
            anchors.top: communityName.bottom
            anchors.topMargin: 2
            font.pixelSize: 15
            font.weight: Font.Thin
            color: Style.current.secondaryText
        }

        Separator {
            anchors.top: headerDescription.bottom
            anchors.topMargin: modalHeader.description === "" ? 0 : Style.current.padding
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: -Style.current.padding
            anchors.leftMargin: -Style.current.padding
        }
    }

    StackView {
        id: stack
        initialItem: profileOverview
        width: parent.width


        pushEnter: Transition { enabled: false }
        pushExit: Transition { enabled: false }
        popEnter: Transition { enabled: false }
        popExit: Transition { enabled: false }

        Component {
            id: inviteFriendsView
            CommunityProfilePopupInviteFriendsView {
                headerTitle: qsTr("Invite friends")
                contactListSearch.chatKey.text: ""
                contactListSearch.pubKey: ""
                contactListSearch.pubKeys: []
                contactListSearch.ensUsername: ""
                contactListSearch.existingContacts.visible: profileModel.contacts.list.hasAddedContacts()
                contactListSearch.noContactsRect.visible: !contactListSearch.existingContacts.visible
            }
        }

        Component {
            id: membersList
            CommunityProfilePopupMembersList {
                headerTitle: qsTr("Members")
                headerDescription: popup.nbMembers.toString()
                members: chatsModel.communities.activeCommunity.members
            }
        }

        Component {
            id: profileOverview
            CommunityProfilePopupOverview {
                property bool useLetterIdenticon: !!!popup.source
                headerTitle: chatsModel.communities.activeCommunity.name
                headerDescription: {
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
                headerImageSource: chatsModel.communities.activeCommunity.thumbnailImage
                description: chatsModel.communities.activeCommunity.description
            }
        }
    }

    footer: Item {
        id: modalFooter
        visible: stack.depth > 1
        width: parent.width
        height: modalFooter.visible ? btnBack.height : 0
        StatusRoundButton {
            id: btnBack
            anchors.left: parent.left
            icon.name: "arrow-right"
            icon.width: 20
            icon.height: 16
            rotation: 180
            type: globalSettings.theme === Universal.Dark ? "secondary" : "primary"
            onClicked: {
                stack.pop()
            }
        }

        StatusButton {
            text: qsTr("Invite")
            anchors.right: parent.right
            enabled: stack.currentItem.contactListSearch !== undefined && stack.currentItem.contactListSearch.pubKeys.length > 0
            onClicked: {
                stack.currentItem.sendInvites(stack.currentItem.contactListSearch.pubKeys)
                stack.pop()
            }
        }
    }
}

