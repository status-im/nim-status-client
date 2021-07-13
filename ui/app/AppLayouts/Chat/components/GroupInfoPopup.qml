import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"
import "./"

ModalPopup {
    id: popup
    enum ChannelType {
        ActiveChannel,
        ContextChannel
    }
    property bool addMembers: false
    property int currMemberCount: 1
    property int memberCount: 1
    readonly property int maxMembers: 10
    property var pubKeys: []
    property int channelType: GroupInfoPopup.ChannelType.ActiveChannel
    property QtObject channel: {
        if (channelType === GroupInfoPopup.ChannelType.ActiveChannel) {
            return chatsModel.channelView.activeChannel
         } else if (channelType === GroupInfoPopup.ChannelType.ContextChannel) {
            return chatsModel.channelView.contextChannel
         }
    }
    property bool isAdmin: false
    property Component pinnedMessagesPopupComponent

    function resetSelectedMembers(){
        pubKeys = [];
        memberCount = channel.members.rowCount();
        currMemberCount = memberCount;
        contactList.membersData.clear();

        const contacts = getContactListObject()

        contacts.forEach(function (contact) {
            if(popup.channel.contains(contact.pubKey) ||
                    !contact.isContact) {
                return;
            }
            contactList.membersData.append(contact)
        })
    }

    onClosed: {
        popup.destroy();
    }

    onOpened: {
        addMembers = false;
        popup.isAdmin = popup.channel.isAdmin(profileModel.profile.pubKey)
        btnSelectMembers.enabled = false;
        resetSelectedMembers();
    }

    function doAddMembers(){
        if(pubKeys.length === 0) return;
        chatsModel.groups.addMembers(popup.channel.id, JSON.stringify(pubKeys));
        popup.close();
    }

    header: Item {
      height: children[0].height
      width: parent.width


      StatusLetterIdenticon {
          id: letterIdenticon
          width: 36
          height: 36
          anchors.top: parent.top
          color: popup.channel.color
          chatId: popup.channel.id
          chatName: popup.channel.name
      }
    
      StyledTextEdit {
          id: groupName
          //% "Add members"
          text: addMembers ? qsTrId("add-members") : popup.channel.name
          anchors.top: parent.top
          anchors.topMargin: 2
          anchors.left: letterIdenticon.right
          anchors.leftMargin: Style.current.smallPadding
          font.bold: true
          font.pixelSize: 14
          readOnly: true
          wrapMode: Text.WordWrap
      }

      StyledText {
          text: {
            let cnt = memberCount;
            if(addMembers){
                //% "%1 / 10 members"
                return qsTrId("%1-/-10-members").arg(cnt)
            } else {
                //% "%1 members"
                if(cnt > 1) return qsTrId("%1-members").arg(cnt);
                //% "1 member"
                return qsTrId("1-member");
            }
          }
          width: 160
          anchors.left: letterIdenticon.right
          anchors.leftMargin: Style.current.smallPadding
          anchors.top: groupName.bottom
          anchors.topMargin: 2
          font.pixelSize: 14
          color: Style.current.secondaryText
      }

      Rectangle {
            id: editGroupNameBtn
            visible: !addMembers && popup.isAdmin
            height: 24
            width: 24
            anchors.verticalCenter: groupName.verticalCenter
            anchors.leftMargin: Style.current.halfPadding
            anchors.left: groupName.right
            radius: 8

            SVGImage {
                id: editGroupImg
                source: "../../../img/edit-group.svg"
                height: 16
                width: 16
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
                id: closeModalMouseArea
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                hoverEnabled: true
                onExited: {
                    editGroupNameBtn.color = Style.current.white
                }
                onEntered: {
                    editGroupNameBtn.color = Style.current.grey
                }
                onClicked: renameGroupPopup.open()
            }
        }

        RenameGroupPopup {
            id: renameGroupPopup
        }
    }

    Item {
        id: addMembersItem
        anchors.fill: parent

        SearchBox {
            id: searchBox
            visible: addMembers
            iconWidth: 17
            iconHeight: 17
            customHeight: 44
            fontPixelSize: 15
        }

        NoFriendsRectangle {
            visible: contactList.membersData.count === 0 && memberCount === 0
            anchors.top: searchBox.bottom
            anchors.topMargin: Style.current.xlPadding
            anchors.horizontalCenter: parent.horizontalCenter
        }

        NoFriendsRectangle {
            visible: contactList.membersData.count === 0 && memberCount > 0
            width: 340
            text: qsTr("All your contacts are already in the group")
            textColor: Style.current.textColor
            anchors.top: searchBox.bottom
            anchors.topMargin: Style.current.xlPadding
            anchors.horizontalCenter: parent.horizontalCenter
        }

        ContactList {
            id: contactList
            visible: addMembers && contactList.membersData.count > 0
            anchors.fill: parent
            anchors.topMargin: 50
            anchors.top: searchBox.bottom
            selectMode: memberCount < maxMembers
            searchString: searchBox.text.toLowerCase()
            onItemChecked: function(pubKey, itemChecked){
                var idx = pubKeys.indexOf(pubKey)
                if(itemChecked){
                    if(idx === -1){
                        pubKeys.push(pubKey)
                    }
                } else {
                    if(idx > -1){
                        pubKeys.splice(idx, 1);
                    }
                }
                memberCount = popup.channel.members.rowCount() + pubKeys.length;
                btnSelectMembers.enabled = pubKeys.length > 0
            }
        }
    }

    Item {
        id: groupInfoItem
        anchors.fill: parent

        Separator {
            id: separator
            visible: !addMembers
            anchors.left: parent.left
            anchors.leftMargin: -Style.current.padding
            anchors.right: parent.right
            anchors.rightMargin: -Style.current.padding
        }

        StatusSettingsLineButton {
            property int pinnedCount: chatsModel.messageView.pinnedMessagesList.count

            id: pinnedMessagesBtn
            visible: pinnedCount > 0
            height: visible ? implicitHeight : 0
            text: qsTr("Pinned messages")
            currentValue: pinnedCount
            anchors.top: separator.bottom
            anchors.topMargin: visible ? Style.current.halfPadding : 0
            anchors.leftMargin: 0
            anchors.rightMargin: 0
            onClicked: openPopup(pinnedMessagesPopupComponent)
            iconSource: "../../../img/pin.svg"
        }

        Separator {
            id: separator2
            visible: pinnedMessagesBtn.visible
            anchors.left: parent.left
            anchors.leftMargin: -Style.current.padding
            anchors.right: parent.right
            anchors.rightMargin: -Style.current.padding
            anchors.top: pinnedMessagesBtn.bottom
            anchors.topMargin: visible ? Style.current.halfPadding : 0
        }

        Connections {
            target: chatsModel.channelView
            onActiveChannelChanged: {
                if (popup.channelType === GroupInfoPopup.ChannelType.ActiveChannel) {
                    popup.channel = chatsModel.channelView.activeChannel
                    resetSelectedMembers()
                }
            }
            onContextChannelChanged: {
                if (popup.channelType === GroupInfoPopup.ChannelType.ContextChannel) {
                    popup.channel = chatsModel.channelView.contextChannel
                    resetSelectedMembers()
                }
            }
        }

        ListView {
            id: memberList
            anchors.top: separator2.bottom
            anchors.bottom: parent.bottom
            anchors.topMargin: addMembers ? 30 : Style.current.padding
            anchors.bottomMargin: Style.current.padding
            anchors.left: parent.left
            anchors.leftMargin: Style.current.padding
            anchors.right: parent.right
            anchors.rightMargin: Style.current.padding
            spacing: Style.current.padding
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: popup.channel.members
            delegate: Item {
                id: contactRow
                width: parent.width
                height: identicon.height

                property string nickname: appMain.getUserNickname(model.pubKey)

                StatusImageIdenticon {
                    id: identicon
                    anchors.left: parent.left
                    source: appMain.getProfileImage(model.pubKey)|| model.identicon
                }

                StyledText {
                    text: !model.userName.endsWith(".eth") && !!contactRow.nickname ?
                              contactRow.nickname : Utils.removeStatusEns(model.userName)
                    anchors.left: identicon.right
                    anchors.leftMargin: Style.current.padding
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 17

                    StyledText {
                        visible: model.pubKey === profileModel.profile.pubKey
                        anchors.left: parent.right
                        anchors.leftMargin: 5
                        //% "(You)"
                        text: qsTrId("-you-")
                        color: Style.current.secondaryText
                        font.pixelSize: parent.font.pixelSize
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const userProfileImage = appMain.getProfileImage(model.pubKey)
                            openProfilePopup(model.userName, model.pubKey, userProfileImage || model.identicon, '', contactRow.nickname, popup)
                        }
                    }
                }

                StyledText {
                    id: adminLabel
                    visible: model.isAdmin
                    //% "Admin"
                    text: qsTrId("group-chat-admin")
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 13
                    color: Style.current.secondaryText
                }

                StyledText {
                    id: moreActionsBtn
                    visible: !model.isAdmin && popup.isAdmin
                    text: "..."
                    anchors.right: parent.right
                    anchors.rightMargin: Style.current.smallPadding
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 20
                    font.bold: true
                    color: Style.current.secondaryText
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            contextMenu.popup(-contextMenu.width / 2 + moreActionsBtn.width / 2, moreActionsBtn.height + 10)
                        }
                        cursorShape: Qt.PointingHandCursor
                        PopupMenu {
                            id: contextMenu
                            Action {
                                icon.source: "../../../img/make-admin.svg"
                                icon.width: 16
                                icon.height: 16
                                //% "Make Admin"
                                text: qsTrId("make-admin")
                                onTriggered: chatsModel.groups.makeAdmin(popup.channel.id,  model.pubKey)
                            }
                            Action {
                                icon.source: "../../../img/remove-from-group.svg"
                                icon.width: 16
                                icon.height: 16
                                icon.color: Style.current.red
                                //% "Remove From Group"
                                text: qsTrId("remove-from-group")
                                onTriggered: chatsModel.groups.kickMember(popup.channel.id,  model.pubKey)
                            }
                        }
                    }
                }
            }
        }
    }

    footer: Item {
        visible: popup.isAdmin
        width: parent.width
        height: children[0].height
        StatusButton {
          visible: !addMembers
          anchors.right: parent.right
          //% "Add members"
          text: qsTrId("add-members")
          anchors.bottom: parent.bottom
          onClicked: {
            addMembers = true;
          }
        }

        StatusRoundButton {
            id: btnBack
            visible: addMembers
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            icon.name: "arrow-right"
            icon.width: 20
            icon.height: 16
            rotation: 180
            onClicked : {
                addMembers = false;
                resetSelectedMembers();
            }
        }

        StatusButton {
          id: btnSelectMembers
          visible: addMembers
          enabled: memberCount >= currMemberCount
          anchors.right: parent.right
          //% "Add selected"
          text: qsTrId("add-selected")
          anchors.bottom: parent.bottom
          onClicked: doAddMembers()
        }
    }

    content: addMembers ? addMembersItem : groupInfoItem
}
