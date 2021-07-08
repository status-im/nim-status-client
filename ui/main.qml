import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import Qt.labs.platform 1.1
import QtQml.StateMachine 1.14 as DSM
import Qt.labs.settings 1.0
import QtQuick.Window 2.12
import QtQml 2.13
import QtQuick.Window 2.0
import QtQuick.Controls.Universal 2.12

import DotherSide 0.1

import "./onboarding"
import "./app"
import "./sounds"
import "./shared"
import "./imports"

StatusWindow {
    property bool hasAccounts: !!loginModel.rowCount()
    property bool removeMnemonicAfterLogin: false
    property alias dragAndDrop: dragTarget
    property bool popupOpened: false

    Universal.theme: Universal.System

    Settings {
        id: globalSettings
        category: "global"
        fileName: profileModel.settings.globalSettingsFile
        property string locale: "en"
        property int theme: 2
    }

    id: applicationWindow
    minimumWidth: 900
    minimumHeight: 600
    width: 1232
    height: 770
    color: Style.current.background
    title: {
        // Set application settings
        //% "Status Desktop"
        Qt.application.name = qsTrId("status-desktop")
        Qt.application.organization = "Status"
        Qt.application.domain = "status.im"
        return Qt.application.name
    }
    visible: true

    Action {
        shortcut: StandardKey.FullScreen
        onTriggered: {
            if (visibility === Window.FullScreen) {
                showNormal()
            } else {
                showFullScreen()
            }
        }
    }

    Action {
        shortcut: "Ctrl+M"
        onTriggered: {
            if (visibility === Window.Minimized) {
                showNormal()
            } else {
                showMinimized()
            }
        }
    }
    
    Action {
        shortcut: "Ctrl+W"
        enabled: loader.item ? loader.item.currentView !== Utils.getAppSectionIndex(Constants.browser)
                             : true
        onTriggered: {
            applicationWindow.visible = false;
        }
    }

    Action {
        shortcut: "Ctrl+Q"
        onTriggered: {
            Qt.quit()
        }
    }

    //! Workaround for custom QQuickWindow
    Connections {
        target: applicationWindow
        function onClosing() {
            if (loader.sourceComponent == login) {
                applicationWindow.visible = false;
                close.accepted = false;
            }
            else if (loader.sourceComponent == app) {
                if (loader.item.appSettings.quitOnClose) {
                    Qt.quit();
                } else {
                    applicationWindow.visible = false;
                    close.accepted = false;
                }
            }
        }

        function onActiveChanged() {
            if (applicationWindow.active && currentlyHasANotification) {
                currentlyHasANotification = false
                // QML doesn't have a function to hide notifications, but this does the trick
                systemTray.hide()
                systemTray.show()
            }
        }
    }

    Component.onCompleted: {
        Style.changeTheme(globalSettings.theme)
        setX(Qt.application.screens[0].width / 2 - width / 2);
        setY(Qt.application.screens[0].height / 2 - height / 2);
    }

    signal navigateTo(string path)
    
    property bool currentlyHasANotification: false

    SystemTrayIcon {
        id: systemTray
        visible: true
        icon.source: "shared/img/status-logo.svg"
        menu: Menu {
            MenuItem {
                visible: !applicationWindow.visible
                text: qsTr("Open Status")
                onTriggered: {
                    applicationWindow.visible = true;
                    applicationWindow.requestActivate();
                }
            }
            
            MenuSeparator {
                visible: !applicationWindow.visible
            }

            MenuItem {
                //% "Quit"
                text: qsTrId("quit")
                onTriggered: Qt.quit()
            }
        }

        onActivated: {
            if (reason === SystemTrayIcon.Context) {
                return
            }
            applicationWindow.show()
            applicationWindow.raise()
            applicationWindow.requestActivate()
        }
    }

    DSM.StateMachine {
        id: stateMachine
        initialState: onboardingState
        running: true

        DSM.State {
            id: onboardingState
            initialState: hasAccounts ? stateLogin : keysMainState

            DSM.State {
                id: keysMainState
                onEntered: loader.sourceComponent = keysMain

                DSM.SignalTransition {
                    targetState: genKeyState
                    signal: applicationWindow.navigateTo
                    guard: path === "GenKey"
                }
            }

            DSM.State {
                id: existingKeyState
                onEntered: loader.sourceComponent = existingKey

                DSM.SignalTransition {
                    targetState: appState
                    signal: onboardingModel.loginResponseChanged
                    guard: !error
                }
            }

            DSM.State {
                id: genKeyState
                onEntered: loader.sourceComponent = genKey

                DSM.SignalTransition {
                    targetState: appState
                    signal: onboardingModel.loginResponseChanged
                    guard: !error
                }
            }

            DSM.State {
                id: stateLogin
                onEntered: loader.sourceComponent = login

                DSM.SignalTransition {
                    targetState: appState
                    signal: loginModel.loginResponseChanged
                    guard: !error
                }

                DSM.SignalTransition {
                    targetState: genKeyState
                    signal: applicationWindow.navigateTo
                    guard: path === "GenKey"
                }
            }

            DSM.SignalTransition {
                targetState: hasAccounts ? stateLogin : keysMainState
                signal: applicationWindow.navigateTo
                guard: path === "InitialState"
            }

            DSM.SignalTransition {
                targetState: existingKeyState
                signal: applicationWindow.navigateTo
                guard: path === "ExistingKey"
            }

            DSM.SignalTransition {
                targetState: keysMainState
                signal: applicationWindow.navigateTo
                guard: path === "KeysMain"
            }

            DSM.FinalState {
                id: onboardingDoneState
            }
        }

        DSM.State {
            id: appState
            onEntered: loader.sourceComponent = app

            DSM.SignalTransition {
                targetState: stateLogin
                signal: loginModel.onLoggedOut
            }
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        property var appSettings
    }

    DropArea {
        id: dragTarget

        signal droppedOnValidScreen(var drop)
        property alias droppedUrls: rptDraggedPreviews.model
        readonly property int chatView: Utils.getAppSectionIndex(Constants.chat)
        readonly property int timelineView: Utils.getAppSectionIndex(Constants.timeline)
        property bool enabled: containsDrag && loader.item &&
                               (
                                   // in chat view
                                   (loader.item.currentView === chatView &&
                                    (
                                        // in a one-to-one chat
                                        chatsModel.channelView.activeChannel.chatType === Constants.chatTypeOneToOne ||
                                        // in a private group chat
                                        chatsModel.channelView.activeChannel.chatType === Constants.chatTypePrivateGroupChat
                                        )
                                    ) ||
                                   // in timeline view
                                   loader.item.currentView === timelineView ||
                                   // In community section
                                   chatsModel.communities.activeCommunity.active
                                   )

        width: applicationWindow.width
        height: applicationWindow.height

        function cleanup() {
            rptDraggedPreviews.model = []
        }

        onDropped: (drop) => {
                       if (enabled) {
                           droppedOnValidScreen(drop)
                       }
                       cleanup()
                   }
        onEntered: {
            // needed because drag.urls is not a normal js array
            rptDraggedPreviews.model = drag.urls.filter(img => Utils.hasDragNDropImageExtension(img))
        }
        onPositionChanged: {
            rptDraggedPreviews.x = drag.x
            rptDraggedPreviews.y = drag.y
        }
        onExited: cleanup()
        Rectangle {
            id: dropRectangle

            width: parent.width
            height: parent.height
            color: Style.current.transparent
            opacity: 0.8

            states: [
                State {
                    when: dragTarget.enabled
                    PropertyChanges {
                        target: dropRectangle
                        color: Style.current.background
                    }
                }
            ]
        }
        Repeater {
            id: rptDraggedPreviews

            Image {
                source: modelData
                width: 80
                height: 80
                sourceSize.width: 160
                sourceSize.height: 160
                fillMode: Image.PreserveAspectFit
                x: index * 10 + rptDraggedPreviews.x
                y: index * 10 + rptDraggedPreviews.y
                z: 1
            }
        }
    }

    Component {
        id: app
        AppMain {}
    }

    Component {
        id: keysMain
        KeysMain {
            displayBeforeGetStartedModal: !hasAccounts
            btnGenKey.onClicked: applicationWindow.navigateTo("GenKey")
            btnExistingKey.onClicked: applicationWindow.navigateTo("ExistingKey")
        }
    }

    Component {
        id: existingKey
        ExistingKey {
            onClosed: function () {
                removeMnemonicAfterLogin = false
                if (hasAccounts) {
                    applicationWindow.navigateTo("InitialState")
                } else {
                    applicationWindow.navigateTo("KeysMain")
                }
            }
        }
    }

    Component {
        id: genKey
        GenKey {
            onClosed: function () {
                if (hasAccounts) {
                    applicationWindow.navigateTo("InitialState")
                } else {
                    applicationWindow.navigateTo("KeysMain")
                }
            }
        }
    }

    Component {
        id: login
        Login {
            onGenKeyClicked: function () {
                applicationWindow.navigateTo("GenKey")
            }
            onExistingKeyClicked: function () {
                applicationWindow.navigateTo("ExistingKey")
            }
        }
    }

    NotificationWindow {
        id: notificationWindow
    }

    MacTrafficLights {
//        parent: Overlay.overlay
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 13

        visible: Qt.platform.os === "osx" && !applicationWindow.isFullScreen

        onClose: {
            if (loader.sourceComponent == login) {
                applicationWindow.visible = false;
            }
            else if (loader.sourceComponent == app) {
                if (loader.item.appSettings.quitOnClose) {
                    Qt.quit();
                } else {
                    applicationWindow.visible = false;
                }
            }
        }

        onMinimised: {
            applicationWindow.showMinimized()
        }

        onMaximized: {
            applicationWindow.toggleFullScreen()
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorZoom:0.5}
}
##^##*/
