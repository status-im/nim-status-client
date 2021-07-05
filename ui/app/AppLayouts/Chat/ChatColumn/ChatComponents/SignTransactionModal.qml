import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtQuick.Dialogs 1.3
import "../../../../../imports"
import "../../../../../shared"
import "../../../../../shared/status"

ModalPopup {
    property var selectedAccount
    property var selectedRecipient
    property var selectedAsset
    property var selectedAmount
    property var selectedFiatAmount
    property bool outgoing: true

    property string trxData: ""

    property alias transactionSigner: transactionSigner

    property var sendTransaction: function(selectedGasLimit, selectedGasPrice, enteredPassword) {
        let success = false
        if(root.selectedAsset.address == Constants.zeroAddress){
            success = walletModel.transactionsView.transferEth(
                                                selectFromAccount.selectedAccount.address,
                                                 selectRecipient.selectedRecipient.address,
                                                 root.selectedAmount,
                                                 selectedGasLimit,
                                                 selectedGasPrice,
                                                 enteredPassword,
                                                 stack.uuid)
        } else {
            success = walletModel.transactionsView.transferTokens(
                                                 selectFromAccount.selectedAccount.address,
                                                 selectRecipient.selectedRecipient.address,
                                                 root.selectedAsset.address,
                                                 root.selectedAmount,
                                                 selectedGasLimit,
                                                 selectedGasPrice,
                                                 enteredPassword,
                                                 stack.uuid)
        }

        if(!success){
            sendingError.text = qsTr("Invalid transaction parameters")
            sendingError.open()
        }


        root.close()
    }

    id: root

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
        stack.pop(groupPreview, StackView.Immediate)
    }

    TransactionStackView {
        id: stack
        anchors.fill: parent
        anchors.leftMargin: Style.current.padding
        anchors.rightMargin: Style.current.padding
        initialItem: groupPreview
        isLastGroup: stack.currentGroup === groupSignTx
        onGroupActivated: {
            root.title = group.headerText
            btnNext.text = group.footerText
        }
        TransactionFormGroup {
            id: groupSelectAcct
            headerText: {
                if(trxData.startsWith("0x095ea7b3")){
                    const approveData = JSON.parse(walletModel.tokensView.decodeTokenApproval(selectedRecipient.address, trxData))
                    if(approveData.symbol)
                        //% "Authorize %1 %2"
                        return qsTrId("authorize--1--2").arg(approveData.amount).arg(approveData.symbol)    
                }
                return qsTrId("command-button-send");
            }
            //% "Continue"
            footerText: qsTrId("continue")
            showNextBtn: false
            onBackClicked: function() {
                if(validate()) {
                    stack.pop()
                }
            }
            AccountSelector {
                id: selectFromAccount
                accounts: walletModel.accountsView.accounts
                currency: walletModel.balanceView.defaultCurrency
                width: stack.width
                selectedAccount: root.selectedAccount
                //% "Choose account"
                label: qsTrId("choose-account")
                showBalanceForAssetSymbol: root.selectedAsset.symbol
                minRequiredAssetBalance: parseFloat(root.selectedAmount)
                onSelectedAccountChanged: if (isValid) { gasSelector.estimateGas() }
            }
            RecipientSelector {
                id: selectRecipient
                visible: false
                accounts: walletModel.accountsView.accounts
                contacts: profileModel.contacts.addedContacts
                selectedRecipient: root.selectedRecipient
                readOnly: true
            }
        }
        TransactionFormGroup {
            id: groupSelectGas
            //% "Network fee"
            headerText: qsTrId("network-fee")
            //% "Preview"
            footerText: qsTrId("preview")
            showNextBtn: false
            onBackClicked: function() {
                stack.pop()
            }
            GasSelector {
                id: gasSelector
                anchors.topMargin: Style.current.bigPadding
                slowestGasPrice: parseFloat(walletModel.gasView.safeLowGasPrice)
                fastestGasPrice: parseFloat(walletModel.gasView.fastestGasPrice)
                getGasEthValue: walletModel.gasView.getGasEthValue
                getFiatValue: walletModel.balanceView.getFiatValue
                defaultCurrency: walletModel.balanceView.defaultCurrency
                maxPriorityFeePerGas: walletModel.gasView.maxPriorityFeePerGas
                width: stack.width
    
                property var estimateGas: Backpressure.debounce(gasSelector, 600, function() {
                    if (!(selectFromAccount.selectedAccount && selectFromAccount.selectedAccount.address &&
                        selectRecipient.selectedRecipient && selectRecipient.selectedRecipient.address &&
                        root.selectedAsset && root.selectedAsset.address &&
                        root.selectedAmount)) {
                        selectedGasLimit = 250000
                        return
                    }
                    
                    let gasEstimate = JSON.parse(walletModel.gasView.estimateGas(
                        selectFromAccount.selectedAccount.address,
                        selectRecipient.selectedRecipient.address,
                        root.selectedAsset.address,
                        root.selectedAmount,
                        trxData))

                    if (!gasEstimate.success) {
                        //% "Error estimating gas: %1"
                        let message = qsTrId("error-estimating-gas---1").arg(gasEstimate.error.message)
                        console.warn(message)
                        //% ". The transaction will probably fail."
                        gasEstimateErrorPopup.confirmationText = message + qsTrId("--the-transaction-will-probably-fail-")
                        gasEstimateErrorPopup.open()
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
                selectedAmount: parseFloat(root.selectedAmount)
                selectedAsset: root.selectedAsset
                selectedGasEthValue: gasSelector.selectedGasEthValue
            }
        }
        
        TransactionFormGroup {
            id: groupPreview
            //% "Transaction preview"
            headerText: qsTrId("transaction-preview")
            //% "Sign with password"
            footerText: qsTrId("sign-with-password")
            showBackBtn: false
            onNextClicked: function() {
                stack.push(groupSignTx, StackView.Immediate)
            }
            isValid: groupSelectAcct.isValid && groupSelectGas.isValid && pvwTransaction.isValid

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
                asset: root.selectedAsset
                amount: { "value": root.selectedAmount, "fiatValue": root.selectedFiatAmount }
                currency: walletModel.balanceView.defaultCurrency
                isFromEditable: false
                trxData: root.trxData
                isGasEditable: true
                fromValid: balanceValidator.isValid
                gasValid: gasValidator.isValid
                onFromClicked: { stack.push(groupSelectAcct, StackView.Immediate) }
                onGasClicked: { stack.push(groupSelectGas, StackView.Immediate) }
            }
            BalanceValidator {
                id: balanceValidator
                anchors.top: pvwTransaction.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                account: selectFromAccount.selectedAccount
                amount: !!root.selectedAmount ? parseFloat(root.selectedAmount) : 0.0
                asset: root.selectedAsset
            }
            GasValidator {
                id: gasValidator2
                anchors.top: balanceValidator.visible ? balanceValidator.bottom : pvwTransaction.bottom
                anchors.topMargin: balanceValidator.visible ? 5 : 0
                anchors.horizontalCenter: parent.horizontalCenter
                selectedAccount: selectFromAccount.selectedAccount
                selectedAmount: parseFloat(root.selectedAmount)
                selectedAsset: root.selectedAsset
                selectedGasEthValue: gasSelector.selectedGasEthValue
            }
        }
        TransactionFormGroup {
            id: groupSignTx
            //% "Sign with password"
            headerText: qsTrId("sign-with-password")
            //% "Send %1 %2"
            footerText: qsTrId("send--1--2").arg(root.selectedAmount).arg(!!root.selectedAsset ? root.selectedAsset.symbol : "")
            onBackClicked: function() {
                stack.pop()
            }

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
            visible: stack.currentGroup.showBackBtn
            enabled: stack.currentGroup.isValid || stack.isLastGroup
            onClicked: {
                if (typeof stack.currentGroup.onBackClicked === "function") {
                    return stack.currentGroup.onBackClicked()
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
            visible: stack.currentGroup.showNextBtn
            onClicked: {
                const validity = stack.currentGroup.validate()
                if (validity.isValid && !validity.isPending) {
                    if (stack.isLastGroup) {
                        return root.sendTransaction(gasSelector.selectedGasLimit,
                                                    gasSelector.selectedGasPrice,
                                                    transactionSigner.enteredPassword)
                    }

                    if(gasSelector.eip1599Enabled){
                        console.log("EIP1559 enabled")
                        if(gasSelector.showPriceLimitWarning || gasSelector.showTipLimitWarning){
                            console.log("SHOW POPUP")
                            // return
                        }
                    }


                    if (typeof stack.currentGroup.onNextClicked === "function") {
                        return stack.currentGroup.onNextClicked()
                    }
                    stack.next()
                }
            }
        }

        Connections {
            target: walletModel.transactionsView
            onTransactionWasSent: {
                try {
                    let response = JSON.parse(txResult)

                    if (response.uuid !== stack.uuid) return
                    
                    stack.currentGroup.isPending = false

                    if (!response.success) {
                        if (Utils.isInvalidPasswordMessage(response.result)){
                            //% "Wrong password"
                            transactionSigner.validationError = qsTrId("wrong-password")
                            return
                        }
                        sendingError.text = response.result
                        return sendingError.open()
                    }

                    //% "Transaction pending..."
                    toastMessage.title = qsTrId("ens-transaction-pending")
                    toastMessage.source = "../../../../img/loading.svg"
                    toastMessage.iconColor = Style.current.primary
                    toastMessage.iconRotates = true
                    toastMessage.link = `${walletModel.utilsView.etherscanLink}/${response.result}`
                    toastMessage.open()
                    root.close()
                } catch (e) {
                    console.error('Error parsing the response', e)
                }
            }
        }
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/

