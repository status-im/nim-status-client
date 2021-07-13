import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtQuick.Dialogs 1.3
import "../../imports"
import "../../shared"
import "../../shared/status"

ModalPopup {
    id: root
    readonly property var asset: JSON.parse(walletModel.getStatusToken())
    property int stickerPackId: -1
    property string packPrice
    property bool showBackBtn: false

    Component.onCompleted: {
        walletModel.gasView.getGasPricePredictions()
    }

    //% "Authorize %1 %2"
    title: qsTrId("authorize--1--2").arg(Utils.stripTrailingZeros(packPrice)).arg(asset.symbol)

    property MessageDialog sendingError: MessageDialog {
        id: sendingError
        //% "Error sending the transaction"
        title: qsTrId("error-sending-the-transaction")
        icon: StandardIcon.Critical
        standardButtons: StandardButton.Ok
    }

    function sendTransaction() {
        let responseStr = chatsModel.stickers.buy(root.stickerPackId,
                                                  selectFromAccount.selectedAccount.address,
                                                  root.packPrice,
                                                  gasSelector.selectedGasLimit,
                                                  gasSelector.selectedGasPrice,
                                                  transactionSigner.enteredPassword)
        let response = JSON.parse(responseStr)

        if (!response.success) {
            if (Utils.isInvalidPasswordMessage(response.result)){
                //% "Wrong password"
                transactionSigner.validationError = qsTrId("wrong-password")
                return
            }
            sendingError.text = response.result
            return sendingError.open()
        }
        root.close()
    }

    TransactionStackView {
        id: stack
        height: parent.height
        anchors.fill: parent
        anchors.leftMargin: Style.current.padding
        anchors.rightMargin: Style.current.padding
        onGroupActivated: {
            root.title = group.headerText
            btnNext.text = group.footerText
        }
        TransactionFormGroup {
            id: group1
            //% "Authorize %1 %2"
            headerText: qsTrId("authorize--1--2").arg(Utils.stripTrailingZeros(root.packPrice)).arg(root.asset.symbol)
            //% "Continue"
            footerText: qsTrId("continue")

            StackView.onActivated: {
                btnBack.visible = root.showBackBtn
            }

            AccountSelector {
                id: selectFromAccount
                accounts: walletModel.accountsView.accounts
                selectedAccount: {
                    const currAcc = walletModel.accountsView.currentAccount
                    if (currAcc.walletType !== Constants.watchWalletType) {
                        return currAcc
                    }
                    return null
                }
                currency: walletModel.balanceView.defaultCurrency
                width: stack.width
                //% "Choose account"
                label: qsTrId("choose-account")
                showBalanceForAssetSymbol: root.asset.symbol
                minRequiredAssetBalance: root.packPrice
                onSelectedAccountChanged: if (isValid) { gasSelector.estimateGas() }
            }
            RecipientSelector {
                id: selectRecipient
                visible: false
                accounts: walletModel.accountsView.accounts
                contacts: profileModel.contacts.addedContacts
                selectedRecipient: { "address": utilsModel.stickerMarketAddress, "type": RecipientSelector.Type.Address }
                readOnly: true
                onSelectedRecipientChanged: if (isValid) { gasSelector.estimateGas() }
            }
            GasSelector {
                id: gasSelector
                visible: false
                slowestGasPrice: parseFloat(walletModel.gasView.safeLowGasPrice)
                fastestGasPrice: parseFloat(walletModel.gasView.fastestGasPrice)
                getGasEthValue: walletModel.gasView.getGasEthValue
                getFiatValue: walletModel.balanceView.getFiatValue
                defaultCurrency: walletModel.balanceView.defaultCurrency
                maxPriorityFeePerGas: walletModel.gasView.maxPriorityFeePerGas
                
                property var estimateGas: Backpressure.debounce(gasSelector, 600, function() {
                    if (!(root.stickerPackId > -1 && selectFromAccount.selectedAccount && root.packPrice && parseFloat(root.packPrice) > 0)) {
                        selectedGasLimit = 325000
                        return
                    }
                    chatsModel.stickers.estimate(root.stickerPackId, selectFromAccount.selectedAccount.address, root.packPrice, uuid)
                })
            }
            Connections {
                target: chatsModel.stickers
                onGasEstimateReturned: {
                    if (uuid === gasSelector.uuid) {
                        gasSelector.selectedGasLimit = estimate
                    }
                }
            }
            GasValidator {
                id: gasValidator
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                selectedAccount: selectFromAccount.selectedAccount
                selectedAsset: root.asset
                selectedAmount: parseFloat(packPrice)
                selectedGasEthValue: gasSelector.selectedGasEthValue
            }
        }
        TransactionFormGroup {
            id: group3
            //% "Authorize %1 %2"
            headerText: qsTrId("authorize--1--2").arg(Utils.stripTrailingZeros(root.packPrice)).arg(root.asset.symbol)
            //% "Sign with password"
            footerText: qsTrId("sign-with-password")

            StackView.onActivated: {
                btnBack.visible = true
            }

            TransactionPreview {
                id: pvwTransaction
                width: stack.width
                fromAccount: selectFromAccount.selectedAccount
                gas: {
                    "value": gasSelector.selectedGasEthValue,
                    "symbol": "ETH",
                    "fiatValue": gasSelector.selectedGasFiatValue
                }
                toAccount: selectRecipient.selectedRecipient
                asset: root.asset
                currency: walletModel.balanceView.defaultCurrency
                amount: {
                    const fiatValue = walletModel.balanceView.getFiatValue(root.packPrice || 0, root.asset.symbol, currency)
                    return { "value": root.packPrice, "fiatValue": fiatValue }
                }
            }
        }
        TransactionFormGroup {
            id: group4
            //% "Send %1 %2"
            headerText: qsTrId("send--1--2").arg(Utils.stripTrailingZeros(root.packPrice)).arg(root.asset.symbol)
            //% "Sign with password"
            footerText: qsTrId("sign-with-password")

            TransactionSigner {
                id: transactionSigner
                width: stack.width
                signingPhrase: walletModel.utilsView.signingPhrase
            }
        }
    }

    footer: Item {
        width: parent.width
        height: btnNext.height

        StatusRoundButton {
            id: btnBack
            anchors.left: parent.left
            icon.name: "arrow-right"
            icon.width: 20
            icon.height: 16
            rotation: 180
            onClicked: {
                if (stack.isFirstGroup) {
                    return root.close()
                }
                stack.back()
            }
        }
        StatusButton {
            id: btnNext
            anchors.right: parent.right
            //% "Next"
            text: qsTrId("next")
            enabled: stack.currentGroup.isValid && !stack.currentGroup.isPending
            state: stack.currentGroup.isPending ? "pending" : "default"
            onClicked: {
                const isValid = stack.currentGroup.validate()

                if (stack.currentGroup.validate()) {
                    if (stack.isLastGroup) {
                        return root.sendTransaction()
                    }
                    stack.next()
                }
            }
        }

        Connections {
            target: chatsModel.stickers
            onTransactionWasSent: {
                //% "Transaction pending..."
                toastMessage.title = qsTrId("ens-transaction-pending")
                toastMessage.source = "../../../img/loading.svg"
                toastMessage.iconColor = Style.current.primary
                toastMessage.iconRotates = true
                toastMessage.link = `${walletModel.utilsView.etherscanLink}/${txResult}`
                toastMessage.open()
            }
            onTransactionCompleted: {
                toastMessage.title = !success ? 
                                     //% "Could not buy Stickerpack"
                                     qsTrId("could-not-buy-stickerpack")
                                     :
                                     //% "Stickerpack bought successfully"
                                     qsTrId("stickerpack-bought-successfully");
                if (success) {
                    toastMessage.source = "../../../img/check-circle.svg"
                    toastMessage.iconColor = Style.current.success
                } else {
                    toastMessage.source = "../../../img/block-icon.svg"
                    toastMessage.iconColor = Style.current.danger
                }

                toastMessage.link = `${walletModel.utilsView.etherscanLink}/${txHash}`
                toastMessage.open()
            }
        }
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/

