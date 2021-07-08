import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status/core"
import "../../../../shared/status"
import "./Contacts"

Item {
    id: contactsContainer
    property alias searchStr: searchBox.text
    property bool isPending: false
    height: parent.height
    Layout.fillWidth: true
    clip: true

    Item {
        anchors.top: parent.top
        anchors.topMargin: 32
        anchors.bottom: parent.bottom
        width: profileContainer.profileContentWidth

        anchors.horizontalCenter: parent.horizontalCenter

        SearchBox {
            id: searchBox
            anchors.top: parent.top
            fontPixelSize: 15
        }

        Item {
            id: addNewContact
            anchors.top: searchBox.bottom
            anchors.topMargin: Style.current.bigPadding
            width: addButton.width + usernameText.width + Style.current.padding
            height: addButton.height


            StatusRoundButton {
                id: addButton
                icon.name: "plusSign"
                size: "medium"
                type: "secondary"
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                id: usernameText
                //% "Add new contact"
                text: qsTrId("add-new-contact")
                color: Style.current.blue
                anchors.left: addButton.right
                anchors.leftMargin: Style.current.padding
                anchors.verticalCenter: addButton.verticalCenter
                font.pixelSize: 15
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    addContactModal.open()
                }
            }
        }

        Item {
            id: blockedContactsButton
            anchors.top: addNewContact.bottom
            anchors.topMargin: Style.current.bigPadding
            width: blockButton.width + blockButtonLabel.width + Style.current.padding
            visible: profileModel.contacts.blockedContacts.rowCount() > 0
            height: addButton.height

            StatusRoundButton {
                id: blockButton
                anchors.verticalCenter: parent.verticalCenter
                icon.name: "block-icon"
                icon.color: Style.current.lightBlue
                width: 40
                height: 40
            }

            StyledText {
                id: blockButtonLabel
                //% "Blocked contacts"
                text: qsTrId("blocked-contacts")
                color: Style.current.blue
                anchors.left: blockButton.right
                anchors.leftMargin: Style.current.padding
                anchors.verticalCenter: blockButton.verticalCenter
                font.pixelSize: 15
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    blockedContactsModal.open()
                }
            }
        }

        ModalPopup {
            id: blockedContactsModal
            //% "Blocked contacts"
            title: qsTrId("blocked-contacts")

            ContactList {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                contacts: profileModel.contacts.blockedContacts
            }
        }

        Component {
            id: loadingIndicator
            StatusLoadingIndicator {
                width: 12
                height: 12
            }
        }

        ModalPopup {
            id: addContactModal
            //% "Add contact"
            title: qsTrId("add-contact")
            property string validationError: ""

            function validate(value) {
                if (!Utils.isChatKey(value) && !Utils.isValidETHNamePrefix(value)) {
                    //% "Enter a valid chat key or ENS username"
                    addContactModal.validationError = qsTr("Enter a valid chat key or ENS username");
                } else if (profileModel.profile.pubKey === value) {
                    addContactModal.validationError = qsTr("You can't add yourself");
                } else {
                    addContactModal.validationError = ""
                }
                return addContactModal.validationError === ""
            }

            property var lookupContact: Backpressure.debounce(addContactSearchInput, 400, function (value) {
                contactsContainer.isPending = true
                searchResults.showProfileNotFoundMessage = false
                profileModel.contacts.lookupContact(value)
            })

            onOpened: {
                addContactSearchInput.text = ""
                searchResults.reset()
            }

            Input {
                id: addContactSearchInput
                //% "Enter ENS username or chat key"
                placeholderText: qsTrId("enter-contact-code")
                customHeight: 44
                fontPixelSize: 15
                Keys.onReleased: {
                    if (!addContactModal.validate(addContactSearchInput.text)) {
                        searchResults.reset()
                        contactsContainer.isPending = false
                        return;
                    }

                    Qt.callLater(addContactModal.lookupContact, addContactSearchInput.text)
                }


                Connections {
                    target: profileModel.contacts
                    function onEnsWasResolved(resolvedPubKey) {
                        if (resolvedPubKey === "") {
                            searchResults.pubKey = ""
                            searchResults.showProfileNotFoundMessage = true
                            contactsContainer.isPending = false
                            return
                        }
                        searchResults.username = utilsModel.generateAlias(resolvedPubKey)
                        searchResults.userAlias = Utils.compactAddress(resolvedPubKey, 4)
                        searchResults.pubKey = resolvedPubKey
                        searchResults.showProfileNotFoundMessage = false
                        contactsContainer.isPending = false
                    }
                }
            }

            StyledText {
                id: validationErrorMessage
                text: addContactModal.validationError
                visible: addContactModal.validationError !== ""
                font.pixelSize: 13
                color: Style.current.danger
                anchors.top: addContactSearchInput.bottom
                anchors.topMargin: Style.current.smallPadding
                anchors.horizontalCenter: parent.horizontalCenter
            }

            SearchResults {
                id: searchResults
                anchors.top: addContactSearchInput.bottom
                anchors.topMargin: Style.current.xlPadding
                loading: contactsContainer.isPending
                resultClickable: false
                onAddToContactsButtonClicked: profileModel.contacts.addContact(pubKey)
            }
        }

        ContactList {
            id: contactListView
            anchors.top: blockedContactsButton.bottom
            anchors.topMargin: Style.current.bigPadding
            anchors.bottom: parent.bottom
            contacts: profileModel.contacts.addedContacts
            searchString: searchBox.text
        }

        NoFriendsRectangle {
            id: element
            visible: profileModel.contacts.addedContacts.rowCount() === 0
            //% "You don’t have any contacts yet"
            text: qsTrId("you-don-t-have-any-contacts-yet")
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;formeditorColor:"#ffffff";formeditorZoom:0.6600000262260437;height:480;width:600}
}
##^##*/
