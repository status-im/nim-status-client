import QtQuick 2.3
import "../../../../../shared"
import "../../../../../imports"
import "./TransactionComponents"
import "../../../Wallet/data"

Item {
    property var commandParametersObject: {
        try {
            return JSON.parse(commandParameters)
        } catch (e) {
            console.error('Error parsing command parameters')
            console.error('JSON:', commandParameters)
            console.error('Error:', e)
            return {
                id: "",
                fromAddress: "",
                address: "",
                contract: "",
                value: "",
                transactionHash: "",
                commandState: 1,
                signature: null
            }
        }
    }
    property var token: JSON.parse(commandParametersObject.contract) // TODO: handle {}
    property string tokenAmount: commandParametersObject.value
    property string tokenSymbol: token.symbol || ""
    property string fiatValue: {
        if (!tokenAmount || !token.symbol) {
            return "0"
        }
        var defaultFiatSymbol = walletModel.balanceView.defaultCurrency
        return walletModel.balanceView.getFiatValue(tokenAmount, token.symbol, defaultFiatSymbol) + " " + defaultFiatSymbol.toUpperCase()
    }
    property int state: commandParametersObject.commandState

    // Any transaction where isCurrentUser is true is actually outgoing transaction.
    property bool outgoing: isCurrentUser

    property int innerMargin: 12
    property bool isError: commandParametersObject.contract === "{}"
    onTokenSymbolChanged: {
        if (!!tokenSymbol) {
            tokenImage.source = `../../../../img/tokens/${root.tokenSymbol}.png`
        }
    }

    id: root
    width: rectangleBubble.width
    height: rectangleBubble.height

    Rectangle {
        id: rectangleBubble
        width: (bubbleLoader.active ? bubbleLoader.width : valueContainer.width)
               + timeText.width + 3 * root.innerMargin
        height: childrenRect.height + root.innerMargin
        radius: 16
        color: Style.current.background
        border.color: Style.current.border
        border.width: 1

        StyledText {
            id: title
            color: Style.current.secondaryText
            text: {
                if (root.state === Constants.transactionRequested) {
                    let prefix = outgoing? "↑ " : "↓ "
                    //% "Transaction request"
                    return prefix + qsTrId("transaction-request")
                }

                return outgoing ?
                    //% "↑ Outgoing transaction"
                    qsTrId("--outgoing-transaction") :
                    //% "↓ Incoming transaction"
                    qsTrId("--incoming-transaction")
            }
            font.weight: Font.Medium
            anchors.top: parent.top
            anchors.topMargin: Style.current.halfPadding
            anchors.left: parent.left
            anchors.leftMargin: root.innerMargin
            font.pixelSize: 13
        }

        Item {
            id: valueContainer
            width: childrenRect.width
            height: tokenText.height + fiatText.height
            anchors.top: title.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.leftMargin: root.innerMargin

            StyledText {
                id: txtError
                color: Style.current.danger
                visible: root.isError
                //% "Something has gone wrong"
                text: qsTrId("something-has-gone-wrong")
            }

            Image {
                id: tokenImage
                visible: !root.isError
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                id: tokenText
                visible: !root.isError
                color: Style.current.textColor
                text: `${root.tokenAmount} ${root.tokenSymbol}`
                anchors.left: tokenImage.right
                anchors.leftMargin: Style.current.halfPadding
                font.pixelSize: 22
            }

            StyledText {
                id: fiatText
                visible: !root.isError
                color: Style.current.secondaryText
                text: root.fiatValue
                anchors.top: tokenText.bottom
                anchors.left: tokenText.left
                font.pixelSize: 13
            }
        }

        Loader {
            id: bubbleLoader
            active: {
                return !root.isError && (
                    isCurrentUser || 
                    (!isCurrentUser && 
                        !(root.state === Constants.addressRequested || 
                        root.state === Constants.transactionRequested)
                    )
                )
            }
            sourceComponent: stateBubbleComponent
            anchors.top: valueContainer.bottom
            anchors.topMargin: Style.current.halfPadding
            anchors.left: parent.left
            anchors.leftMargin: root.innerMargin
        }

        Component {
            id: stateBubbleComponent

            StateBubble {
                state: root.state
                outgoing: root.outgoing
            }
        }

        Loader {
            id: buttonsLoader
            active: !root.isError && (
                    (root.state === Constants.addressRequested && !root.outgoing) ||
                    (root.state === Constants.addressReceived && root.outgoing) ||
                    (root.state === Constants.transactionRequested && !root.outgoing)
            )
            sourceComponent: root.outgoing ? signAndSendComponent : acceptTransactionComponent
            anchors.top: bubbleLoader.active ? bubbleLoader.bottom : valueContainer.bottom
            anchors.topMargin: bubbleLoader.active ? root.innerMargin : 20
            width: parent.width
        }

        Component {
            id: acceptTransactionComponent

            AcceptTransaction {
                state: root.state
            }
        }

        Component {
            id: signAndSendComponent

            SendTransactionButton {
                // outgoing: root.outgoing
            }
        }

        StyledText {
            id: timeText
            color: Style.current.secondaryText
            text: Utils.formatTime(timestamp)
            anchors.left: bubbleLoader.active ? bubbleLoader.right : undefined
            anchors.leftMargin: bubbleLoader.active ? 13 : 0
            anchors.right: bubbleLoader.active ? undefined : parent.right
            anchors.rightMargin: bubbleLoader.active ? 0 : root.innerMargin
            anchors.bottom: bubbleLoader.active ? bubbleLoader.bottom : buttonsLoader.top
            anchors.bottomMargin: bubbleLoader.active ? -root.innerMargin : 7
            font.pixelSize: 10
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorColor:"#4c4e50";formeditorZoom:1.25}
}
##^##*/
