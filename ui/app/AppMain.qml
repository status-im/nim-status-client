import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import QtMultimedia 5.13
import "../imports"
import "../sounds"
import "../shared"
import "../shared/status"
import "./AppLayouts"
import "./AppLayouts/Timeline"
import "./AppLayouts/Wallet"
import "./AppLayouts/Chat/components"
import Qt.labs.settings 1.0

RowLayout {
    id: appMain
    spacing: 0
    Layout.fillHeight: true
    Layout.fillWidth: true

    property alias appSettings: appSettings


    function getProfileImage(pubkey, isCurrentUser, useLargeImage) {
        if (isCurrentUser || (isCurrentUser === undefined && pubkey === profileModel.profile.pubKey)) {
            return profileModel.profile.thumbnailImage
        }

        const index = profileModel.contacts.list.getContactIndexByPubkey(pubkey)
        if (index === -1) {
            return
        }

        if (appSettings.onlyShowContactsProfilePics) {
            const isContact = profileModel.contacts.list.rowData(index, "isContact")
            if (isContact === "false") {
                return
            }
        }

        return profileModel.contacts.list.rowData(index, useLargeImage ? "largeImage" : "thumbnailImage")
    }

    function openPopup(popupComponent, params = {}) {
        const popup = popupComponent.createObject(appMain, params);
        popup.open()
        return popup
    }

    function getUserNickname(pubKey) {
        // Get contact nickname
        const contactList = profileModel.contacts.list
        const contactCount = contactList.rowCount()
        for (let i = 0; i < contactCount; i++) {
            if (contactList.rowData(i, 'pubKey') === pubKey) {
                return contactList.rowData(i, 'localNickname')
            }
        }
        return ""
    }


    function openLink(link) {
        if (appSettings.showBrowserSelector) {
            appMain.openPopup(chooseBrowserPopupComponent, {link: link})
        } else {
            if (appSettings.openLinksInStatus) {
                appMain.changeAppSection(Constants.browser)
                browserLayoutContainer.item.openUrlInNewTab(link)
            } else {
                Qt.openUrlExternally(link)
            }
        }
    }

    signal settingsLoaded()

    Settings {
        id: appSettings
        fileName: profileModel.profileSettingsFile
        property var chatSplitView
        property var walletSplitView
        property var profileSplitView
        property bool communitiesEnabled: false
        property bool walletEnabled: false
        property bool nodeManagementEnabled: false
        property bool browserEnabled: false
        property bool displayChatImages: false
        property bool useCompactMode: false
        property bool timelineEnabled: true
        property string locale: "en"
        property var recentEmojis: []
        property real volume: 0.2
        property int notificationSetting: Constants.notifyAllMessages
        property bool notificationSoundsEnabled: true
        property bool useOSNotifications: true
        property int notificationMessagePreviewSetting: Constants.notificationPreviewNameAndMessage
        property bool allowNotificationsFromNonContacts: false
        property var whitelistedUnfurlingSites: ({})
        property bool neverAskAboutUnfurlingAgain: false
        property bool hideChannelSuggestions: false
        property int fontSize: Constants.fontSizeM
        property bool hideSignPhraseModal: false
        property bool onlyShowContactsProfilePics: true
        property bool quitOnClose: true

        // Browser settings
        property bool showBrowserSelector: true
        property bool openLinksInStatus: true
        property bool showFavoritesBar: false
        property string browserHomepage: ""
        property int browserSearchEngine: Constants.browserSearchEngineNone
        property int browserEthereumExplorer: Constants.browserEthereumExplorerNone
        property bool autoLoadImages: true
        property bool javaScriptEnabled: true
        property bool errorPageEnabled: true
        property bool pluginsEnabled: true
        property bool autoLoadIconsForPage: true
        property bool touchIconsEnabled: true
        property bool webRTCPublicInterfacesOnly: false
        property bool devToolsEnabled: false
        property bool pdfViewerEnabled: true
        property bool compatibilityMode: true
    }
    

    ErrorSound {
        id: errorSound
    }

    Audio {
        id: sendMessageSound
        audioRole: Audio.NotificationRole
        source: "../../../../sounds/send_message.wav"
        volume: appSettings.volume
        muted: !appSettings.notificationSoundsEnabled
    }

    Audio {
        id: notificationSound
        audioRole: Audio.NotificationRole
        source: "../../../../sounds/notification.wav"
        volume: appSettings.volume
        muted: !appSettings.notificationSoundsEnabled
    }


    Connections {
        target: profileModel
        onProfileSettingsFileChanged: {
            if (appSettings.locale !== "en") {
                profileModel.changeLocale(appSettings.locale)
            }
            const whitelist = profileModel.getLinkPreviewWhitelist()
            try {
                const whiteListedSites = JSON.parse(whitelist)
                let settingsUpdated = false
                const settings = appSettings.whitelistedUnfurlingSites
                const whitelistedHostnames = []

                // Add whitelisted sites in to app settings that are not already there
                whiteListedSites.forEach(site => {
                    if (!settings.hasOwnProperty(site.address))  {
                        settings[site.address] = false
                        settingsUpdated = true
                    }
                    whitelistedHostnames.push(site.address)
                })
                // Remove any whitelisted sites from app settings that don't exist in the
                // whitelist from status-go
                Object.keys(settings).forEach(settingsHostname => {
                    if (!whitelistedHostnames.includes(settingsHostname)) {
                        delete settings[settingsHostname]
                        settingsUpdated = true
                    }
                })
                if (settingsUpdated) {
                    appSettings.whitelistedUnfurlingSites = settings
                }
            } catch (e) {
                console.error('Could not parse the whitelist for sites', e)
            }
            appMain.settingsLoaded()
        }
    }
    Connections {
        target: profileModel
        ignoreUnknownSignals: true
        enabled: removeMnemonicAfterLogin
        onInitialized: {
            profileModel.mnemonic.remove()
        }
    }

    Component {
        id: chooseBrowserPopupComponent
        ChooseBrowserPopup {
            onClosed: {
                destroy()
            }
        }
    }

    ToastMessage {
        id: toastMessage
    }

    // Add SenmdModal here as it is used by the Wallet as well as the Browser
    Loader {
        id: sendModal

        function open() {
            this.active = true
            this.item.open()
        }
        function closed() {
            // this.sourceComponent = undefined // kill an opened instance
            this.active = false
        }
        sourceComponent: SendModal {
            onOpened: {
                walletModel.getGasPricePredictions()
            }
            onClosed: {
                sendModal.closed()
            }
        }
    }

    Action {
        shortcut: "Ctrl+1"
        onTriggered: changeAppSection(Constants.chat)
    }
    Action {
        shortcut: "Ctrl+2"
        onTriggered: changeAppSection(Constants.browser)
    }
    Action {
        shortcut: "Ctrl+3"
        onTriggered: changeAppSection(Constants.wallet)
    }
    Action {
        shortcut: "Ctrl+4, Ctrl+,"
        onTriggered: changeAppSection(Constants.profile)
    }
    Action {
        shortcut: "Ctrl+K"
        onTriggered: {
            if (channelPicker.opened) {
                channelPicker.close()
            } else {
                channelPicker.open()
            }
        }
    }
    Component {
        id: statusIdenticonComponent
        StatusIdenticon {}
    }

    StatusInputListPopup {
        id: channelPicker
        //% "Where do you want to go?"
        title: qsTrId("where-do-you-want-to-go-")
        showSearchBox: true
        width: 350
        x: parent.width / 2 - width / 2
        y: parent.height / 2 - height / 2
        modelList: chatsModel.chats
        getText: function (modelData) {
            return modelData.name
        }
        getImageComponent: function (parent, modelData) {
            return statusIdenticonComponent.createObject(parent, {
                                                             width: channelPicker.imageWidth,
                                                             height: channelPicker.imageHeight,
                                                             chatName: modelData.name,
                                                             chatType: modelData.chatType,
                                                             identicon: modelData.identicon
                                                         });
        }
        onClicked: function (index) {
            chatsModel.setActiveChannelByIndex(index)
            appMain.changeAppSection(Constants.chat)
            channelPicker.close()
        }
    }

    function changeAppSection(section) {
        let sectionId = -1
        switch (section) {
        case Constants.chat: sectionId = 0; break;
        case Constants.wallet: sectionId = 1; break;
        case Constants.browser: sectionId = 2; break;
        case Constants.profile: sectionId = 4; break;
        case Constants.node: sectionId = 5; break;
        case Constants.ui: sectionId = 6; break;
        }
        if (sectionId === -1) {
            throw new Exception ("Unknown section name. Check the Constants to know the available ones")
        }
        tabBar.setCurrentIndex(sectionId)
    }

    TabBar {
        id: tabBar
        width: 78
        Layout.maximumWidth: 80
        Layout.preferredWidth: 80
        Layout.minimumWidth: 80
        currentIndex: 0
        topPadding: 57
        rightPadding: 19
        leftPadding: 19
        transformOrigin: Item.Top
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        Layout.fillHeight: true
        spacing: 5
        background: Rectangle {
            color: "#00000000"
            border.color: Style.current.border
        }

        StatusIconTabButton {
              id: chatBtn
              anchors.horizontalCenter: parent.horizontalCenter
              icon.name: "message"
              anchors.topMargin: 0

              Rectangle {
                  id: chatBadge
                  visible: chatsModel.unreadMessagesCount > 0
                  anchors.top: parent.top
                  anchors.left: parent.right
                  anchors.leftMargin: -17
                  anchors.topMargin: 1
                  radius: height / 2
                  color: Style.current.blue
                  border.color: chatBtn.hovered ? Style.current.secondaryBackground : Style.current.background
                  border.width: 2
                  width: chatsModel.unreadMessagesCount < 10 ? 22 : messageCount.width + 14
                  height: 22
                  Text {
                      id: messageCount
                      font.pixelSize: chatsModel.unreadMessagesCount > 99 ? 10 : 12
                      color: Style.current.white
                      anchors.centerIn: parent
                      text: chatsModel.unreadMessagesCount > 99 ? "99+" : chatsModel.unreadMessagesCount
                  }
              }
        }

        StatusIconTabButton {
              id: walletBtn
              anchors.top: chatBtn.top
              enabled: isExperimental === "1" || appSettings.walletEnabled
              icon.name: "wallet"
        }

        StatusIconTabButton {
              id: browserBtn
              anchors.top: walletBtn.top
              enabled: isExperimental === "1" || appSettings.browserEnabled
              icon.name: "compass"
        }

        StatusIconTabButton {
              id: timelineBtn
              anchors.top: browserBtn.enabled ? browserBtn.top : walletBtn.top
              enabled: isExperimental === "1" || appSettings.timelineEnabled
              icon.name: "timeline"
        }

        StatusIconTabButton {
              id: profileBtn
              anchors.top: timelineBtn.enabled ? timelineBtn.top : browserBtn.top
              icon.name: "profile"

              Rectangle {
                id: profileBadge
                visible: !profileModel.mnemonic.isBackedUp && sLayout.children[sLayout.currentIndex] !== profileLayoutContainer
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.topMargin: 5
                radius: height / 2
                color: Style.current.blue
                border.color: profileBtn.hovered ? Style.current.secondaryBackground : Style.current.background
                border.width: 2
                width: 14
                height: 14
            }
        }

        StatusIconTabButton {
              id: nodeBtn
              enabled: isExperimental === "1" && appSettings.nodeManagementEnabled
              anchors.top: profileBtn.top
              icon.name: "node"
        }

        StatusIconTabButton {
              id: uiComponentBtn
              enabled: isExperimental === "1"
              anchors.top: nodeBtn.top
              icon.name: "node"
        }
    }

    StackLayout {
        id: sLayout
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        Layout.fillHeight: true
        currentIndex: tabBar.currentIndex
        onCurrentIndexChanged: {
            if (typeof this.children[currentIndex].onActivated === "function") {
                this.children[currentIndex].onActivated()
            }

            if(this.children[currentIndex] === browserLayoutContainer && browserLayoutContainer.active == false){
                browserLayoutContainer.active = true;
            }

            timelineLayoutContainer.active = this.children[currentIndex] == timelineLayoutContainer

            if(this.children[currentIndex] === chatLayoutContainer){
                chatLayoutContainer.chatColumn.chatMessages.chatLogView.scrollToBottom(true);
            }

            if(this.children[currentIndex] === walletLayoutContainer){
                walletLayoutContainer.showSigningPhrasePopup();
            }
        }

        ChatLayout {
            id: chatLayoutContainer
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.fillHeight: true
        }

        WalletLayout {
            id: walletLayoutContainer
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.fillHeight: true
        }

        Component {
            id: browserLayoutComponent
            BrowserLayout { }
        }

        Loader {
            id: browserLayoutContainer
            sourceComponent: browserLayoutComponent
            active: false
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.fillHeight: true
            // Loaders do not have access to the context, so props need to be set
            // Adding a "_" to avoid a binding loop
            property var _chatsModel: chatsModel
            property var _walletModel: walletModel
            property var _utilsModel: utilsModel
            property var _web3Provider: web3Provider
        }

        Loader {
            id: timelineLayoutContainer
            sourceComponent: Component {
                TimelineLayout {}
            }
            onLoaded: timelineLayoutContainer.item.onActivated()
            active: false
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.fillHeight: true
        }

        ProfileLayout {
            id: profileLayoutContainer
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.fillHeight: true
        }

        NodeLayout {
            id: nodeLayoutContainer
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.fillHeight: true
        }

        UIComponents {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.fillHeight: true
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorZoom:0.33000001311302185;height:770;width:1232}
}
##^##*/
