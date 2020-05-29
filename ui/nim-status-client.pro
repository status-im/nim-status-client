QT += quick

# The following define makes your compiler emit warnings if you use
# any Qt feature that has been marked deprecated (the exact warnings
# depend on your compiler). Refer to the documentation for the
# deprecated API to know how to port your code away from it.
DEFINES += QT_DEPRECATED_WARNINGS

# You can also make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
# You can also select to disable deprecated APIs only up to a certain version of Qt.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

SOURCES +=

RESOURCES += \
    imports/Theme.qml \
    imports/Constants.qml \
    main.qml

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH = $$PWD/imports

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH = $$PWD/imports

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

DISTFILES += \
    ../fonts/InterStatus/InterStatus-Black.otf \
    ../fonts/InterStatus/InterStatus-BlackItalic.otf \
    ../fonts/InterStatus/InterStatus-Bold.otf \
    ../fonts/InterStatus/InterStatus-BoldItalic.otf \
    ../fonts/InterStatus/InterStatus-ExtraBold.otf \
    ../fonts/InterStatus/InterStatus-ExtraBoldItalic.otf \
    ../fonts/InterStatus/InterStatus-ExtraLight.otf \
    ../fonts/InterStatus/InterStatus-ExtraLightItalic.otf \
    ../fonts/InterStatus/InterStatus-Italic.otf \
    ../fonts/InterStatus/InterStatus-Light.otf \
    ../fonts/InterStatus/InterStatus-LightItalic.otf \
    ../fonts/InterStatus/InterStatus-Medium.otf \
    ../fonts/InterStatus/InterStatus-MediumItalic.otf \
    ../fonts/InterStatus/InterStatus-Regular.otf \
    ../fonts/InterStatus/InterStatus-SemiBold.otf \
    ../fonts/InterStatus/InterStatus-SemiBoldItalic.otf \
    ../fonts/InterStatus/InterStatus-Thin.otf \
    ../fonts/InterStatus/InterStatus-ThinItalic.otf \
    Theme.qml \
    app/AppLayouts/Browser/BrowserLayout.qml \
    app/AppLayouts/Chat/ChatColumn.qml \
    app/AppLayouts/Chat/ChatColumn/MessagesData.qml \
    app/AppLayouts/Chat/ChatColumn/ChatInput.qml \
    app/AppLayouts/Chat/ChatColumn/ChatMessages.qml \
    app/AppLayouts/Chat/ChatColumn/EmptyChat.qml \
    app/AppLayouts/Chat/ChatColumn/Message.qml \
    app/AppLayouts/Chat/ChatColumn/TopBar.qml \
    app/AppLayouts/Chat/ChatColumn/qmldir \
    app/AppLayouts/Chat/ChatLayout.qml \
    app/AppLayouts/Chat/ContactsColumn.qml \
    app/AppLayouts/Chat/ContactsColumn/AddChat.qml \
    app/AppLayouts/Chat/ContactsColumn/Channel.qml \
    app/AppLayouts/Chat/ContactsColumn/ChannelList.qml \
    app/AppLayouts/Chat/ContactsColumn/EmptyView.qml \
    app/AppLayouts/Chat/ContactsColumn/SearchBox.qml \
    app/AppLayouts/Chat/ContactsColumn/qmldir \
    app/AppLayouts/Chat/components/PublicChatPopup.qml \
    app/AppLayouts/Chat/components/PrivateChatPopup.qml \
    app/AppLayouts/Chat/components/SuggestedChannel.qml \
    app/AppLayouts/Chat/components/qmldir \
    app/AppLayouts/Chat/qmldir \
    app/AppLayouts/Node/NodeLayout.qml \
    app/AppLayouts/Profile/LeftTab.qml \
    app/AppLayouts/Profile/LeftTab/Menu.qml \
    app/AppLayouts/Profile/LeftTab/Profile.qml \
    app/AppLayouts/Profile/LeftTab/qmldir \
    app/AppLayouts/Profile/ProfileLayout.qml \
    app/AppLayouts/Wallet/AssetsTab.qml \
    app/AppLayouts/Wallet/CollectiblesTab.qml \
    app/AppLayouts/Wallet/Components/SendModalContent.qml \
    app/AppLayouts/Wallet/Components/qmldir \
    app/AppLayouts/Wallet/HistoryTab.qml \
    app/AppLayouts/Profile/Sections/AboutContainer.qml \
    app/AppLayouts/Profile/Sections/AdvancedContainer.qml \
    app/AppLayouts/Profile/Sections/ContactsContainer.qml \
    app/AppLayouts/Profile/Sections/EnsContainer.qml \
    app/AppLayouts/Profile/Sections/HelpContainer.qml \
    app/AppLayouts/Profile/Sections/LanguageContainer.qml \
    app/AppLayouts/Profile/Sections/NotificationsContainer.qml \
    app/AppLayouts/Profile/Sections/PrivacyContainer.qml \
    app/AppLayouts/Profile/Sections/SignoutContainer.qml \
    app/AppLayouts/Profile/Sections/SyncContainer.qml \
    app/AppLayouts/Profile/Sections/qmldir \
    app/AppLayouts/Profile/qmldir \
    app/AppLayouts/Wallet/LeftTab.qml \
    app/AppLayouts/Wallet/SendModal.qml \
    app/AppLayouts/Wallet/WalletHeader.qml \
    app/AppLayouts/Wallet/WalletLayout.qml \
    app/AppLayouts/Wallet/qmldir \
    app/AppLayouts/WalletLayout.qml \
    app/AppLayouts/qmldir \
    app/AppMain.qml \
    app/img/arrow-btn-active.svg \
    app/img/arrow-btn-inactive.svg \
    app/img/compass.svg \
    app/img/compassActive.svg \
    app/img/close.svg \
    app/img/group_chat.svg \
    app/img/hash.svg \
    app/img/message.svg \
    app/img/messageActive.svg \
    app/img/new_chat.svg \
    app/img/profile.svg \
    app/img/profileActive.svg \
    app/img/public_chat.svg \
    app/img/search.svg \
    app/img/wallet.svg \
    app/img/walletActive.svg \
    app/qmldir \
    imports/qmldir \
    onboarding/ExistingKey.qml \
    onboarding/GenKey.qml \
    onboarding/Intro.qml \
    onboarding/KeysMain.qml \
    onboarding/Login.qml \
    onboarding/OnboardingMain.qml \
    onboarding/img/browser-dark@2x.jpg \
    onboarding/img/browser-dark@3x.jpg \
    onboarding/img/browser@2x.jpg \
    onboarding/img/browser@3x.jpg \
    onboarding/img/chat-dark@2x.jpg \
    onboarding/img/chat-dark@3x.jpg \
    onboarding/img/chat@2x.jpg \
    onboarding/img/chat@3x.jpg \
    onboarding/img/key.png \
    onboarding/img/key@2x.png \
    onboarding/img/next.svg \
    onboarding/img/wallet-dark@2x.jpg \
    onboarding/img/wallet-dark@3x.jpg \
    onboarding/img/wallet@2x.jpg \
    onboarding/img/wallet@3x.jpg \
    onboarding/qmldir \
    shared/Input.qml \
    shared/ModalPopup.qml \
    shared/PopupMenu.qml \
    shared/Separator.qml \
    shared/StatusTabButton.qml \
    shared/StyledButton.qml \
    shared/RoundedIcon.qml \
    shared/qmldir
