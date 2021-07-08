import QtQuick 2.14
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.14
import QtQml.StateMachine 1.14 as DSM
import "../../../../imports"
import "../../../../shared"
import "./Ens"

Item {
    id: ensContainer
    Layout.fillHeight: true
    Layout.fillWidth: true
    clip: true

    property bool showSearchScreen: false
    property string addedUsername: ""
    property string selectedUsername: ""

    signal next(output: string)
    signal back()
    signal done(ensUsername: string)
    signal connect(ensUsername: string)
    signal changePubKey(ensUsername: string)


    signal goToWelcome();
    signal goToList();

    function goToStart(){                  /* Comment this to use on testnet      */
        if(profileModel.ens.rowCount() > 0 && profileModel.network.current === "mainnet_rpc"){
            goToList();
        } else {
            goToWelcome();
        }
    }

    DSM.StateMachine {
        id: stateMachine
        initialState: welcomeState
        running: true

        DSM.State {
            id: welcomeState
            onEntered: loader.sourceComponent = welcome
            DSM.SignalTransition {
                targetState: searchState
                signal: next
            }
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
        }

        DSM.State {
            id: searchState
            onEntered: loader.sourceComponent = search
            DSM.SignalTransition {
                targetState: tAndCState
                signal: next
                guard: output === "available"
            }
            DSM.SignalTransition {
                targetState: addedState
                signal: connect
            }
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
            DSM.SignalTransition {
                targetState: welcomeState
                signal: goToWelcome
            }
            DSM.SignalTransition {
                targetState: ensConnectedState
                signal: done
            }
        }

        DSM.State {
            id: addedState
            onEntered: {
                loader.sourceComponent = added;
                loader.item.ensUsername = addedUsername;
            }
            DSM.SignalTransition {
                targetState: listState
                signal: next
            }
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
            DSM.SignalTransition {
                targetState: welcomeState
                signal: goToWelcome
            }
        }

        DSM.State {
            id: listState
            onEntered: {
                loader.sourceComponent = list;
            }
            DSM.SignalTransition {
                targetState: searchState
                signal: next
                guard: output === "search"
            }
            DSM.SignalTransition {
                targetState: detailsState
                signal: next
                guard: output === "details"
            }
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
            DSM.SignalTransition {
                targetState: welcomeState
                signal: goToWelcome
            }
        }

        DSM.State {
            id: detailsState
            onEntered: {
                loader.sourceComponent = details;
            }
            DSM.SignalTransition {
                targetState: listState
                signal: back
            }
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
            DSM.SignalTransition {
                targetState: welcomeState
                signal: goToWelcome
            }
        }

        DSM.State {
            id: tAndCState
            onEntered:loader.sourceComponent = termsAndConditions
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
            DSM.SignalTransition {
                targetState: welcomeState
                signal: goToWelcome
            }
            DSM.SignalTransition {
                targetState: listState
                signal: back
            }
            DSM.SignalTransition {
                targetState: listState
                signal: back
            }
            DSM.SignalTransition {
                targetState: ensRegisteredState
                signal: done
            }
        }

        DSM.State {
            id: ensRegisteredState
            onEntered:loader.sourceComponent = ensRegistered
            DSM.SignalTransition {
                targetState: listState
                signal: next
            }
        }

        DSM.State {
            id: ensConnectedState
            onEntered:loader.sourceComponent = ensConnected
            DSM.SignalTransition {
                targetState: listState
                signal: next
            }
        }       
    }

    Loader {
        id: loader
        anchors.fill: parent
    }

    Component {
        id: welcome
        Welcome {
            onStartBtnClicked: next(null)
        }
    }

    Component {
        id: search
        Search {
            onContinueClicked: {
                if(output === "connected"){
                    connect(username)
                } else {
                    selectedUsername = username;
                    next(output);
                }
            }
            onUsernameUpdated: {
                selectedUsername = username;
                done(username);
            }
        }
    }

    Component {
        id: termsAndConditions
        TermsAndConditions {
            username: selectedUsername
            onBackBtnClicked: back();
            onUsernameRegistered: done(userName);
        }
    }

    Component {
        id: added
        Added {
            onOkBtnClicked: next(null)
        }
    }

    Component {
        id: ensRegistered
        ENSRegistered {
            ensUsername: selectedUsername
            onOkBtnClicked: next(null)
        }
    }

    Component {
        id: ensConnected
        ENSConnected {
            ensUsername: selectedUsername
            onOkBtnClicked: next(null)
        }
    }

    Component {
        id: list
        List {
            onAddBtnClicked: next("search")
            onSelectEns: {
                profileModel.ens.details(username)
                selectedUsername = username;
                next("details")
            }
        }
    }

    Component {
        id: details
        ENSDetails {
            username: selectedUsername
            onBackBtnClicked: back();
        }
    }

    Connections {
        target: ensContainer
        function onConnect(ensUsername) {
            addedUsername = ensUsername;
        }
    }

    Connections {
        target: profileModel.ens
        function onTransactionWasSent(txResult) {
            //% "Transaction pending..."
            toastMessage.title = qsTrId("ens-transaction-pending")
            toastMessage.source = "../../../img/loading.svg"
            toastMessage.iconColor = Style.current.primary
            toastMessage.iconRotates = true
            toastMessage.link = `${walletModel.utilsView.etherscanLink}/${txResult}`
            toastMessage.open()
        }
        function onTransactionCompleted(success, txHash, username, trxType, revertReason) {
            switch(trxType){
                case "RegisterENS":
                    toastMessage.title = !success ? 
                                         //% "ENS Registration failed"
                                         qsTrId("ens-registration-failed")
                                         :
                                         //% "ENS Registration completed"
                                         qsTrId("ens-registration-completed");
                    break;
                case "SetPubKey":
                    toastMessage.title = !success ? 
                                         //% "Updating ENS pubkey failed"
                                         qsTrId("updating-ens-pubkey-failed")
                                         :
                                         //% "Updating ENS pubkey completed"
                                         qsTrId("updating-ens-pubkey-completed");
                    break;
            }

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
