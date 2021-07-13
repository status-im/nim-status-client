import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Controls 1.0 as QQC1
import QtQuick.Layouts 1.13
import QtWebEngine 1.10
import QtWebChannel 1.13
import Qt.labs.settings 1.0
import QtQuick.Controls.Styles 1.0
import QtQuick.Dialogs 1.2
import "../../../shared"
import "../../../shared/status"
import "../../../imports"
import "../Chat/ChatColumn/ChatComponents"
import "./components"

// Code based on https://code.qt.io/cgit/qt/qtwebengine.git/tree/examples/webengine/quicknanobrowser/BrowserWindow.qml?h=5.15 
// Licensed under BSD

Rectangle {
    id: browserWindow
    color: Style.current.inputBackground
    border.width: 0

    property Item currentWebView: tabs.currentIndex < tabs.count ? tabs.getTab(tabs.currentIndex).item : null

    property Component browserDialogComponent: BrowserDialog {
        onClosing: destroy()
    }

    property Component jsDialogComponent: JSDialogWindow {}

    property bool currentTabConnected: false

    ListModel {
        id: downloadModel
        property var downloads: []
    }

    function removeDownloadFromModel(index) {
        downloadModel.downloads = downloadModel.downloads.filter(function (el) {
            return el.id !== downloadModel.downloads[index].id;
        });
        downloadModel.remove(index);
    }

    Layout.fillHeight: true
    Layout.fillWidth: true

    property var urlENSDictionary: ({})

    function determineRealURL(text){
        var url = _utilsModel.urlFromUserInput(text);
        var host = _web3Provider.getHost(url);
        if(host.endsWith(".eth")){
            var ensResource = _web3Provider.ensResourceURL(host, url);

            if(/^https\:\/\/swarm\-gateways\.net\/bzz:\/([0-9a-fA-F]{64}|.+\.eth)(\/?)/.test(ensResource)){
                // TODO: populate urlENSDictionary for prettier url instead of swarm-gateway big URL
                return ensResource;
            } else {
                urlENSDictionary[_web3Provider.getHost(ensResource)] = host;
            }
            url = ensResource;
        }
        return url;
    }

    function openUrlInNewTab(url) {
        browserWindow.addNewTab()
        currentWebView.url = determineRealURL(url)
    }

    property Component accessDialogComponent: BrowserConnectionModal {
        currentTab: tabs.getTab(tabs.currentIndex) && tabs.getTab(tabs.currentIndex).item
        x: browserWindow.width - width - Style.current.halfPadding
        y: browserHeader.y + browserHeader.height + Style.current.halfPadding
    }

    // TODO we'll need a new dialog at one point because this one is not using the same call, but it's good for now
    property Component sendTransactionModalComponent: SignTransactionModal {}

    property Component signMessageModalComponent: SignMessageModal {}

    property MessageDialog sendingError: MessageDialog {
        id: sendingError
        //% "Error sending the transaction"
        title: qsTrId("error-sending-the-transaction")
        icon: StandardIcon.Critical
        standardButtons: StandardButton.Ok
    }

    property MessageDialog signingError: MessageDialog {
        id: signingError
        //% "Error signing message"
        title: qsTrId("error-signing-message")
        icon: StandardIcon.Critical
        standardButtons: StandardButton.Ok
    }

    function getCurrentFavorite(url) {
        if (!url) {
            return null
        }
        const index = browserModel.bookmarks.getBookmarkIndexByUrl(url)
        if (index === -1) {
            return null
        }

        return {
            url: url,
            name: browserModel.bookmarks.rowData(index, 'name'),
            image: browserModel.bookmarks.rowData(index, 'imageUrl')
        }
    }

    AddFavoriteModal {
        id: addFavoriteModal
    }

    FavoriteMenu {
        id: favoriteMenu
        openInNewTab: function (url) {
            browserWindow.openUrlInNewTab(url)
        }
    }

    QtObject {
        id: provider
        WebChannel.id: "backend"

        signal web3Response(string data);

        function signValue(input){
            if(Utils.isHex(input) && Utils.startsWith0x(input)){
                return input
            }
            return utilsModel.ascii2Hex(input)
        }

        function postMessage(data) {
            var request;
            try {
                request = JSON.parse(data)
            } catch (e) {
                console.error("Error parsing the message data", e)
                return;
            }

            var ensAddr = urlENSDictionary[request.hostname];
            if (ensAddr) {
                request.hostname = ensAddr;
            }

            if (request.type === Constants.api_request) {
                if (!_web3Provider.hasPermission(request.hostname, request.permission)) {
                    browserWindow.currentTabConnected = false
                    var dialog = accessDialogComponent.createObject(browserWindow);
                    dialog.request = request;
                    dialog.open();
                } else {
                    browserWindow.currentTabConnected = true
                    request.isAllowed = true;
                    web3Response(_web3Provider.postMessage(JSON.stringify(request)));
                }
            } else if (request.type === Constants.web3SendAsyncReadOnly &&
                       request.payload.method === "eth_sendTransaction") {
                var acc = walletModel.dappBrowserView.dappBrowserAccount
                const value = utilsModel.wei2Eth(request.payload.params[0].value, 18);
                const sendDialog = sendTransactionModalComponent.createObject(browserWindow, {
                    trxData: request.payload.params[0].data || "",
                    selectedAccount: {
                        name: acc.name,
                        address: request.payload.params[0].from,
                        iconColor: acc.iconColor,
                        assets: acc.assets
                    },
                    selectedRecipient: {
                        address: request.payload.params[0].to,
                        identicon: utilsModel.generateIdenticon(request.payload.params[0].to),
                        name: chatsModel.channelView.activeChannel.name,
                        type: RecipientSelector.Type.Address
                    },
                    selectedAsset: {
                        name: "ETH",
                        symbol: "ETH",
                        address: Constants.zeroAddress
                    },
                    selectedFiatAmount: "42", // TODO calculate that
                    selectedAmount: value
                });

                // TODO change sendTransaction function to the postMessage one
                sendDialog.sendTransaction = function (selectedGasLimit, selectedGasPrice, enteredPassword) {
                    request.payload.selectedGasLimit = selectedGasLimit
                    request.payload.selectedGasPrice = selectedGasPrice
                    request.payload.password = enteredPassword
                    request.payload.params[0].value = value

                    const response = _web3Provider.postMessage(JSON.stringify(request))
                    provider.web3Response(response)

                    let responseObj
                    try {
                        responseObj = JSON.parse(response)

                        if (responseObj.error) {
                            throw new Error(responseObj.error)
                        }

                        //% "Transaction pending..."
                        toastMessage.title = qsTrId("ens-transaction-pending")
                        toastMessage.source = "../../img/loading.svg"
                        toastMessage.iconColor = Style.current.primary
                        toastMessage.iconRotates = true
                        toastMessage.link = `${_walletModel.utilsView.etherscanLink}/${responseObj.result.result}`
                        toastMessage.open()
                    } catch (e) {
                        if (Utils.isInvalidPasswordMessage(e.message)){
                            //% "Wrong password"
                            sendDialog.transactionSigner.validationError = qsTrId("wrong-password")
                            return
                        }
                        sendingError.text = e.message
                        return sendingError.open()
                    }

                    sendDialog.close()
                    sendDialog.destroy()
                }

                sendDialog.open();
                walletModel.gasView.getGasPricePredictions()
            } else if (request.type === Constants.web3SendAsyncReadOnly && ["eth_sign", "personal_sign", "eth_signTypedData", "eth_signTypedData_v3"].indexOf(request.payload.method) > -1) {
                const signDialog = signMessageModalComponent.createObject(browserWindow, {
                        request,
                        selectedAccount: {
                            name: walletModel.dappBrowserView.dappBrowserAccount.name,
                            iconColor: walletModel.dappBrowserView.dappBrowserAccount.iconColor
                        }
                    });
                signDialog.web3Response = web3Response
                signDialog.signMessage = function (enteredPassword) {
                    signDialog.interactedWith = true;
                    request.payload.password = enteredPassword;
                    switch(request.payload.method){
                        case Constants.personal_sign:
                            request.payload.params[0] = signValue(request.payload.params[0]);
                        case Constants.eth_sign:
                            request.payload.params[1] = signValue(request.payload.params[1]);
                    }
                    const response = web3Provider.postMessage(JSON.stringify(request));
                    provider.web3Response(response);
                    try {
                        let responseObj = JSON.parse(response)
                        if (responseObj.error) {
                            throw new Error(responseObj.error)
                        }
                    } catch (e) {
                        if (Utils.isInvalidPasswordMessage(e.message)){
                            //% "Wrong password"
                            signDialog.transactionSigner.validationError = qsTrId("wrong-password")
                            return
                        }
                        signingError.text = e.message
                        return signingError.open()
                    }
                    signDialog.close()
                    signDialog.destroy()
                }


                signDialog.open();
            } else if (request.type === Constants.web3DisconnectAccount) {
                web3Response(data);
            } else {
                web3Response(_web3Provider.postMessage(data));
            }
        }

        property int networkId: (_web3Provider && _web3Provider.networkId) || -1
    }

    WebChannel {
        id: channel
        registeredObjects: [provider]
    }

    property QtObject defaultProfile: WebEngineProfile {
        storageName: "Profile"
        offTheRecord: false
        httpUserAgent: {
            if (appSettings.compatibilityMode) {
                // Google doesn't let you connect if the user agent is Chrome-ish and doesn't satisfy some sort of hidden requirement
                return "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:81.0) Gecko/20100101 Firefox/81.0"
            }
            return ""
        }
        useForGlobalCertificateVerification: true
        userScripts: [
            WebEngineScript {
                injectionPoint: WebEngineScript.DocumentCreation
                sourceUrl:  Qt.resolvedUrl("provider.js")
                worldId: WebEngineScript.MainWorld // TODO: check https://doc.qt.io/qt-5/qml-qtwebengine-webenginescript.html#worldId-prop 
            }
        ]
    }

    property QtObject otrProfile: WebEngineProfile {
        offTheRecord: true
        persistentCookiesPolicy:  WebEngineProfile.NoPersistentCookies
        httpUserAgent: defaultProfile.httpUserAgent
        userScripts: [
            WebEngineScript {
                injectionPoint: WebEngineScript.DocumentCreation
                sourceUrl:  Qt.resolvedUrl("provider.js")
                worldId: WebEngineScript.MainWorld // TODO: check https://doc.qt.io/qt-5/qml-qtwebengine-webenginescript.html#worldId-prop 
            }
        ]
    }
    
    function obtainAddress(){
        var ensAddr = urlENSDictionary[web3Provider.getHost(currentWebView.url)];
        browserHeader.addressBar.text = ensAddr ? web3Provider.replaceHostByENS(currentWebView.url, ensAddr) : currentWebView.url;
    }

    onCurrentWebViewChanged: {
        findBar.reset();
        obtainAddress();
    }

    Action {
        shortcut: "Ctrl+D"
        onTriggered: {
            addNewDownloadTab()
        }
    }
    function addNewDownloadTab() {
        tabs.createDownloadTab(tabs.count !== 0 ? currentWebView.profile : defaultProfile);
        tabs.currentIndex = tabs.count - 1;
    }

    Action {
        id: focus
        shortcut: "Ctrl+L"
        onTriggered: {
            browserHeader.addressBar.forceActiveFocus();
            browserHeader.addressBar.selectAll();
        }
    }
    Action {
        shortcut: StandardKey.Refresh
        onTriggered: {
            if (currentWebView)
                currentWebView.reload();
        }
    }
    function addNewTab() {
        tabs.createEmptyTab(tabs.count !== 0 ? currentWebView.profile : defaultProfile);
        tabs.currentIndex = tabs.count - 1;
        browserHeader.addressBar.forceActiveFocus();
        browserHeader.addressBar.selectAll();
    }

    Action {
        shortcut: "Ctrl+W"
        onTriggered: {
            tabs.removeView(tabs.currentIndex)
        }
    }


    Action {
        shortcut: StandardKey.Close
        onTriggered: {
            currentWebView.triggerWebAction(WebEngineView.RequestClose);
        }
    }
    Action {
        shortcut: "Escape"
        onTriggered: {
            if (findBar.visible)
                findBar.visible = false;
        }
    }


    Action {
        shortcut: StandardKey.Copy
        onTriggered: currentWebView.triggerWebAction(WebEngineView.Copy)
    }
    Action {
        shortcut: StandardKey.Cut
        onTriggered: currentWebView.triggerWebAction(WebEngineView.Cut)
    }
    Action {
        shortcut: StandardKey.Paste
        onTriggered: currentWebView.triggerWebAction(WebEngineView.Paste)
    }
    Action {
        shortcut: "Shift+"+StandardKey.Paste
        onTriggered: currentWebView.triggerWebAction(WebEngineView.PasteAndMatchStyle)
    }
    Action {
        shortcut: StandardKey.SelectAll
        onTriggered: currentWebView.triggerWebAction(WebEngineView.SelectAll)
    }
    Action {
        shortcut: StandardKey.Undo
        onTriggered: currentWebView.triggerWebAction(WebEngineView.Undo)
    }
    Action {
        shortcut: StandardKey.Redo
        onTriggered: currentWebView.triggerWebAction(WebEngineView.Redo)
    }
    Action {
        shortcut: StandardKey.Back
        onTriggered: currentWebView.triggerWebAction(WebEngineView.Back)
    }
    Action {
        shortcut: StandardKey.Forward
        onTriggered: currentWebView.triggerWebAction(WebEngineView.Forward)
    }
    Action {
        shortcut: StandardKey.FindNext
        onTriggered: findBar.findNext()
    }
    Action {
        shortcut: StandardKey.FindPrevious
        onTriggered: findBar.findPrevious()
    }

    BrowserHeader {
        id: browserHeader
        anchors.top: parent.top
        anchors.topMargin: tabs.tabHeight + tabs.anchors.topMargin
        z: 52
        addNewTab: browserWindow.addNewTab
    }

    QQC1.TabView {
        property int tabHeight: 40
        id: tabs
        function createEmptyTab(profile, createAsStartPage) {
            var tab = addTab("", tabComponent);
            // We must do this first to make sure that tab.active gets set so that tab.item gets instantiated immediately.
            tab.active = true;
            createAsStartPage = createAsStartPage || tabs.count === 1
            tab.title = Qt.binding(function() {
                if (tab.item.title) {
                    return tab.item.title
                }

                if (createAsStartPage) {
                    //% "Start Page"
                    return qsTrId("start-page")
                }
                //% "New Tab"
                return qsTrId("new-tab")
            })

            tab.item.profile = profile;
            if (appSettings.browserHomepage !== "") {
                tab.item.url = appSettings.browserHomepage
            }
            return tab;
        }

        function createDownloadTab(profile) {
            var tab = addTab("", tabComponent);
            tab.active = true;
            //% "Downloads Page"
            tab.title = qsTrId("downloads-page")
            tab.item.profile = profile
            tab.item.url = "status://downloads";
        }

        function indexOfView(view) {
            for (let i = 0; i < tabs.count; ++i)
                if (tabs.getTab(i).item === view)
                    return i
            return -1
        }

        function removeView(index) {
            if (tabs.count === 1) {
                tabs.createEmptyTab(currentWebView.profile, true)
            }
            tabs.removeTab(index)
        }

        z: 50
        anchors.top: parent.top
        anchors.topMargin: Style.current.halfPadding
        anchors.bottom: devToolsView.top
        anchors.bottomMargin: browserHeader.height
        anchors.left: parent.left
        anchors.right: parent.right
        Component.onCompleted: {
            defaultProfile.downloadRequested.connect(onDownloadRequested);
            otrProfile.downloadRequested.connect(onDownloadRequested);
            var tab = createEmptyTab(defaultProfile);
            // For Devs: Uncomment the next lien if you want to use the simpeldapp on first load
            // tab.item.url = determineRealURL("https://simpledapp.eth");
        }

        style: BrowserTabStyle {}

        Component {
            id: tabComponent
            WebEngineView {
                id: webEngineView
                anchors.top: parent.top
                anchors.topMargin: browserHeader.height
                focus: true
                url: "https://dap.ps"
                webChannel: channel
                onLinkHovered: function(hoveredUrl) {
                    if (hoveredUrl === "")
                        hideStatusText.start();
                    else {
                        statusText.text = hoveredUrl;
                        statusBubble.visible = true;
                        hideStatusText.stop();
                    }
                }
                backgroundColor: Style.current.background

                function changeZoomFactor(newFactor) {
                    // FIXME there seems to be a bug in the WebEngine where the zoomFactor only update 1/2 times
                    zoomFactor = newFactor
                    zoomFactor = newFactor
                    zoomFactor = newFactor
                }

                settings.autoLoadImages: appSettings.autoLoadImages
                settings.javascriptEnabled: appSettings.javaScriptEnabled
                settings.errorPageEnabled: appSettings.errorPageEnabled
                settings.pluginsEnabled: appSettings.pluginsEnabled
                settings.autoLoadIconsForPage: appSettings.autoLoadIconsForPage
                settings.touchIconsEnabled: appSettings.touchIconsEnabled
                settings.webRTCPublicInterfacesOnly: appSettings.webRTCPublicInterfacesOnly
                settings.pdfViewerEnabled: appSettings.pdfViewerEnabled
                settings.focusOnNavigationEnabled: true

                onCertificateError: function(error) {
                    error.defer();
                    sslDialog.enqueue(error);
                }

                onJavaScriptDialogRequested: function(request) {
                    request.accepted = true;
                    var dialog = jsDialogComponent.createObject(browserWindow, {"request": request});
                    dialog.open();
                }

                onNewViewRequested: function(request) {
                    if (!request.userInitiated) {
                        print("Warning: Blocked a popup window.");
                    } else if (request.destination === WebEngineView.NewViewInTab) {
                        var tab = tabs.createEmptyTab(currentWebView.profile);
                        tabs.currentIndex = tabs.count - 1;
                        request.openIn(tab.item);
                    } else if (request.destination === WebEngineView.NewViewInBackgroundTab) {
                        var backgroundTab = tabs.createEmptyTab(currentWebView.profile);
                        request.openIn(backgroundTab.item);
                    // Disabling popups temporarily since we need to set that webengineview settings / channel and other properties
                    /*} else if (request.destination === WebEngineView.NewViewInDialog) {
                        var dialog = browserDialogComponent.createObject();
                        dialog.currentWebView.profile = currentWebView.profile;
                        dialog.currentWebView.webChannel = channel;
                        request.openIn(dialog.currentWebView);*/
                    } else {
                        // Instead of opening a new window, we open a new tab
                        // TODO: remove "open in new window" from context menu
                        var tab = tabs.createEmptyTab(currentWebView.profile);
                        tabs.currentIndex = tabs.count - 1;
                        request.openIn(tab.item);
                    }
                }

                onQuotaRequested: function(request) {
                    if (request.requestedSize <= 5 * 1024 * 1024)
                        request.accept();
                    else
                        request.reject();
                }

                onRegisterProtocolHandlerRequested: function(request) {
                    console.log("accepting registerProtocolHandler request for "
                                + request.scheme + " from " + request.origin);
                    request.accept();
                }

                onRenderProcessTerminated: function(terminationStatus, exitCode) {
                    var status = "";
                    switch (terminationStatus) {
                    case WebEngineView.NormalTerminationStatus:
                        status = "(normal exit)";
                        break;
                    case WebEngineView.AbnormalTerminationStatus:
                        status = "(abnormal exit)";
                        break;
                    case WebEngineView.CrashedTerminationStatus:
                        status = "(crashed)";
                        break;
                    case WebEngineView.KilledTerminationStatus:
                        status = "(killed)";
                        break;
                    }

                    print("Render process exited with code " + exitCode + " " + status);
                    reloadTimer.running = true;
                }

                onWindowCloseRequested: tabs.removeView(tabs.indexOfView(webEngineView))

                onSelectClientCertificate: function(selection) {
                    selection.certificates[0].select();
                }

                onFindTextFinished: function(result) {
                    if (!findBar.visible)
                        findBar.visible = true;

                    findBar.numberOfMatches = result.numberOfMatches;
                    findBar.activeMatch = result.activeMatch;
                }

                onLoadingChanged: function(loadRequest) {
                    if (loadRequest.status === WebEngineView.LoadStartedStatus)
                        findBar.reset();
                }

                onNavigationRequested: {
                    if(request.url.toString().startsWith("file://")){
                        console.log("Local file browsing is disabled" )
                        request.action = WebEngineNavigationRequest.IgnoreRequest;
                    }
                }

                Loader {
                    active: webEngineView.url.toString() === "status://downloads"
                    width: parent.width
                    height: parent.height
                    z: 54
                    sourceComponent: DownloadView {
                        id: downloadView
                    }
                }

                Loader {
                    active: !webEngineView.url.toString()
                    width: parent.width
                    height: parent.height
                    z: 54

                    sourceComponent: Item {
                        width: parent.width
                        height: parent.height

                        Image {
                            id: emptyPageImage
                            source: "../../img/browser/compass.png"
                            width: 294
                            height: 294
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 60
                        }

                        FavoritesList {
                            id: bookmarkListContainer
                            anchors.horizontalCenter: emptyPageImage.horizontalCenter
                            anchors.top: emptyPageImage.bottom
                            anchors.topMargin: 30
                            width: parent.width - Style.current.bigPadding * 2
                        }
                    }
                }



                Timer {
                    id: reloadTimer
                    interval: 0
                    running: false
                    repeat: false
                    onTriggered: currentWebView.reload()
                }
            }
        }
    }

    Connections {
        target: currentWebView
        onUrlChanged: obtainAddress()
    }

    ProgressBar {
        id: progressBar
        height: 3
        from: 0
        to: 100
        visible: value != 0 && value != 100
        value: (currentWebView && currentWebView.loadProgress < 100) ? currentWebView.loadProgress : 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.current.padding
        anchors.right: parent.right
        anchors.rightMargin: Style.current.padding
    }

    WebEngineView {
        id: devToolsView
        visible: appSettings.devToolsEnabled
        height: visible ? 400 : 0
        inspectedView: visible && tabs.currentIndex < tabs.count ? tabs.getTab(tabs.currentIndex).item : null
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        onNewViewRequested: function(request) {
            var tab = tabs.createEmptyTab(currentWebView.profile);
            tabs.currentIndex = tabs.count - 1;
            request.openIn(tab.item);
        }
        z: 100
    }

    function onDownloadRequested(download) {
        downloadBar.isVisible = true
        download.accept();
        downloadModel.append(download);
        downloadModel.downloads.push(download);
    }

    MessageDialog {
        id: sslDialog

        property var certErrors: []
        icon: StandardIcon.Warning
        standardButtons: StandardButton.No | StandardButton.Yes
        //% "Server's certificate not trusted"
        title: qsTrId("server-s-certificate-not-trusted")
        //% "Do you wish to continue?"
        text: qsTrId("do-you-wish-to-continue-")
        //% "If you wish so, you may continue with an unverified certificate. Accepting an unverified certificate means you may not be connected with the host you tried to connect to.\nDo you wish to override the security check and continue?"
        detailedText: qsTrId("if-you-wish-so--you-may-continue-with-an-unverified-certificate--accepting-an-unverified-certificate-means-you-may-not-be-connected-with-the-host-you-tried-to-connect-to--ndo-you-wish-to-override-the-security-check-and-continue-")
        onYes: {
            certErrors.shift().ignoreCertificateError();
            presentError();
        }
        onNo: reject()
        onRejected: reject()

        function reject(){
            certErrors.shift().rejectCertificate();
            presentError();
        }
        function enqueue(error){
            certErrors.push(error);
            presentError();
        }
        function presentError(){
            visible = certErrors.length > 0
        }
    }



    DownloadBar {
        id: downloadBar
        anchors.bottom: parent.bottom
        z: 60
    }

    FindBar {
        id: findBar
        visible: false
        anchors.right: parent.right
        anchors.top: browserHeader.bottom
        z: 60

        onFindNext: {
            if (text)
                currentWebView && currentWebView.findText(text);
            else if (!visible)
                visible = true;
        }
        onFindPrevious: {
            if (text)
                currentWebView && currentWebView.findText(text, WebEngineView.FindBackward);
            else if (!visible)
                visible = true;
        }
    }

    Rectangle {
        id: statusBubble
        color: "oldlace"
        property int padding: 8
        visible: false

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: statusText.paintedWidth + padding
        height: statusText.paintedHeight + padding

        Text {
            id: statusText
            anchors.centerIn: statusBubble
            elide: Qt.ElideMiddle

            Timer {
                id: hideStatusText
                interval: 750
                onTriggered: {
                    statusText.text = "";
                    statusBubble.visible = false;
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
