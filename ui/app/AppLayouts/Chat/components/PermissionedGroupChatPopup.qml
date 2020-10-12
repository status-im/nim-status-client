import QtQuick 2.12
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3
import QtQml.Models 2.3
import "../../../../imports"
import "../../../../shared"
import "./"

ModalPopup {
    id: popup

    property var pubKeys: []
    property bool selectChatMembers: true
    property int memberCount: 1
    readonly property int maxMembers: 10

    onOpened: {
        groupName.text = "";
        searchBox.text = "";
        selectChatMembers = true;
        memberCount = 1;
        pubKeys = [];
        btnSelectMembers.state = "inactive";
        for(var i in groupMembers.contentItem.children){
            if (groupMembers.contentItem.children[i].isChecked !== null) {
                groupMembers.contentItem.children[i].isChecked = false
            }
        }

        data.clear();
        const nbContacts = profileModel.contactList.rowCount()
        for(let i = 0; i < nbContacts; i++){
            data.append({
                            name: profileModel.contactList.rowData(i, "name"),
                            localNickname: profileModel.contactList.rowData(i, "localNickname"),
                            pubKey: profileModel.contactList.rowData(i, "pubKey"),
                            address: profileModel.contactList.rowData(i, "address"),
                            identicon: profileModel.contactList.rowData(i, "identicon"),
                            isUser: false,
                            isContact: profileModel.contactList.rowData(i, "isContact") !== "false"
                        });
        }
        data.append({
                        //% "(You)"
                        name: profileModel.profile.username + " " + qsTrId("(you)"),
                        pubKey: profileModel.profile.pubKey,
                        address: "",
                        identicon: profileModel.profile.identicon,
                        isUser: true
                    });
        noContactsRect.visible = !profileModel.contactList.hasAddedContacts();
        svMembers.visible = !noContactsRect.visible;
        if(!svMembers.visible){
            memberCount = 0;
        }
    }

    function doJoin(){
        if(pubKeys.length === 0) return;
        chatsModel.createGroup(groupName.text, JSON.stringify(pubKeys));
        popup.close();
    }

    header: Item {
        height: 30
        width: parent.width

        StyledText {
            id: lblNewGroup
            text: qsTr("New permissioned group chat")
            anchors.left: parent.left
            font.bold: true
            font.pixelSize: 17
            anchors.top: parent.top
        }

        StyledText {
            anchors.top: lblNewGroup.bottom
            //% "%1 / 10 members"
            text: qsTrId("%1-/-10-members").arg(memberCount)
            color: Style.current.darkGrey
            font.pixelSize: 15
        }
    }

    StyledText {
        id: chatInfo
        visible: selectChatMembers
        text: qsTr("A Permissioned group chat is a channel that everyone can look at, but only the allowed members can write. It's perfect to reduce the risk of spam and create communities")
        color: Style.current.darkGrey
        font.pixelSize: 15
        width: parent.width
        wrapMode: Text.WordWrap
    }

    SearchBox {
        id: searchBox
        visible: selectChatMembers
        iconWidth: 17
        iconHeight: 17
        customHeight: 44
        fontPixelSize: 15
        anchors.top: chatInfo.bottom
        anchors.topMargin: Style.current.smallPadding
    }

    Input {
        id: groupName
        //% "Group name"
        placeholderText: qsTrId("group-name")
        visible: !selectChatMembers
    }

    Rectangle {
        id: noContactsRect
        width: 260
        anchors.top: searchBox.bottom
        anchors.topMargin: Style.current.xlPadding
        anchors.horizontalCenter: parent.horizontalCenter
        StyledText {
            id: noContacts
            //% "You don’t have any contacts yet. Invite your friends to start chatting."
            text: qsTrId("you-don-t-have-any-contacts-yet--invite-your-friends-to-start-chatting-")
            color: Style.current.darkGrey
            anchors.top: parent.top
            anchors.topMargin: Style.current.padding
            anchors.left: parent.left
            anchors.right: parent.right
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        StyledButton {
            //% "Invite friends"
            label: qsTrId("invite-friends")
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: noContacts.bottom
            anchors.topMargin: Style.current.xlPadding
            onClicked: {
                inviteFriendsPopup.open()
            }
        }
        InviteFriendsPopup {
            id: inviteFriendsPopup
        }
    }

    ScrollView {
        anchors.topMargin: Style.current.smallPadding
        anchors.top: searchBox.visible ? searchBox.bottom : groupName.bottom
        anchors.bottom: parent.bottom
        width: parent.width

        id: svMembers
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: groupMembers.contentHeight > groupMembers.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

        ListView {
            anchors.fill: parent
            model: ListModel {
                id: data
            }
            spacing: 0
            clip: true
            id: groupMembers
            delegate: Contact {
                isVisible: {
                    if(selectChatMembers){
                        return searchBox.text == "" || model.name.includes(searchBox.text)
                    } else {
                        return isChecked || isUser
                    }
                }
                showCheckbox: selectChatMembers && memberCount < maxMembers
                pubKey: model.pubKey
                isContact: !!model.isContact
                isUser: model.isUser
                name: !model.name.endsWith(".eth") && !!model.localNickname ?
                          model.localNickname : Utils.removeStatusEns(model.name)
                address: model.address
                identicon: model.identicon
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
                    memberCount = pubKeys.length + 1;
                    btnSelectMembers.state = pubKeys.length > 0 ? "active" : "inactive"
                }
            }
        }
    }
    
    footer: Item {
        anchors.top: parent.bottom
        anchors.right: parent.right
        anchors.bottom: popup.bottom
        anchors.left: parent.left

        Button {
            id: btnSelectMembers
            visible: selectChatMembers
            width: 44
            height: 44
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            state: "inactive"
            states: [
                State {
                    name: "inactive"
                    PropertyChanges {
                        target: btnSelectMembersImg
                        source: "../../../img/arrow-right-btn-inactive.svg"
                    }
                },
                State {
                    name: "active"
                    PropertyChanges {
                        target: btnSelectMembersImg
                        source: "../../../img/arrow-right-btn-active.svg"
                    }
                }
            ]
            SVGImage {
                id: btnSelectMembersImg
                width: 50
                height: 50
            }
            background: Rectangle {
                color: "transparent"
            }
            MouseArea {
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                onClicked : {
                    if(pubKeys.length > 0)
                        selectChatMembers = false
                    searchBox.text = ""
                    groupName.forceActiveFocus(Qt.MouseFocusReason)
                }
            }
        }

        Button {
            id: btnBack
            visible: !selectChatMembers
            width: 44
            height: 44
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            SVGImage {
                source: "../../../img/arrow-left-btn-active.svg"
                width: 50
                height: 50
            }
            background: Rectangle {
                color: "transparent"
            }
            MouseArea {
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                onClicked : {
                    selectChatMembers = true
                }
            }
        }

        StyledButton {
            visible: !selectChatMembers
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            label: qsTr("Create Permissioned Group Chat")
            disabled: groupName.text === ""
            onClicked : doJoin()
        }
    }
}

