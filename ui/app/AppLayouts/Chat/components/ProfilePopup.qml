import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtGraphicalEffects 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"
import "./"

ModalPopup {
    id: popup

    property Popup parentPopup

    property var identicon: ""
    property var userName: ""
    property string nickname: ""
    property var fromAuthor: ""
    property var text: ""
    property var alias: ""

    readonly property int innerMargin: 20
    
    property bool isEnsVerified: false
    property bool noFooter: false
    property bool isBlocked: false

    signal blockButtonClicked(name: string, address: string)
    signal unblockButtonClicked(name: string, address: string)
    signal removeButtonClicked(address: string)

    signal contactUnblocked(publicKey: string)
    signal contactBlocked(publicKey: string)
    signal contactAdded(publicKey: string)
    signal contactRemoved(publicKey: string)

    clip: true
    noTopMargin: true

    function openPopup(showFooter, userNameParam, fromAuthorParam, identiconParam, textParam, nicknameParam) {
        userName = userNameParam || ""
        nickname = nicknameParam || ""
        fromAuthor = fromAuthorParam || ""
        identicon = identiconParam || ""
        text = textParam || ""
        isEnsVerified = chatsModel.ensView.isEnsVerified(this.fromAuthor)
        isBlocked = profileModel.contacts.isContactBlocked(this.fromAuthor);
        alias = chatsModel.alias(this.fromAuthor) || ""
        
        noFooter = !showFooter;
        popup.open()
    }

    header: Item {
        height: 78
        width: parent.width

        RoundedImage {
            id: profilePic
            width: 40
            height: 40
            border.color: Style.current.border
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            source: identicon
        }

        StyledText {
            id: profileName
            text:  Utils.removeStatusEns(userName)
            elide: Text.ElideRight
            anchors.top: parent.top
            anchors.topMargin: Style.current.padding
            anchors.left: profilePic.right
            anchors.leftMargin: Style.current.halfPadding
            anchors.right: qrCodeButton.left
            anchors.rightMargin: Style.current.padding
            font.bold: true
            font.pixelSize: 17
        }

        StyledText {
            text: isEnsVerified ? alias : fromAuthor
            elide: !isEnsVerified ? Text.ElideMiddle : Text.ElideRight
            anchors.left: profilePic.right
            anchors.leftMargin: Style.current.smallPadding
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.current.padding
            anchors.right: qrCodeButton.left
            anchors.rightMargin: Style.current.padding
            anchors.topMargin: 2
            font.pixelSize: 14
            color: Style.current.secondaryText
        }

        StatusIconButton {
            id: qrCodeButton
            icon.name: "qr-code-icon"
            anchors.verticalCenter: profileName.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 52
            iconColor: Style.current.textColor
            onClicked: qrCodePopup.open()
            width: 32
            height: 32
        }

        Separator {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: -Style.current.padding
            anchors.right: parent.right
            anchors.rightMargin: -Style.current.padding
        }

        ModalPopup {
            id: qrCodePopup
            width: 320
            height: 320
            Image {
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                source: profileModel.qrCode(fromAuthor)
                anchors.horizontalCenter: parent.horizontalCenter
                height: 212
                width: 212
                mipmap: true
                smooth: false
            }
        }
    }

    Item {
        anchors.fill: parent

        TextWithLabel {
            id: ensText
            //% "ENS username"
            label: qsTrId("ens-username")
            text: userName
            anchors.top: parent.top
            visible: isEnsVerified
            height: visible ? implicitHeight : 0
            textToCopy: userName
        }

        StyledText {
            id: labelChatKey
            //% "Chat key"
            text: qsTrId("chat-key")
            font.pixelSize: 13
            font.weight: Font.Medium
            color: Style.current.secondaryText
            anchors.top: ensText.bottom
            anchors.topMargin: ensText.visible ? popup.innerMargin : 0
        }

        Address {
            id: valueChatKey
            text: fromAuthor
            width: 160
            maxWidth: parent.width - (3 * Style.current.smallPadding) - copyBtn.width
            color: Style.current.textColor
            font.pixelSize: 15
            anchors.top: labelChatKey.bottom
            anchors.topMargin: 4
        }

        CopyToClipBoardButton {
            id: copyBtn
            anchors.top: labelChatKey.bottom
            anchors.left: valueChatKey.right
            textToCopy: valueChatKey.text
        }

        Separator {
            id: separator
            anchors.top: valueChatKey.bottom
            anchors.topMargin: popup.innerMargin
            anchors.left: parent.left
            anchors.leftMargin: -Style.current.padding
            anchors.right: parent.right
            anchors.rightMargin: -Style.current.padding
        }

        TextWithLabel {
            id: valueShareURL
            //% "Share Profile URL"
            label: qsTrId("share-profile-url")
            text: Constants.userLinkPrefix + fromAuthor.substr(0, 4) + "..." + fromAuthor.substr(fromAuthor.length - 5)
            anchors.top: separator.top
            anchors.topMargin: popup.innerMargin
            textToCopy: Constants.userLinkPrefix + fromAuthor
        }

        Separator {
            id: separator2
            anchors.top: valueShareURL.bottom
            anchors.topMargin: popup.innerMargin
            anchors.left: parent.left
            anchors.leftMargin: -Style.current.padding
            anchors.right: parent.right
            anchors.rightMargin: -Style.current.padding
        }

        TextWithLabel {
            id: chatSettings
            visible: profileModel.profile.pubKey !== fromAuthor
            //% "Chat settings"
            label: qsTrId("chat-settings")
            //% "Nickname"
            text: qsTrId("nickname")
            anchors.top: separator2.top
            anchors.topMargin: popup.innerMargin
        }

        SVGImage {
            id: nicknameCaret
            visible: profileModel.profile.pubKey !== fromAuthor
            source: "../../../img/caret.svg"
            rotation: -90
            anchors.right: parent.right
            anchors.rightMargin: Style.current.padding
            anchors.bottom: chatSettings.bottom
            anchors.bottomMargin: 5
            width: 13
            height: 7
            fillMode: Image.PreserveAspectFit
            ColorOverlay {
                anchors.fill: parent
                source: parent
                color: Style.current.secondaryText
            }
        }

        StyledText {
            id: nicknameText
            visible: profileModel.profile.pubKey !== fromAuthor
            //% "None"
            text: nickname ? nickname : qsTrId("none")
            anchors.right: nicknameCaret.left
            anchors.rightMargin: Style.current.padding
            anchors.verticalCenter: nicknameCaret.verticalCenter
            color: Style.current.secondaryText
        }

        MouseArea {
            cursorShape: Qt.PointingHandCursor
            anchors.left: chatSettings.left
            anchors.right: nicknameCaret.right
            anchors.top: chatSettings.top
            anchors.bottom: chatSettings.bottom
            onClicked: {
                nicknamePopup.open()
            }
        }

        NicknamePopup {
            id: nicknamePopup
            changeUsername: function (newUsername) {
                popup.userName = newUsername
            }
            changeNickname: function (newNickname) {
                popup.nickname = newNickname
            }
        }
    }

    footer: Item {
        id: footerContainer
        visible: !noFooter
        width: parent.width
        height: children[0].height

        StatusButton {
            id: blockBtn
            anchors.right: addToContactsButton.left
            anchors.rightMargin: addToContactsButton ? Style.current.padding : 0
            anchors.bottom: parent.bottom
            type: "warn"
            showBorder: true
            bgColor: "transparent"
            borderColor: Style.current.border
            hoveredBorderColor: Style.current.transparent
            text: isBlocked ?
                      //% "Unblock User"
                      qsTrId("unblock-user") :
                      //% "Block User"
                      qsTrId("block-user")
            onClicked: {
                if (isBlocked) {
                    unblockContactConfirmationDialog.contactName = userName;
                    unblockContactConfirmationDialog.contactAddress = fromAuthor;
                    unblockContactConfirmationDialog.open();
                    return;
                }
                blockContactConfirmationDialog.contactName = userName;
                blockContactConfirmationDialog.contactAddress = fromAuthor;
                blockContactConfirmationDialog.open();
            }
        }

        StatusButton {
            property bool isAdded:  profileModel.contacts.isAdded(fromAuthor)

            id: addToContactsButton
            anchors.right: sendMessageBtn.left
            anchors.rightMargin: sendMessageBtn.visible ? Style.current.padding : 0
            text: isAdded ?
                      //% "Remove Contact"
                      qsTrId("remove-contact") :
                      //% "Add to contacts"
                      qsTrId("add-to-contacts")
            anchors.bottom: parent.bottom
            type: isAdded ? "warn" : "primary"
            showBorder: isAdded
            borderColor: Style.current.border
            bgColor: isAdded ? "transparent" : Style.current.buttonBackgroundColor
            hoveredBorderColor: Style.current.transparent
            visible: !isBlocked
            width: visible ? implicitWidth : 0
            onClicked: {
                if (profileModel.contacts.isAdded(fromAuthor)) {
                    removeContactConfirmationDialog.parentPopup = profilePopup;
                    removeContactConfirmationDialog.open();
                } else {
                    profileModel.contacts.addContact(fromAuthor);
                    contactAdded(fromAuthor);
                    profilePopup.close();
                }
            }
        }

        StatusButton {
            id: sendMessageBtn
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            //% "Send message"
            text: qsTrId("send-message")
            visible: !isBlocked && chatsModel.activeChannel.id !== popup.fromAuthor
            width: visible ? implicitWidth : 0
            onClicked: {
                appMain.changeAppSection(Constants.chat)
                chatsModel.joinPrivateChat(fromAuthor, "");
                popup.close()
            }
        }

        BlockContactConfirmationDialog {
            id: blockContactConfirmationDialog
            onBlockButtonClicked: {
                profileModel.contacts.blockContact(fromAuthor)
                blockContactConfirmationDialog.close();
                popup.close()

                contactBlocked(fromAuthor)
            }
        }

        UnblockContactConfirmationDialog {
            id: unblockContactConfirmationDialog
            onUnblockButtonClicked: {
                profileModel.contacts.unblockContact(fromAuthor)
                unblockContactConfirmationDialog.close();
                popup.close()
                contactUnblocked(fromAuthor)
            }
        }

        ConfirmationDialog {
            id: removeContactConfirmationDialog
            // % "Remove contact"
            title: qsTrId("remove-contact")
            //% "Are you sure you want to remove this contact?"
            confirmationText: qsTrId("are-you-sure-you-want-to-remove-this-contact-")
            onConfirmButtonClicked: {
                if (profileModel.contacts.isAdded(fromAuthor)) {
                    profileModel.contacts.removeContact(fromAuthor);
                }
                removeContactConfirmationDialog.close();
                popup.close();

                contactRemoved(fromAuthor);
            }
        }
    }
}
