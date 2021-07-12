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
import Qt.labs.platform 1.1
import Qt.labs.settings 1.0

import StatusQ.Core.Theme 0.1
import StatusQ.Controls 0.1
import StatusQ.Layout 0.1
import StatusQ.Popups 0.1

StatusAppLayout {
    id: appMain
    anchors.fill: parent

    property alias appSettings: appSettings
    signal settingsLoaded()

    function changeAppSection(section) {
        chatsModel.communities.activeCommunity.active = false
        appView.currentIndex = Utils.getAppSectionIndex(section)
    }

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


    appNavBar: StatusAppNavBar {
        height: appMain.height

        navBarChatButton: StatusNavBarTabButton {
            icon.name: "chat"
            checked: !chatsModel.communities.activeCommunity.active  && appView.currentIndex === Utils.getAppSectionIndex(Constants.chat)
            tooltip.text: qsTr("Chat")
            badge.value: chatsModel.messageView.unreadDirectMessagesAndMentionsCount + profileModel.contacts.contactRequests.count
            badge.visible: badge.value > 0 || (chatsModel.messageView.unreadMessagesCount > 0 && !checked)
            badge.anchors.rightMargin: badge.value > 0 ? 0 : 4
            badge.anchors.topMargin: badge.value > 0 ? 4 : 5
            badge.border.color: hovered ? Theme.palette.statusBadge.hoverBorderColor : Theme.palette.statusAppNavBar.backgroundColor
            badge.border.width: 2
            onClicked: {
                if (chatsModel.communities.activeCommunity.active) {
                    chatLayoutContainer.chatColumn.input.hideExtendedArea();
                    chatsModel.communities.activeCommunity.active = false
                }
                appMain.changeAppSection(Constants.chat)
            }
        }

        navBarCommunityTabButtons.model: chatsModel.communities.joinedCommunities
        navBarCommunityTabButtons.delegate: StatusNavBarTabButton {
            onClicked: {
                appMain.changeAppSection(Constants.chat)
                chatsModel.communities.setActiveCommunity(model.id)
            }

            anchors.horizontalCenter: parent.horizontalCenter

            checked: chatsModel.communities.activeCommunity.active && chatsModel.communities.activeCommunity.id === model.id
            name: model.name
            tooltip.text: model.name
            icon.color: model.communityColor
            icon.source: model.thumbnailImage

            badge.visible: !checked && model.unviewedMessagesCount > 0
            badge.border.color: hovered ? Theme.palette.statusBadge.hoverBorderColor : Theme.palette.statusBadge.borderColor
            badge.border.width: 2
            badge.anchors.rightMargin: 4
            badge.anchors.topMargin: 5

            popupMenu: StatusPopupMenu {
                id: communityContextMenu

                openHandler: function () {
                    chatsModel.communities.setObservedCommunity(model.id)
                }

                StatusMenuItem {
                    text: qsTr("Invite People")
                    icon.name: "share-ios"
                    enabled: chatsModel.communities.observedCommunity.canManageUsers
                    onTriggered: openPopup(inviteFriendsToCommunityPopup, { communityId: model.id })
                }

                StatusMenuItem {
                    text: qsTr("View Community")
                    icon.name: "group-chat"
                    onTriggered: openPopup(communityMembersPopup, {community: chatsModel.communities.observedCommunity})
                }

                StatusMenuItem {
                    enabled: false//chatsModel.communities.observedCommunity.admin
                    text: qsTr("Edit Community")
                    icon.name: "edit"
                    onTriggered: openPopup(editCommunityPopup, {community: chatsModel.communities.observedCommunity})
                }

                StatusMenuSeparator {}

                StatusMenuItem {
                    text: qsTr("Leave Community")
                    icon.name: "arrow-right"
                    icon.width: 14
                    iconRotation: 180
                    type: StatusMenuItem.Type.Danger
                    onTriggered: chatsModel.communities.leaveCommunity(model.id)
                }
            }
        }

        navBarTabButtons: [
            StatusNavBarTabButton {
                icon.name: "wallet"
                tooltip.text: qsTr("Wallet")
                visible: enabled
                enabled: isExperimental === "1" || appSettings.isWalletEnabled
                checked: appView.currentIndex == Utils.getAppSectionIndex(Constants.wallet)
                onClicked: appMain.changeAppSection(Constants.wallet)
            },

            StatusNavBarTabButton {
                enabled: isExperimental === "1" || appSettings.isBrowserEnabled
                visible: enabled
                tooltip.text: qsTr("Browser")
                icon.name: "browser"
                checked: appView.currentIndex == Utils.getAppSectionIndex(Constants.browser)
                onClicked: appMain.changeAppSection(Constants.browser)
            },

            StatusNavBarTabButton {
                enabled: isExperimental === "1" || appSettings.timelineEnabled
                visible: enabled
                tooltip.text: qsTr("Timeline")
                icon.name: "status-update"
                checked: appView.currentIndex == Utils.getAppSectionIndex(Constants.timeline)
                onClicked: appMain.changeAppSection(Constants.timeline)
            },

            StatusNavBarTabButton {
                id: profileBtn
                tooltip.text: qsTr("Profile")
                icon.name: "profile"
                checked: appView.currentIndex == Utils.getAppSectionIndex(Constants.profile)
                onClicked: appMain.changeAppSection(Constants.profile)

                badge.visible: !profileModel.mnemonic.isBackedUp && !checked
                badge.anchors.rightMargin: 4
                badge.anchors.topMargin: 5
                badge.border.color: hovered ? Theme.palette.statusBadge.hoverBorderColor : Theme.palette.statusAppNavBar.backgroundColor
                badge.border.width: 2
            }
        ]
    }

    appView: StackLayout {
        id: appView
        anchors.fill: parent
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

    Settings {
        id: appSettings
        fileName: profileModel.settings.settingsFile
        property var chatSplitView
        property var walletSplitView
        property var profileSplitView
        property bool communitiesEnabled: false
        property bool isWalletEnabled: false
        property bool nodeManagementEnabled: false
        property bool isBrowserEnabled: false
        property bool isActivityCenterEnabled: false
        property bool showOnlineUsers: false
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
        property string skinColor: ""

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
        target: profileModel.settings
        onSettingsFileChanged: {
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

    Connections {
        target: profileModel.contacts
        onContactRequestAdded: {
            if (!appSettings.notifyOnNewRequests) {
                return
            }
            const isContact = profileModel.contacts.isAdded(address)
            systemTray.showMessage(isContact ? qsTr("Contact request accepted") :
                                               qsTr("New contact request"),
                                   isContact ? qsTr("You can now chat with %1").arg(Utils.removeStatusEns(name)) :
                                               qsTr("%1 requests to become contacts").arg(Utils.removeStatusEns(name)),
                                   SystemTrayIcon.NoIcon,
                                   Constants.notificationPopupTTL)
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
}

/*##^##
Designer {
    D{i:0;formeditorZoom:1.75;height:770;width:1232}
}
##^##*/
