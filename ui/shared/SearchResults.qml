import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../imports"
import "./status"
// TODO move Contact into shared to get rid of that import
import "../app/AppLayouts/Chat/components"
import "./"


Item {
    id: root
    height: 64
    property bool hasExistingContacts: false
    property bool showProfileNotFoundMessage: false
    property bool loading: false
    property string username: ""
    property string userAlias: ""
    property string pubKey: ""
    property string address: ""
    property bool resultClickable: true
    property bool addContactEnabled: true

    property bool isAddedContact: pubKey != "" ? chatsModel.messageView.isAddedContact(pubKey) : false

    signal resultClicked(string pubKey)
    signal addToContactsButtonClicked(string pubKey)

    function reset() {
        hasExistingContacts = false
        showProfileNotFoundMessage = false
        username = ""
        userAlias = ""
        pubKey = ""
    }

    width: parent.width

    StyledText {
        id: nonContactsLabel
        //% "Non contacts"
        text: qsTrId("non-contacts")
        anchors.top: parent.top
        color: Style.current.secondaryText
        font.pixelSize: 15
        visible: root.hasExistingContacts && (root.loading || root.pubKey !== "" || root.showProfileNotFoundMessage)
    }

    Loader {
        active: root.loading
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: Component {
            LoadingAnimation {
                width: 18
                height: 18
            }
        }
    }

    Rectangle {
        id: foundContact
        property bool hovered: false
        anchors.top: nonContactsLabel.visible ? nonContactsLabel.bottom : parent.top
        color: hovered ? Style.current.backgroundHover : Style.current.background
        radius: Style.current.radius
        width: parent.width
        height: 64
        visible: root.pubKey !== "" && !root.loading

        StatusImageIdenticon {
            id: contactIdenticon
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.current.padding
            source: utilsModel.generateIdenticon(root.pubKey)
        }

        StyledText {
            id: ensUsername
            font.pixelSize: 17
            color: Style.current.textColor
            anchors.top: contactIdenticon.top
            anchors.left: contactIdenticon.right
            anchors.leftMargin: Style.current.padding
            text: root.username
        }

        StyledText {
            id: contactAlias
            font.pixelSize: 15
            color: Style.current.secondaryText
            anchors.top: ensUsername.bottom
            anchors.topMargin: 2
            anchors.left: ensUsername.left
            text: root.userAlias
        }

        MouseArea {
            cursorShape: root.resultClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            anchors.fill: parent
            hoverEnabled: true
            onEntered: foundContact.hovered = true
            onExited: foundContact.hovered = false
            onClicked: {
                if (root.resultClickable) {
                    root.resultClicked(root.pubKey)
                }
            }
        }

        StatusIconButton {
            id: addContactBtn
            icon.name: "add-contact"
            highlightedBackgroundColor: Utils.setColorAlpha(Style.current.buttonHoveredBackgroundColor, 0.2)
            iconColor: Style.current.primary
            icon.width: 24
            icon.height: 24
            width: 32
            height: 32
            anchors.right: parent.right
            anchors.rightMargin: Style.current.padding
            anchors.verticalCenter: parent.verticalCenter
            visible: addContactEnabled && !isAddedContact && !checkIcon.visible
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    foundContact.hovered = true
                }
                onExited: {
                    foundContact.hovered = false
                }
                onClicked: {
                    root.addToContactsButtonClicked(root.pubKey)
                    mouse.accepted = false
                }
            }
        }

        SVGImage {
            id: checkIcon
            source: "../../../../app/img/check-2.svg"
            width: 19
            height: 19
            anchors.right: parent.right
            anchors.rightMargin: Style.current.smallPadding * 2
            anchors.verticalCenter: parent.verticalCenter
            visible: foundContact.hovered && isAddedContact
        }
    }

    StyledText {
        id: profileNotFoundMessage
        color: Style.current.secondaryText
        visible: root.showProfileNotFoundMessage
        font.pixelSize: 15
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        //% "No profile found"
        text: qsTrId("no-profile-found")
    }

}
