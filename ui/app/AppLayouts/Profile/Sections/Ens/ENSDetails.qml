import QtQuick 2.14
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.14
import "../../../../../imports"
import "../../../../../shared"

Item {
    property var onClick: function(){}
    property string username: ""
    property string walletAddress: "-"
    property string key: "-"

    StyledText {
        id: sectionTitle
        text: username
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 24
        font.weight: Font.Bold
        font.pixelSize: 20
    }

    Component {
        id: loadingImageComponent
        LoadingImage {}
    }

    Loader {
        id: loadingImg
        active: false
        sourceComponent: loadingImageComponent
        anchors.right: parent.right
        anchors.rightMargin: Style.current.padding
        anchors.top: parent.top
        anchors.topMargin: Style.currentPadding
    }

    Connections {
        target: profileModel.ens
        onDetailsObtained: {
            if(username != ensName) return;
                walletAddressLbl.text = address;
                walletAddressLbl.textToCopy = address;
                keyLbl.text = pubkey.substring(0, 20) + "..." + pubkey.substring(pubkey.length - 20);
                keyLbl.textToCopy = pubkey;
                walletAddressLbl.visible = true;
                keyLbl.visible = true;
        }
        onLoading: {
            console.log("ABC")
            loadingImg.active = isLoading
            if(!isLoading) return;
            walletAddressLbl.visible = false;
            keyLbl.visible = false;
        }
    }

    TextWithLabel {
        id: walletAddressLbl
        label: qsTr("Wallet address")
        visible: false
        text:  ""
        textToCopy: ""
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: sectionTitle.bottom
        anchors.topMargin: 24
    }

    TextWithLabel {
        id: keyLbl
        visible: false
        label: qsTr("Key")
        text: ""
        textToCopy: ""
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: walletAddressLbl.bottom
        anchors.topMargin: 24
    }

    StyledButton {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.current.padding
        anchors.horizontalCenter: parent.horizontalCenter
        label: qsTr("Back")
        onClicked: onClick()
    }
}