import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Dialogs 1.2
import QtGraphicalEffects 1.13
import QtQuick.Layouts 1.13

import StatusQ.Components 0.1
import StatusQ.Popups 0.1

import "../../../imports"
import "../../../shared"
import "../../../shared/status"
import "./components"
import "./CommunityComponents"


Item {
    // TODO unhardcode
    property int chatGroupsListViewCount: communityChatListAndCategories.chatList.count
    property Component pinnedMessagesPopupComponent

    id: root

    Layout.fillHeight: true
    width: 304

    StatusChatInfoToolBar {
        id: communityHeader
        anchors.top: parent.top
        anchors.topMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter

        chatInfoButton.title: chatsModel.communities.activeCommunity.name
        chatInfoButton.subTitle: chatsModel.communities.activeCommunity.nbMembers === 1 ? 
            qsTr("1 Member") : 
            qsTr("%1 Members").arg(chatsModel.communities.activeCommunity.nbMembers)
        chatInfoButton.image.source: chatsModel.communities.activeCommunity.thumbnailImage
        chatInfoButton.icon.color: chatsModel.communities.activeCommunity.communityColor
        chatInfoButton.onClicked: communityProfilePopup.open()

        popupMenu: StatusPopupMenu {

            StatusMenuItem {
                text: qsTr("Create channel")
                icon.name: "channel"
                enabled: chatsModel.communities.activeCommunity.admin
                onTriggered: openPopup(createChannelPopup, {communityId: chatsModel.communities.activeCommunity.id})
            }

            StatusMenuItem {
                text: qsTr("Create category")
                icon.name: "channel-category"
                enabled: chatsModel.communities.activeCommunity.admin
                onTriggered: openPopup(createCategoryPopup, {communityId: chatsModel.communities.activeCommunity.id})
            }

            StatusMenuSeparator {}

            StatusMenuItem {
                text: qsTr("Invite people")
                icon.name: "share-ios"
                enabled: chatsModel.communities.activeCommunity.canManageUsers
                onTriggered: openPopup(inviteFriendsToCommunityPopup, {communityId: chatsModel.communities.activeCommunity.id})
            }
        }
    }

    Loader {
        id: membershipRequests

        property int nbRequests: chatsModel.communities.activeCommunity.communityMembershipRequests.nbRequests

        anchors.top: communityHeader.bottom
        anchors.topMargin: active ? 8 : 0
        anchors.horizontalCenter: parent.horizontalCenter

        active: chatsModel.communities.activeCommunity.admin && nbRequests > 0
        sourceComponent: Component {
            StatusContactRequestsIndicatorListItem {
                title: qsTr("Membership requests")
                requestsCount: membershipRequests.nbRequests
                sensor.onClicked: membershipRequestPopup.open()
            }
        }
    }

    ScrollView {
        id: chatGroupsContainer
        anchors.top: membershipRequests.bottom
        anchors.topMargin: Style.current.padding
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        width: parent.width

        leftPadding: Style.current.halfPadding
        rightPadding: Style.current.halfPadding

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true
        contentHeight: communityChatListAndCategories.height
                       + emptyViewAndSuggestionsLoader.height
                       + backUpBannerLoader.height 
                       + 16

        StatusChatListAndCategories {
            id: communityChatListAndCategories

            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width
            height: {
                if (!emptyViewAndSuggestionsLoader.active &&
                    !backUpBannerLoader.active) {
                    return implicitHeight > (root.height - 82) ? implicitHeight + 8 : root.height - 82
                }
                return implicitHeight
            }
              
            chatList.model: chatsModel.communities.activeCommunity.chats
            categoryList.model: chatsModel.communities.activeCommunity.categories

            showCategoryActionButtons: chatsModel.communities.activeCommunity.admin
            selectedChatId: chatsModel.channelView.activeChannel.id

            onChatItemSelected: chatsModel.channelView.setActiveChannel(id)
            onChatItemUnmuted: chatsModel.channelView.unmuteChatItem(id)
            onCategoryAddButtonClicked: openPopup(createChannelPopup, {
                communityId: chatsModel.communities.activeCommunity.id,
                categoryId: id
            })

            popupMenu: StatusPopupMenu {

                StatusMenuItem {
                    text: qsTr("Create channel")
                    icon.name: "channel"
                    enabled: chatsModel.communities.activeCommunity.admin
                    onTriggered: openPopup(createChannelPopup, {communityId: chatsModel.communities.activeCommunity.id})
                }

                StatusMenuItem {
                    text: qsTr("Create category")
                    icon.name: "channel-category"
                    enabled: chatsModel.communities.activeCommunity.admin
                    onTriggered: openPopup(createCategoryPopup, {communityId: chatsModel.communities.activeCommunity.id})
                }

                StatusMenuSeparator {}

                StatusMenuItem {
                    text: qsTr("Invite people")
                    icon.name: "share-ios"
                    enabled: chatsModel.communities.activeCommunity.canManageUsers
                    onTriggered: openPopup(inviteFriendsToCommunityPopup, {communityId: chatsModel.communities.activeCommunity.id})
                }
            }

            categoryPopupMenu: StatusPopupMenu {

                property var categoryItem

                openHandler: function (id) {
                    categoryItem = chatsModel.communities.activeCommunity.getCommunityCategoryItemById(id)
                }

                StatusMenuItem { 
                    enabled: chatsModel.communities.activeCommunity.admin
                    text: qsTr("Edit Category")
                    icon.name: "edit"
                    onTriggered: {
                        openPopup(createCategoryPopup, {
                            communityId: chatsModel.communities.activeCommunity.id,
                            isEdit: true,
                            categoryId: categoryItem.id,
                            categoryName: categoryItem.name
                        })
                    }
                }

                StatusMenuSeparator {
                    visible: chatsModel.communities.activeCommunity.admin
                }

                StatusMenuItem {
                    enabled: chatsModel.communities.activeCommunity.admin
                    text: qsTr("Delete Category")
                    icon.name: "delete"
                    type: StatusMenuItem.Type.Danger
                    onTriggered: {
                        openPopup(deleteCategoryConfirmationDialogComponent, {
                            title: qsTr("Delete %1 category").arg(categoryItem.name),
                            confirmationText: qsTr("Are you sure you want to delete %1 category? Channels inside the category won’t be deleted.")
                                .arg(categoryItem.name),
                            categoryId: categoryItem.id
                        })
                    }
                }
            }

            chatListPopupMenu: ChatContextMenu {
                openHandler: function (id) {
                    chatItem = chatsModel.channelView.getChatItemById(id)
                }
            }
        }

        Loader {
            id: emptyViewAndSuggestionsLoader
            active: chatsModel.communities.activeCommunity.admin && !appSettings.hiddenCommunityWelcomeBanners.includes(chatsModel.communities.activeCommunity.id)
            width: parent.width
            height: active ? item.height : 0
            anchors.top: communityChatListAndCategories.bottom
            anchors.topMargin: active ? Style.current.padding : 0
            sourceComponent: Component {
                CommunityWelcomeBanner {}
            }
        }

        Loader {
            id: backUpBannerLoader
            active: chatsModel.communities.activeCommunity.admin && !appSettings.hiddenCommunityBackUpBanners.includes(chatsModel.communities.activeCommunity.id)
            width: parent.width
            height: active ? item.height : 0
            anchors.top: emptyViewAndSuggestionsLoader.bottom
            anchors.topMargin: active ? Style.current.padding : 0
            sourceComponent: Component {
                Item {
                    width: parent.width
                    height: backupBanner.height

                    BackUpCommuntyBanner {
                        id: backupBanner
                    }
                    MouseArea {
                        anchors.fill: backupBanner
                        acceptedButtons: Qt.RightButton
                        onClicked: {
                            /* Prevents sending events to the component beneath
                               if Right Mouse Button is clicked. */
                            mouse.accepted = false;
                        }
                    }
                }
            }
        }
    }

    Component {
        id: createChannelPopup
        CreateChannelPopup {
            anchors.centerIn: parent
            pinnedMessagesPopupComponent: root.pinnedMessagesPopupComponent
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: createCategoryPopup
        CreateCategoryPopup {
            anchors.centerIn: parent
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: transferOwnershipPopup
        TransferOwnershipPopup {}
    }

    CommunityProfilePopup {
        id: communityProfilePopup
        communityId: chatsModel.communities.activeCommunity.id
        name: chatsModel.communities.activeCommunity.name
        description: chatsModel.communities.activeCommunity.description
        access: chatsModel.communities.activeCommunity.access
        nbMembers: chatsModel.communities.activeCommunity.nbMembers
        isAdmin: chatsModel.communities.activeCommunity.admin
        source: chatsModel.communities.activeCommunity.thumbnailImage
        communityColor: chatsModel.communities.activeCommunity.communityColor
    }

    Component {
        id: deleteCategoryConfirmationDialogComponent
        ConfirmationDialog {
            property string categoryId
            btnType: "warn"
            height: 216
            showCancelButton: true
            onClosed: {
                destroy()
            }
            onCancelButtonClicked: {
                close();
            }
            onConfirmButtonClicked: function(){
                const error = chatsModel.communities.deleteCommunityCategory(chatsModel.communities.activeCommunity.id, categoryId)
                if (error) {
                    creatingError.text = error
                    return creatingError.open()
                }
                close();
            }
        }
    }

    MessageDialog {
        id: deleteError
        title: qsTr("Error deleting the category")
        icon: StandardIcon.Critical
        standardButtons: StandardButton.Ok
    }

    MembershipRequestsPopup {
        id: membershipRequestPopup
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;formeditorColor:"#ffffff";height:480;width:640}
}
##^##*/
