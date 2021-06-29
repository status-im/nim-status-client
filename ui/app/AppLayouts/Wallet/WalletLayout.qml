import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../imports"
import "../../../shared"
import "../Profile/Sections"
import "."


ColumnLayout {
    property bool hideSignPhraseModal: false

    SignPhraseModal {
        id: signPhrasePopup
    }
    
    function showSigningPhrasePopup(){
        if(!hideSignPhraseModal && !appSettings.hideSignPhraseModal){
            signPhrasePopup.open();
        }
    }

    Component.onCompleted: {
        if(onboardingModel.firstTimeLogin){
            onboardingModel.firstTimeLogin = false
            walletModel.setInitialRange()
        }
        walletModel.transactionsView.checkRecentHistory()
    }

    Timer {
        id: recentHistoryTimer
        interval: Constants.walletFetchRecentHistoryInterval
        running: true
        repeat: true
        onTriggered: walletModel.transactionsView.checkRecentHistory()
    }

    Component {
        id: backupSeedModalComponent
        BackupSeedModal {
            onClosed: {
                destroy();
            }
        }
    }
    
    ModuleWarning {
        visible: !profileModel.mnemonic.isBackedUp
        color: Style.current.red
              //% "Back up your seed phrase"
        text: qsTrId("back-up-your-seed-phrase")
        btnText: qsTr("Back up") 
        onClick: function() {
            openPopup(backupSeedModalComponent);
        }
    }
    
    SplitView {
        id: walletView
        Layout.fillHeight: true
        Layout.fillWidth: true

        handle: SplitViewHandle {}

        Connections {
            target: appMain
            onSettingsLoaded: {
                // Add recent
                walletView.restoreState(appSettings.walletSplitView)
            }
        }
        Component.onDestruction: appSettings.walletSplitView = this.saveState()

        LeftTab {
            id: leftTab
            SplitView.preferredWidth: Style.current.leftTabPreferredSize
        }
        
        Item {
            id: walletContainer
            anchors.top: parent.top
            anchors.topMargin: 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0
            anchors.right: parent.right
            anchors.rightMargin: 0
            anchors.left: leftTab.right
            anchors.leftMargin: 0

            WalletHeader {
                id: walletHeader
                changeSelectedAccount: leftTab.changeSelectedAccount
            }

            RowLayout {
                id: walletInfoContainer
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 0
                anchors.left: parent.left
                anchors.leftMargin: 0
                anchors.right: parent.right
                anchors.rightMargin: 0
                anchors.top: walletHeader.bottom
                anchors.topMargin: 23

                Item {
                    id: walletInfoContent
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    TabBar {
                        id: walletTabBar
                        anchors.right: parent.right
                        anchors.rightMargin: Style.current.bigPadding
                        anchors.left: parent.left
                        anchors.leftMargin: Style.current.bigPadding
                        anchors.top: parent.top
                        anchors.topMargin: Style.current.padding
                        height: assetBtn.height
                        background: Rectangle {
                            color: Style.current.transparent
                        }

                        StatusTabButton {
                            id: assetBtn
                            //% "Assets"
                            btnText: qsTrId("wallet-assets")
                        }
                        StatusTabButton {
                            id: collectiblesBtn
                            anchors.left: assetBtn.right
                            anchors.leftMargin: 32
                            //% "Collectibles"
                            btnText: qsTrId("wallet-collectibles")
                        }
                        StatusTabButton {
                            id: historyBtn
                            anchors.left: collectiblesBtn.right
                            anchors.leftMargin: 32
                            //% "History"
                            btnText: qsTrId("history")
                        }
                    }

                    StackLayout {
                        id: stackLayout
                        anchors.rightMargin: Style.current.bigPadding
                        anchors.leftMargin: Style.current.bigPadding
                        anchors.top: walletTabBar.bottom
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.topMargin: Style.current.bigPadding
                        currentIndex: walletTabBar.currentIndex

                        AssetsTab {
                            id: assetsTab
                        }
                        CollectiblesTab {
                            id: collectiblesTab
                        }
                        HistoryTab {
                            id: historyTab
                        }
                    }
                }
            }
        }
    }
}


/*##^##
Designer {
    D{i:0;autoSize:true;formeditorColor:"#ffffff";height:770;width:1152}
}
##^##*/
