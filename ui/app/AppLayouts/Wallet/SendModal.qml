import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtQuick.Dialogs 1.3
import "../../../imports"
import "../../../shared"
import "../../../shared/status"
import "./components"

ModalPopup {
    id: root
    property alias selectFromAccount: selectFromAccount
    property alias selectRecipient: selectRecipient
    property alias stack: stack
    signal reset

    //% "Send"
    title: qsTrId("command-button-send")
    height: 504

    property MessageDialog sendingError: MessageDialog {
        id: sendingError
        //% "Error sending the transaction"
        title: qsTrId("error-sending-the-transaction")
        icon: StandardIcon.Critical
        standardButtons: StandardButton.Ok
    }

    onClosed: {
        stack.reset()
        root.reset()
    }

    function sendTransaction() {
        stack.currentGroup.isPending = true
        walletModel.sendTransaction(selectFromAccount.selectedAccount.address,
                                                 selectRecipient.selectedRecipient.address,
                                                 txtAmount.selectedAsset.address,
                                                 txtAmount.selectedAmount,
                                                 gasSelector.selectedGasLimit,
                                                 gasSelector.selectedGasPrice,
                                                 transactionSigner.enteredPassword,
                                                 stack.uuid)
    }

    TransactionStackView {
        id: stack
        anchors.fill: parent
        anchors.leftMargin: Style.current.padding
        anchors.rightMargin: Style.current.padding
        onGroupActivated: {
            root.title = group.headerText
            btnNext.text = group.footerText
        }
        TransactionFormGroup {
            id: group1
            //% "Send"
            headerText: qsTrId("command-button-send")
            //% "Continue"
            footerText: qsTrId("continue")

            AccountSelector {
                id: selectFromAccount
                accounts: walletModel.accounts
                selectedAccount: walletModel.currentAccount
                currency: walletModel.defaultCurrency
                width: stack.width
                //% "From account"
                label: qsTrId("from-account")
                reset: function() {
                    accounts = Qt.binding(function() { return walletModel.accounts })
                    selectedAccount = Qt.binding(function() { return walletModel.currentAccount })
                }
                onSelectedAccountChanged: if (isValid) { gasSelector.estimateGas() }
            }
            SeparatorWithIcon {
                id: separator
                anchors.top: selectFromAccount.bottom
                anchors.topMargin: 19
            }
            RecipientSelector {
                id: selectRecipient
                accounts: walletModel.accounts
                contacts: profileModel.addedContacts
                //% "Recipient"
                label: qsTrId("recipient")
                anchors.top: separator.bottom
                anchors.topMargin: 10
                width: stack.width
                reset: function() {
                    accounts = Qt.binding(function() { return walletModel.accounts })
                    contacts = Qt.binding(function() { return profileModel.addedContacts })
                    selectedRecipient = undefined
                }
                onSelectedRecipientChanged: if (isValid) { gasSelector.estimateGas() }
            }
        }
        TransactionFormGroup {
            id: group2
            //% "Send"
            headerText: qsTrId("command-button-send")
            //% "Preview"
            footerText: qsTrId("preview")

            AssetAndAmountInput {
                id: txtAmount
                selectedAccount: selectFromAccount.selectedAccount
                defaultCurrency: walletModel.defaultCurrency
                getFiatValue: walletModel.getFiatValue
                getCryptoValue: walletModel.getCryptoValue
                width: stack.width
                reset: function() {
                    selectedAccount = Qt.binding(function() { return selectFromAccount.selectedAccount })
                }
                onSelectedAssetChanged: if (isValid) { gasSelector.estimateGas() }
                onSelectedAmountChanged: if (isValid) { gasSelector.estimateGas() }
            }
            GasSelector {
                id: gasSelector
                anchors.top: txtAmount.bottom
                anchors.topMargin: Style.current.bigPadding * 2
                slowestGasPrice: parseFloat(walletModel.safeLowGasPrice)
                fastestGasPrice: parseFloat(walletModel.fastestGasPrice)
                getGasEthValue: walletModel.getGasEthValue
                getFiatValue: walletModel.getFiatValue
                defaultCurrency: walletModel.defaultCurrency
                width: stack.width
                reset: function() {
                    slowestGasPrice = Qt.binding(function(){ return parseFloat(walletModel.safeLowGasPrice) })
                    fastestGasPrice = Qt.binding(function(){ return parseFloat(walletModel.fastestGasPrice) })
                }
                property var estimateGas: Backpressure.debounce(gasSelector, 600, function() {
                    if (!(selectFromAccount.selectedAccount && selectFromAccount.selectedAccount.address &&
                        selectRecipient.selectedRecipient && selectRecipient.selectedRecipient.address &&
                        txtAmount.selectedAsset && txtAmount.selectedAsset.address &&
                        txtAmount.selectedAmount)) return
                    
                    let gasEstimate = JSON.parse(walletModel.estimateGas(
                        selectFromAccount.selectedAccount.address,
                        selectRecipient.selectedRecipient.address,
                        txtAmount.selectedAsset.address,
                        txtAmount.selectedAmount,
                        ""))

                    if (!gasEstimate.success) {
                        //% "Error estimating gas: %1"
                        console.warn(qsTrId("error-estimating-gas---1").arg(gasEstimate.error.message))
                        return
                    }
                    selectedGasLimit = gasEstimate.result
                })
            }
            GasValidator {
                id: gasValidator
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                selectedAccount: selectFromAccount.selectedAccount
                selectedAmount: parseFloat(txtAmount.selectedAmount)
                selectedAsset: txtAmount.selectedAsset
                selectedGasEthValue: gasSelector.selectedGasEthValue
                reset: function() {
                    selectedAccount = Qt.binding(function() { return selectFromAccount.selectedAccount })
                    selectedAmount = Qt.binding(function() { return parseFloat(txtAmount.selectedAmount) })
                    selectedAsset = Qt.binding(function() { return txtAmount.selectedAsset })
                    selectedGasEthValue = Qt.binding(function() { return gasSelector.selectedGasEthValue })
                }
            }
        }
        TransactionFormGroup {
            id: group3
            //% "Transaction preview"
            headerText: qsTrId("transaction-preview")
            //% "Sign with password"
            footerText: qsTrId("sign-with-password")

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
                asset: txtAmount.selectedAsset
                amount: { "value": txtAmount.selectedAmount, "fiatValue": txtAmount.selectedFiatAmount }
                currency: walletModel.defaultCurrency
                reset: function() {
                    fromAccount = Qt.binding(function() { return selectFromAccount.selectedAccount })
                    toAccount = Qt.binding(function() { return selectRecipient.selectedRecipient })
                    asset = Qt.binding(function() { return txtAmount.selectedAsset })
                    amount = Qt.binding(function() { return { "value": txtAmount.selectedAmount, "fiatValue": txtAmount.selectedFiatAmount } })
                    gas = Qt.binding(function() {
                        return {
                            "value": gasSelector.selectedGasEthValue,
                            "symbol": "ETH",
                            "fiatValue": gasSelector.selectedGasFiatValue
                        }
                    })
                }
            }
            SendToContractWarning {
                id: sendToContractWarning
                anchors.top: pvwTransaction.bottom
                selectedRecipient: selectRecipient.selectedRecipient
                reset: function() {
                    selectedRecipient = Qt.binding(function() { return selectRecipient.selectedRecipient })
                }
            }
        }
        TransactionFormGroup {
            id: group4
            //% "Sign with password"
            headerText: qsTrId("sign-with-password")
            //% "Send %1 %2"
            footerText: qsTrId("send--1--2").arg(txtAmount.selectedAmount).arg(!!txtAmount.selectedAsset ? txtAmount.selectedAsset.symbol : "")

            TransactionSigner {
                id: transactionSigner
                width: stack.width
                signingPhrase: walletModel.signingPhrase
                reset: function() {
                    signingPhrase = Qt.binding(function() { return walletModel.signingPhrase })
                }
            }
        }
    }

    footer: Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        StatusRoundButton {
            id: btnBack
            anchors.left: parent.left
            visible: !stack.isFirstGroup
            icon.name: "arrow-right"
            icon.width: 20
            icon.height: 16
            rotation: 180
            onClicked: {
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
                const validity = stack.currentGroup.validate()
                if (validity.isValid && !validity.isPending) {
                    if (stack.isLastGroup) {
                        return root.sendTransaction()
                    }
                    stack.next()
                }
            }
        }

        Connections {
            target: walletModel
            onTransactionWasSent: {
                try {
                    let response = JSON.parse(txResult)

                    if (response.uuid !== stack.uuid) return
                    
                    stack.currentGroup.isPending = false

                    if (!response.success) {
                        if (response.result.includes("could not decrypt key with given password")){
                            //% "Wrong password"
                            transactionSigner.validationError = qsTrId("wrong-password")
                            return
                        }
                        sendingError.text = response.result
                        return sendingError.open()
                    }

                    //% "Transaction pending..."
                    toastMessage.title = qsTrId("ens-transaction-pending")
                    toastMessage.source = "../../img/loading.svg"
                    toastMessage.iconColor = Style.current.primary
                    toastMessage.iconRotates = true
                    toastMessage.link = `${walletModel.etherscanLink}/${response.result}`
                    toastMessage.open()
                    root.close()
                } catch (e) {
                    console.error('Error parsing the response', e)
                }
            }
            onTransactionCompleted: {
                if (success) {
                    //% "Transaction completed"
                    toastMessage.title = qsTrId("transaction-completed")
                    toastMessage.source = "../../img/check-circle.svg"
                    toastMessage.iconColor = Style.current.success
                } else {
                    //% "Transaction failed"
                    toastMessage.title = qsTrId("ens-registration-failed-title")
                    toastMessage.source = "../../img/block-icon.svg"
                    toastMessage.iconColor = Style.current.danger
                }
                toastMessage.link = `${walletModel.etherscanLink}/${txHash}`
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

