import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtGraphicalEffects 1.13
import "../imports"
import "../shared/status"

Item {
    id: root
    property var fromAccount
    property var toAccount
    property var asset
    property var amount
    property string currency: "USD"
    property var gas
    height: content.height
    property var reset: function() {}
    signal fromClicked
    signal gasClicked
    // Creates a mouse area around the "from account". When clicked, triggers 
    // the "fromClicked" signal
    property bool isFromEditable: false
    // Creates a mouse area around the "network fee". When clicked, triggers 
    // the "gasClicked" signal
    property bool isGasEditable: false
    property bool isValid: toValid && fromValid && gasValid
    property bool fromValid: true
    property bool toValid: true
    property bool toWarn: false
    property bool gasValid: true

    function resetInternal() {
        fromAccount = undefined
        toAccount = undefined
        asset = undefined
        amount = undefined
        gas = undefined
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        LabelValueRow {
            id: itmFrom
            //% "From"
            label: qsTrId("from")
            value: Item {
                id: itmFromValue
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter
                function needsRightPadding() {
                    return !root.fromValid || root.isFromEditable
                }
                Row {
                    spacing: Style.current.halfPadding
                    rightPadding: itmFromValue.needsRightPadding() ? Style.current.halfPadding : 0
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        font.pixelSize: 15
                        height: 22
                        text: root.fromAccount ? root.fromAccount.name : ""
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    SVGImage {
                        id: imgFromWallet
                        sourceSize.height: 18
                        sourceSize.width: 18
                        visible: !!root.fromAccount ? root.fromAccount.type === RecipientSelector.Type.Account : true
                        horizontalAlignment: Image.AlignLeft
                        width: itmFromValue.needsRightPadding() ? (Style.current.halfPadding + sourceSize.width) : undefined // adding width to add addl spacing to image
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        source: "../app/img/walletIcon.svg"
                        ColorOverlay {
                            visible: parent.visible
                            anchors.fill: parent
                            source: parent
                            color: root.fromAccount && root.fromAccount.iconColor ? root.fromAccount.iconColor : Style.current.blue
                        }
                    }
                    SVGImage {
                        id: fromInvalid
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13.33
                        height: 13.33
                        sourceSize.height: height * 2
                        sourceSize.width: width * 2
                        fillMode: Image.PreserveAspectFit
                        source: "../app/img/exclamation_outline.svg"
                        visible: !root.fromValid
                    }
                    SVGImage {
                        id: fromArrow
                        width: 13
                        visible: root.isFromEditable
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        source: "../app/img/caret.svg"
                        rotation: 270
                        ColorOverlay {
                            anchors.fill: parent
                            visible: parent.visible
                            source: parent
                            color: Style.current.secondaryText
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    visible: fromArrow.visible
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.fromClicked()
                }
            }
        }
        LabelValueRow {
            id: itmTo
            function needsRightPadding() {
                return !root.toValid || root.toWarn
            }
            //% "Recipient"
            label: qsTrId("recipient")
            states: [
                State {
                    name: "Address"
                    when: !!root.toAccount && root.toAccount.type === RecipientSelector.Type.Address
                    PropertyChanges {
                        target: txtToPrimary
                        text: root.toAccount ? root.toAccount.address : ""
                        elide: Text.ElideMiddle
                        anchors.leftMargin: 190
                        anchors.right: parent.right
                    }
                    PropertyChanges {
                        target: txtToSecondary
                        width: 0
                    }
                },
                State {
                    name: "Contact"
                    when: !!root.toAccount && root.toAccount.type === RecipientSelector.Type.Contact && !!root.toAccount.address
                    PropertyChanges {
                        target: metSecondary
                        text: root.toAccount.ensVerified ? root.toAccount.alias : root.toAccount.address
                    }
                    PropertyChanges {
                        target: txtToSecondary
                        anchors.right: idtToContact.left
                        anchors.rightMargin: Style.current.halfPadding
                        width: txtToSecondary.visible ? metSecondary.elidedWidth : 0
                        text: metSecondary.elidedText
                        visible: root.toAccount.address !== Constants.zeroAddress
                    }
                    PropertyChanges {
                        target: idtToContact
                        source: root.toAccount.identicon
                        visible: true
                    }
                    PropertyChanges {
                        target: txtToPrimary
                        text: Utils.removeStatusEns(root.toAccount.name)
                    }
                },
                State {
                    name: "Account"
                    when: !!root.toAccount && root.toAccount.type === RecipientSelector.Type.Account && !!root.toAccount.address
                    PropertyChanges {
                        target: metSecondary
                        text: root.toAccount.address
                    }
                    PropertyChanges {
                        target: txtToSecondary
                        anchors.right: imgToWallet.left
                        anchors.rightMargin: Style.current.halfPadding
                        text: metSecondary.elidedText
                        width: metSecondary.elidedWidth
                    }
                    PropertyChanges {
                        target: imgToWallet
                        visible: true
                    }
                    PropertyChanges {
                        target: ovlToWallet
                        visible: true
                        color: root.toAccount.iconColor
                    }
                    PropertyChanges {
                        target: txtToPrimary
                        text: root.toAccount.name
                    }
                }
            ]

            StyledText {
                id: txtToPrimary
                font.pixelSize: 15
                height: 22
                anchors.left: parent.left
                anchors.right: txtToSeparator.visible ? txtToSeparator.left : idtToContact.left
                anchors.rightMargin: txtToSeparator.visible ? 0 : Style.current.halfPadding
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            StyledText {
                id: txtToSeparator
                font.pixelSize: 15
                height: 22
                text: " • "
                visible: txtToSecondary.visible && txtToSecondary.width > 0
                color: Style.current.secondaryText
                anchors.right: txtToSecondary.left
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
            StyledText {
                id: txtToSecondary
                visible: true
                font.pixelSize: 15
                height: 22
                color: Style.current.secondaryText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
            TextMetrics {
                id: metSecondary
                elideWidth: 102
                elide: Text.ElideMiddle
            }
            SVGImage {
                id: imgToWallet
                visible: false
                sourceSize.height: 18
                sourceSize.width: 18
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                source: "../app/img/walletIcon.svg"
            }
            ColorOverlay {
                id: ovlToWallet
                anchors.fill: imgToWallet
                visible: false
                source: imgToWallet
            }
            StatusImageIdenticon {
                id: idtToContact
                visible: false
                anchors.right: toInvalid.visible ? toInvalid.left : parent.right
                anchors.rightMargin: toInvalid.visible ? Style.current.halfPadding : 0
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
            }
            SVGImage {
                id: toInvalid
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                width: 13.33
                height: 13.33
                sourceSize.height: height * 2
                sourceSize.width: width * 2
                fillMode: Image.PreserveAspectFit
                source: "../app/img/exclamation_outline.svg"
                visible: !root.toValid || root.toWarn
            }
        }
        LabelValueRow {
            id: itmAsset
            //% "Asset"
            label: qsTrId("wallet-asset")
            value: Item {
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    font.pixelSize: 15
                    height: 22
                    text: (root.asset && root.asset.name) ? root.asset.name : ""
                    anchors.left: parent.left
                    anchors.right: txtAssetSymbol.left
                    anchors.rightMargin: Style.current.halfPadding
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }
                StyledText {
                    id: txtAssetSymbol
                    font.pixelSize: 15
                    height: 22
                    text: (root.asset && root.asset.symbol) ? root.asset.symbol : ""
                    color: Style.current.secondaryText
                    anchors.right: imgAsset.left
                    anchors.rightMargin: Style.current.halfPadding
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }
                Image {
                    id: imgAsset
                    sourceSize.height: 32
                    sourceSize.width: 32
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    source: "../app/img/tokens/" + ((root.asset && root.asset.symbol) ? root.asset.symbol : "ETH") + ".png"
                    onStatusChanged: {
                        if (status == Image.Error) {
                            source = "../app/img/tokens/0-native.png"
                        }
                    }
                }
            }
        }
        LabelValueRow {
            id: itmAmount
            //% "Amount"
            label: qsTrId("amount")
            value: Item {
                id: amountRoot
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    font.pixelSize: 15
                    height: 22
                    text: (root.amount && root.amount.value) ? Utils.stripTrailingZeros(root.amount.value) : ""
                    anchors.left: parent.left
                    anchors.right: txtAmountSymbol.left
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                StyledText {
                    id: txtAmountSymbol
                    font.pixelSize: 15
                    height: 22
                    text: ((root.asset && root.asset.symbol) ? root.asset.symbol : "") + " •"
                    color: Style.current.secondaryText
                    anchors.right: txtAmountFiat.left
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }
                StyledText {
                    id: txtAmountFiat
                    font.pixelSize: 15
                    height: 22
                    text: "~" + (root.amount && root.amount.fiatValue ? root.amount.fiatValue : "0.00")
                    anchors.right: txtAmountCurrency.left
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }
                StyledText {
                    id: txtAmountCurrency
                    font.pixelSize: 15
                    height: 22
                    text: root.currency.toUpperCase()
                    color: Style.current.secondaryText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        LabelValueRow {
            id: itmNetworkFee
            //% "Network fee"
            label: qsTrId("network-fee")
            visible: !!root.gas
            value: Item {
                id: networkFeeRoot
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter
                function needsRightPadding() {
                    return !root.gasValid || root.isGasEditable
                }
                Row {
                    spacing: Style.current.halfPadding
                    rightPadding: networkFeeRoot.needsRightPadding() ? Style.current.halfPadding : 0
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    StyledText {
                        font.pixelSize: 15
                        height: 22
                        text: (root.gas && root.gas.value) ? Utils.stripTrailingZeros(root.gas.value) : ""
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    StyledText {
                        id: txtFeeSymbol
                        font.pixelSize: 15
                        height: 22
                        text: ((root.gas && root.gas.symbol) ? root.gas.symbol : "") + " •"
                        color: Style.current.secondaryText
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    StyledText {
                        id: txtFeeFiat
                        font.pixelSize: 15
                        height: 22
                        text: "~" + ((root.gas && root.gas.fiatValue) ? root.gas.fiatValue : "0.00")
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    StyledText {
                        id: txtFeeCurrency
                        font.pixelSize: 15
                        height: 22
                        text: root.currency.toUpperCase()
                        color: Style.current.secondaryText
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    SVGImage {
                        id: gasInvalid
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13.33
                        height: 13.33
                        sourceSize.height: height * 2
                        sourceSize.width: width * 2
                        fillMode: Image.PreserveAspectFit
                        source: "../app/img/exclamation_outline.svg"
                        visible: !root.gasValid
                    }
                    SVGImage {
                        id: gasArrow
                        width: 13
                        visible: root.isGasEditable
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        source: "../app/img/caret.svg"
                        rotation: 270
                        ColorOverlay {
                            anchors.fill: parent
                            visible: parent.visible
                            source: parent
                            color: Style.current.secondaryText
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    visible: gasArrow.visible
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.gasClicked()
                }
            }
        }
    }
}
