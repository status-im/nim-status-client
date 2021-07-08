import QtQuick 2.14
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.14
import "../../../../../imports"
import "../../../../../shared"
import "../../../../../shared/status"

Item {
    id: searchENS

    signal continueClicked(string output, string username)
    signal usernameUpdated(username: string);


    property string validationMessage: ""
    property bool valid: false
    property bool isStatus: true
    property bool loading: false
    property string ensStatus: ""

    property var validateENS: Backpressure.debounce(searchENS, 500, function (ensName, isStatus){
        profileModel.ens.validate(ensName, isStatus)
    });

    function validate(ensUsername) {
        validationMessage = "";
        valid = false;
        ensStatus = "";
        if (ensUsername.length < 4) {
            //% "At least 4 characters. Latin letters, numbers, and lowercase only."
            validationMessage = qsTrId("ens-username-hints");
        } else if(isStatus && !ensUsername.match(/^[a-z0-9]+$/)){
            //% "Letters and numbers only."
            validationMessage = qsTrId("ens-username-invalid");
        } else if(!isStatus && !ensUsername.endsWith(".eth")){
            //% "Type the entire username including the custom domain like username.domain.eth"
            validationMessage = qsTrId("ens-custom-username-hints")
        }
        return validationMessage === "";
    }

    function onKeyReleased(ensUsername){
        if (!validate(ensUsername)) {
            return;
        }
        loading = true;
        Qt.callLater(validateENS, ensUsername, isStatus)
    }

    Loader {
        id: transactionDialog
        function open() {
            this.active = true
            this.item.open()
        }
        function closed() {
            this.active = false // kill an opened instance
        }
        sourceComponent: SetPubKeyModal {
            onClosed: {
                transactionDialog.closed()
            }
            ensUsername: ensUsername.text || ""
            width: 400
            height: 400
        }
    }

    Item {
        id: ensContainer
        anchors.top: parent.top
        width: profileContainer.profileContentWidth
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            id: circleAt
            anchors.top: parent.top
            anchors.topMargin: Style.current.bigPadding*2
            anchors.horizontalCenter: parent.horizontalCenter
            width: 60
            height: 60
            radius: 120
            color: Style.current.blue

            SVGImage {
                id: imgIcon
                visible: ensStatus === Constants.ens_taken
                fillMode: Image.PreserveAspectFit
                source: "../../../../img/block-icon-white.svg"
                width: 20
                height: 20
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: ensStatus !== Constants.ens_taken
                text: {
                    if((ensStatus === Constants.ens_available || 
                         ensStatus === Constants.ens_connected || 
                         ensStatus === Constants.ens_connected_dkey)) {
                        return "✓"
                    } else {
                        return "@"
                    }
                }
                opacity: 0.7
                font.weight: Font.Bold
                font.pixelSize: 18
                color: Style.current.white
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Input {
            id: ensUsername
            placeholderText: !isStatus ? "vitalik94.domain.eth" : "vitalik94"
            anchors.top: circleAt.bottom
            anchors.topMargin: Style.current.bigPadding
            anchors.right: btnContinue.left
            anchors.rightMargin: Style.current.bigPadding
            Keys.onReleased: {
                onKeyReleased(ensUsername.text);
            }

            Connections {
                target: profileModel.ens
                function onEnsWasResolved(ensResult) {
                    if(!validate(ensUsername.text)) return;
                    valid = false;
                    loading = false;
                    ensStatus = ensResult;
                    switch(ensResult){
                        case "available":
                        case "owned":
                        case "connected":
                        case "connected-different-key":
                            valid = true;
                            validationMessage = Constants.ensState[ensResult]
                            break;
                        case "taken":
                            validationMessage = Constants.ensState[!isStatus ? 'taken-custom' : 'taken']
                            break;
                        case "already-connected":
                            validationMessage = Constants.ensState[ensResult]
                            break;
                    }
                }
            }
        }

        StatusRoundButton {
            id: btnContinue
            width: 44
            height: 44
            anchors.top: circleAt.bottom
            anchors.topMargin: Style.current.bigPadding
            anchors.right: parent.right
            size: "medium"
            type: "secondary"
            icon.name: "arrow-right"
            icon.width: 18
            icon.height: 14
            visible: valid
            onClicked: {
                if(!valid) return;

                if(ensStatus === Constants.ens_connected){
                    profileModel.ens.connectOwnedUsername(ensUsername.text, isStatus);
                    continueClicked(ensStatus, ensUsername.text)
                    return;
                }

                if(ensStatus === Constants.ens_available){
                    continueClicked(ensStatus, ensUsername.text);
                    return;
                }

                if(ensStatus === Constants.ens_connected_dkey || ensStatus === Constants.ens_owned){
                    transactionDialog.open();
                    return;
                }
            }
        }

        Rectangle {
            id: ensTypeRect
            anchors.top: ensUsername.bottom
            anchors.topMargin: Style.current.bigPadding
            border.width: 1
            border.color: Style.current.border
            color: Style.current.background
            radius: 50
            height: 30
            width: 350

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Style.current.halfPadding
                anchors.leftMargin: Style.current.padding
                height: 20

                StyledText {
                    text: !isStatus ? 
                        //% "Custom domain"
                        qsTrId("ens-custom-domain")
                        :
                        ".stateofus.eth"
                    font.weight: Font.Bold
                    font.pixelSize: 12
                    anchors.leftMargin: Style.current.padding
                    color: Style.current.textColor
                }

                StyledText {
                    text: !isStatus ? 
                        //% "I want a stateofus.eth domain"
                        qsTrId("ens-want-domain")
                        :
                        //% "I own a name on another domain"
                        qsTrId("ens-want-custom-domain")
                    font.pixelSize: 12
                    color: Style.current.blue
                    anchors.right: parent.right
                    anchors.rightMargin: Style.current.padding

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        onClicked : {
                            isStatus = !isStatus;
                            let ensUser = ensUsername.text;
                            if(validate(ensUser))
                                validateENS(ensUser, isStatus)
                        }
                    }
                }
            }
        }

        StyledText {
            id: validationResult
            text: validationMessage
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            anchors.top: ensTypeRect.bottom
            wrapMode: Text.WordWrap
            anchors.topMargin: Style.current.bigPadding
        }
    }
}
