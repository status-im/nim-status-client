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
import "./AppLayouts/Chat/CommunityComponents"
import Qt.labs.settings 1.0

RowLayout {
    id: appMain
    property int currentView: sLayout.currentIndex
    property bool popupOpened: false
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

    function getContactListObject(dataModel) {
        const nbContacts = profileModel.contacts.list.rowCount()
        const contacts = []
        let contact
        for (let i = 0; i < nbContacts; i++) {
            contact = {
                name: profileModel.contacts.list.rowData(i, "name"),
                localNickname: profileModel.contacts.list.rowData(i, "localNickname"),
                pubKey: profileModel.contacts.list.rowData(i, "pubKey"),
                address: profileModel.contacts.list.rowData(i, "address"),
                identicon: profileModel.contacts.list.rowData(i, "identicon"),
                thumbnailImage: profileModel.contacts.list.rowData(i, "thumbnailImage"),
                isUser: false,
                isContact: profileModel.contacts.list.rowData(i, "isContact") !== "false"
            }

            contacts.push(contact)
            if (dataModel) {
                dataModel.append(contact);
            }
        }
        return contacts
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
        property bool isWalletEnabled: false
        property bool nodeManagementEnabled: false
        property bool isBrowserEnabled: false
        property bool isActivityCenterEnabled: false
        property bool displayChatImages: false
        property bool useCompactMode: true
        property bool timelineEnabled: true
        property var recentEmojis: []
        property var hiddenCommunityWelcomeBanners: []
        property var hiddenCommunityBackUpBanners: []
        property real volume: 0.2
        property int notificationSetting: Constants.notifyAllMessages
        property bool notificationSoundsEnabled: true
        property bool useOSNotifications: true
        property int notificationMessagePreviewSetting: Constants.notificationPreviewNameAndMessage
        property bool notifyOnNewRequests: true
        property var whitelistedUnfurlingSites: ({})
        property bool neverAskAboutUnfurlingAgain: false
        property bool hideChannelSuggestions: false
        property int fontSize: Constants.fontSizeM
        property bool hideSignPhraseModal: false
        property bool onlyShowContactsProfilePics: true
        property bool quitOnClose: false

        // Browser settings
        property bool showBrowserSelector: true
        property bool openLinksInStatus: true
        property bool shouldShowFavoritesBar: true
        property string browserHomepage: ""
        property int shouldShowBrowserSearchEngine: Constants.browserSearchEngineDuckDuckGo
        property int useBrowserEthereumExplorer: Constants.browserEthereumExplorerEtherscan
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
            profileModel.changeLocale(globalSettings.locale)


            // Since https://github.com/status-im/status-desktop/commit/93668ff75
            // we're hiding the setting to change appearance for compact normal mode
            // of the UI. For now, compact mode is the new default.
            //
            // Prior to this change, most likely many users are still using the
            // normal mode configuration, so we have to enforce compact mode for
            // those.
            if (!appSettings.useCompactMode) {
                appSettings.useCompactMode = true
            }

            const whitelist = profileModel.getLinkPreviewWhitelist()
            try {
                const whiteListedSites = JSON.parse(whitelist)
                let settingsUpdated = false

                // Add Status links to whitelist
                whiteListedSites.push({title: "Status", address: Constants.deepLinkPrefix, imageSite: false})
                whiteListedSites.push({title: "Status", address: Constants.joinStatusLink, imageSite: false})

                const settings = appSettings.whitelistedUnfurlingSites

                // Set Status links as true. We intercept thoseURLs so it is privacy-safe
                if (!settings[Constants.deepLinkPrefix] || !settings[Constants.joinStatusLink]) {
                    settings[Constants.deepLinkPrefix] = true
                    settings[Constants.joinStatusLink] = true
                    settingsUpdated = true
                }

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

    Component {
        id: inviteFriendsToCommunityPopup
        InviteFriendsToCommunityPopup {
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: communityMembersPopup
        CommunityMembersPopup {
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: editCommunityPopup
        CreateCommunityPopup {
            isEdit: true
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: editChannelPopup
        CreateChannelPopup {
            isEdit: true
            pinnedMessagesPopupComponent: chatLayoutContainer.chatColumn.pinnedMessagesPopupComponent
            onClosed: {
                destroy()
            }
        }
    }

    ToastMessage {
        id: toastMessage
    }

    // Add SendModal here as it is used by the Wallet as well as the Browser
    Loader {
        id: sendModal
        active: false

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
                walletModel.gasView.getGasPricePredictions()
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
        modelList: chatsModel.channelView.chats
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
            chatsModel.channelView.setActiveChannelByIndex(index)
            appMain.changeAppSection(Constants.chat)
            channelPicker.close()
        }
    }

    function changeAppSection(section) {
        chatsModel.communities.activeCommunity.active = false
        sLayout.currentIndex = Utils.getAppSectionIndex(section)
    }


    Rectangle {
        id: leftTab
        Layout.maximumWidth: 78
        Layout.minimumWidth: 78
        Layout.preferredWidth: 78
        Layout.fillHeight: true
        height: parent.height
        color: Style.current.mainMenuBackground

        ScrollView {
            id: scrollView
            width: leftTab.width
            anchors.top: parent.top
            anchors.topMargin: 50
            anchors.bottom: leftTabButtons.visible ? leftTabButtons.top : parent.bottom
            anchors.bottomMargin: tabBar.spacing
            clip: true

            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                id: tabBar
                spacing: 12
                width: scrollView.width

                Loader {
                    id: communitiesListLoader
                    active: appSettings.communitiesEnabled
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: {
                        if (item && active) {
                            return item.height
                        }

                        return 0
                    }
                    sourceComponent: Component {
                        CommunityList {}
                    }
                }

                StatusIconTabButton {
                    id: chatBtn
                    icon.name: "message"
                    icon.width: 20
                    icon.height: 20
                    section: Constants.chat
                    doNotHandleClick: true
                    onClicked: {
                        if (chatsModel.communities.activeCommunity.active) {
                            chatLayoutContainer.chatColumn.input.hideExtendedArea();
                            chatsModel.communities.activeCommunity.active = false
                        }
                        appMain.changeAppSection(Constants.chat)
                    }

                    checked: !chatsModel.communities.activeCommunity.active  && sLayout.currentIndex === Utils.getAppSectionIndex(Constants.chat)

                    Rectangle {
                        property int badgeCount: chatsModel.messageView.unreadMessagesCount + profileModel.contacts.contactRequests.count

                        id: chatBadge
                        visible: chatBadge.badgeCount > 0
                        anchors.top: parent.top
                        anchors.left: parent.right
                        anchors.leftMargin: -17
                        anchors.topMargin: 1
                        radius: height / 2
                        color: Style.current.blue
                        border.color: chatBtn.hovered ? Style.current.secondaryBackground : Style.current.mainMenuBackground
                        border.width: 2
                        width: chatBadge.badgeCount < 10 ? 22 : messageCount.width + 14
                        height: 22
                        Text {
                            id: messageCount
                            font.pixelSize: chatBadge.badgeCount > 99 ? 10 : 12
                            color: Style.current.white
                            anchors.centerIn: parent
                            text: chatBadge.badgeCount > 99 ? "99+" : chatBadge.badgeCount
                        }
                    }
                }

                Loader {
                    active: !leftTabButtons.visible
                    width: parent.width
                    height: {
                        if (item && active) {
                            return item.height
                        }
                        return 0
                    }
                    sourceComponent: LeftTabBottomButtons {}
                }
            }
        }

        LeftTabBottomButtons {
            id: leftTabButtons
            visible: scrollView.contentHeight > leftTab.height
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.current.padding
        }
    }

    StackLayout {
        id: sLayout
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        Layout.fillHeight: true
        currentIndex: 0
        onCurrentIndexChanged: {
            if (typeof this.children[currentIndex].onActivated === "function") {
                this.children[currentIndex].onActivated()
            }

            if(this.children[currentIndex] === browserLayoutContainer && browserLayoutContainer.active == false){
                browserLayoutContainer.active = true;
            }

            timelineLayoutContainer.active = this.children[currentIndex] === timelineLayoutContainer

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
            property var _chatsModel: chatsModel.messageView
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
    D{i:0;formeditorZoom:1.75;height:770;width:1232}
}
##^##*/
