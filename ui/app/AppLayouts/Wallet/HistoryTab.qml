import QtQuick 2.13
import QtQuick.Controls 2.1
import QtQuick.Layouts 1.3
import "./components"
import "./data"
import "../../../imports"
import "../../../shared"
import "../../../shared/status/core"
import "../../../shared/status"

Item {
    property int pageSize: 20 // number of transactions per page
    property var tokens: {
        let count = walletModel.tokensView.defaultTokenList.rowCount()
        const toks = []
        for (let i = 0; i < count; i++) {
            toks.push({
                          "address": walletModel.tokensView.defaultTokenList.rowData(i, 'address'),
                          "symbol": walletModel.tokensView.defaultTokenList.rowData(i, 'symbol')
                      })
        }
        count = walletModel.tokensView.customTokenList.rowCount()
        for (let j = 0; j < count; j++) {
            toks.push({
                          "address": walletModel.customTokenList.rowData(j, 'address'),
                          "symbol": walletModel.customTokenList.rowData(j, 'symbol')
                      })
        }
        return toks
    }

    function fetchHistory() {
        if (walletModel.historyView.isFetchingHistory(walletModel.accountsView.currentAccount.address)) {
            loadingImg.active = true
        } else {
            walletModel.historyView.loadTransactionsForAccount(
                        walletModel.accountsView.currentAccount.address, 
                        walletModel.transactionsView.transactions.getLastTxBlockNumber(),
                        pageSize,
                        true)
        }
    }

    // function checkIfHistoryIsBeingFetched() {
    //     loadMoreButton.loadedMore = false;

    //     // prevent history from being fetched everytime you click on
    //     // the history tab
    //     if (walletModel.historyView.isHistoryFetched(walletModel.accountsView.currentAccount.account))
    //         return;

    //     fetchHistory();
    // }

    id: root

    Loader {
        id: loadingImg
        active: false
        sourceComponent: loadingImageComponent
        anchors.right: parent.right
        anchors.rightMargin: Style.current.padding
        anchors.top: parent.top
    }

    Component {
        id: loadingImageComponent
        StatusLoadingIndicator {}
    }

    Connections {
        target: walletModel.historyView
        // onHistoryWasFetched: checkIfHistoryIsBeingFetched()
        function onLoadingTrxHistoryChanged(isLoading, address) {
            if (walletModel.accountsView.currentAccount.address.toLowerCase() === address.toLowerCase()) {
                loadingImg.active = isLoading
            }
        }
    }

    Component {
        id: transactionListItemCmp

        Rectangle {
            id: transactionListItem
            property bool isHovered: false
            property string symbol: ""
            property bool isIncoming: to === walletModel.accountsView.currentAccount.address
            anchors.right: parent.right
            anchors.left: parent.left
            height: 64
            color: isHovered ? Style.current.secondaryBackground : Style.current.transparent
            radius: 8

            Component.onCompleted: {
                const count = root.tokens.length
                for (var i = 0; i < count; i++) {
                    let token = root.tokens[i]
                    if (token.address === contract) {
                        transactionListItem.symbol = token.symbol
                        break
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: transactionModal.open()
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: {
                    transactionListItem.isHovered = true
                }
                onExited: {
                    transactionListItem.isHovered = false
                }
            }

            TransactionModal {
                id: transactionModal
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Style.current.smallPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Image {
                    id: assetIcon
                    width: 40
                    height: 40
                    source: "../../img/tokens/"
                            + (transactionListItem.symbol
                               != "" ? transactionListItem.symbol : "ETH") + ".png"
                    anchors.verticalCenter: parent.verticalCenter
                    onStatusChanged: {
                        if (assetIcon.status == Image.Error) {
                            assetIcon.source = "../../img/tokens/DEFAULT-TOKEN@3x.png"
                        }
                    }

                    anchors.leftMargin: Style.current.padding
                }

                StyledText {
                    id: transferIcon
                    anchors.verticalCenter: parent.verticalCenter
                    height: 15
                    width: 15
                    color: isIncoming ? Style.current.success : Style.current.danger
                    text: isIncoming ? "↓" : "↑"
                }

                StyledText {
                    id: transactionValue
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Style.current.primaryTextFontSize
                    text: utilsModel.hex2Eth(value) + " " + transactionListItem.symbol
                }
            }

            Row {
                anchors.right: timeInfo.left
                anchors.rightMargin: Style.current.smallPadding
                anchors.top: parent.top
                anchors.topMargin: Style.current.bigPadding
                spacing: 5

                StyledText {
                    text: isIncoming ?
                            //% "From "
                            qsTrId("from-") :
                            //% "To "
                            qsTrId("to-")
                    color: Style.current.secondaryText
                    font.pixelSize: Style.current.primaryTextFontSize
                    font.strikeout: false
                }

                Address {
                    id: addressValue
                    text: isIncoming ? fromAddress : to
                    maxWidth: 120
                    width: 120
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: Style.current.primaryTextFontSize
                    color: Style.current.textColor
                }
            }

            Row {
                id: timeInfo
                anchors.right: parent.right
                anchors.rightMargin: Style.current.smallPadding
                anchors.top: parent.top
                anchors.topMargin: Style.current.bigPadding
                spacing: 5

                StyledText {
                    text: " • "
                    font.weight: Font.Bold
                    color: Style.current.secondaryText
                    font.pixelSize: Style.current.primaryTextFontSize
                }

                StyledText {
                    id: timeIndicator
                    text: qsTr("At ")
                    color: Style.current.secondaryText
                    font.pixelSize: Style.current.primaryTextFontSize
                    font.strikeout: false
                }
                StyledText {
                    id: timeValue
                    text: new Date(timestamp).toLocaleString(globalSettings.locale)
                    font.pixelSize: Style.current.primaryTextFontSize
                    anchors.rightMargin: Style.current.smallPadding
                }
            }
        }
    }

    StyledText {
        id: nonArchivalNodeError
        visible: walletModel.isNonArchivalNode
        height: visible ? implicitHeight : 0
        anchors.top: parent.top
        text: qsTr("Status Desktop is connected to a non-archival node. Transaction history may be incomplete.")
        font.pixelSize: Style.current.primaryTextFontSize
        color: Style.current.danger
    }

    StyledText {
        id: noTxs
        anchors.top: nonArchivalNodeError.bottom
        visible: transactionListRoot.count === 0
        height: visible ? implicitHeight : 0
        text: qsTr("No transactions found")
        font.pixelSize: Style.current.primaryTextFontSize
    }

    ListView {
        id: transactionListRoot
        anchors.top: noTxs.bottom
        anchors.topMargin: Style.current.padding
        anchors.bottom: loadMoreButton.top
        anchors.bottomMargin: Style.current.padding
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: walletModel.transactionsView.transactions
        delegate: transactionListItemCmp
        ScrollBar.vertical: ScrollBar {
            id: scrollBar
        }

        onCountChanged: {
            if (loadMoreButton.loadedMore)
                transactionListRoot.positionViewAtEnd();
        }
    }

    StatusButton {
        id: loadMoreButton
        //% "Load More"
        text: qsTrId("load-more")
        // TODO: handle case when requested limit === transaction count -- there
        // is currently no way to know that there are no more results
        enabled: !loadingImg.active && walletModel.transactionsView.transactions.hasMore
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.current.padding
        property bool loadedMore: false

        onClicked: {
            fetchHistory()
            loadMoreButton.loadedMore = true
        }
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/

