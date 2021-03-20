import NimQml, chronicles, os, strformat

import app/chat/core as chat
import app/wallet/core as wallet
import app/node/core as node
import app/utilsView/core as utilsView
import app/browser/core as browserView
import app/profile/core as profile
import app/onboarding/core as onboarding
import app/login/core as login
import app/provider/core as provider
import status/signals/core as signals
import status/libstatus/types
import status/libstatus/accounts/constants
import status_go
import status/status as statuslib
import ./eventemitter

var signalsQObjPointer: pointer

logScope:
  topics = "main"

proc mainProc() =
  let fleets =
    if defined(windows) and getEnv("NIM_STATUS_CLIENT_DEV").string == "":
      "/../resources/fleets.json"
    else:
      "/../fleets.json"

  let status = statuslib.newStatusInstance(readFile(joinPath(getAppDir(), fleets)))
  status.initNode()

  enableHDPI()
  initializeOpenGL()

  let app = newQApplication("Status Desktop")
  let resources =
    if defined(windows) and getEnv("NIM_STATUS_CLIENT_DEV").string == "":
      "/../resources/resources.rcc"
    else:
      "/../resources.rcc"
  QResource.registerResource(app.applicationDirPath & resources)

  let statusAppIcon =
    if defined(macosx):
      "" # not used in macOS
    elif defined(windows) and getEnv("NIM_STATUS_CLIENT_DEV").string == "":
      "/../resources/status.svg"
    elif getEnv("NIM_STATUS_CLIENT_DEV").string != "":
      "/../status-dev.svg"
    else:
      "/../status.svg"
  if not defined(macosx):
    app.icon(app.applicationDirPath & statusAppIcon)

  var i18nPath = ""
  if (getEnv("NIM_STATUS_CLIENT_DEV").string != ""):
    i18nPath = joinPath(getAppDir(), "../ui/i18n")
  elif (defined(windows)):
    i18nPath = joinPath(getAppDir(), "../resources/i18n")
  elif (defined(macosx)):
    i18nPath = joinPath(getAppDir(), "../i18n")
  elif (defined(linux)):
    i18nPath = joinPath(getAppDir(), "../i18n")

  let networkAccessFactory = newQNetworkAccessManagerFactory(TMPDIR & "netcache")

  let engine = newQQmlApplicationEngine()
  engine.setNetworkAccessManagerFactory(networkAccessFactory)

  let netAccMgr = newQNetworkAccessManager(engine.getNetworkAccessManager())

  status.events.on("network:connected") do(e: Args):
    # This is a workaround for Qt bug https://bugreports.qt.io/browse/QTBUG-55180
    # that was apparently reintroduced in 5.14.1 Unfortunately, the only workaround
    # that could be found uses obsolete properties and methods
    # (https://doc.qt.io/qt-5/qnetworkaccessmanager-obsolete.html), so this will
    # need to be something we keep in mind when upgrading to Qt 6.
    # The workaround is to manually set the NetworkAccessible property of the
    # QNetworkAccessManager once peers have dropped (network connection is lost).
    netAccMgr.clearConnectionCache()
    netAccMgr.setNetworkAccessible(NetworkAccessibility.Accessible)

  let signalController = signals.newController(status)

  # We need this global variable in order to be able to access the application
  # from the non-closure callback passed to `libstatus.setSignalEventCallback`
  signalsQObjPointer = cast[pointer](signalController.vptr)

  var wallet = wallet.newController(status)
  engine.setRootContextProperty("walletModel", wallet.variant)

  var chat = chat.newController(status)
  engine.setRootContextProperty("chatsModel", chat.variant)

  var node = node.newController(status, netAccMgr)
  engine.setRootContextProperty("nodeModel", node.variant)

  var utilsController = utilsView.newController(status)
  engine.setRootContextProperty("utilsModel", utilsController.variant)

  var browserController = browserView.newController(status)
  engine.setRootContextProperty("browserModel", browserController.variant)

  proc changeLanguage(locale: string) =
    engine.setTranslationPackage(joinPath(i18nPath, fmt"qml_{locale}.qm"))

  var profile = profile.newController(status, changeLanguage)
  engine.setRootContextProperty("profileModel", profile.variant)

  var provider = provider.newController(status)
  engine.setRootContextProperty("web3Provider", provider.variant)

  var login = login.newController(status)
  var onboarding = onboarding.newController(status)

  status.events.once("login") do(a: Args):
    var args = AccountArgs(a)
    # Delete login and onboarding from memory to remove any mnemonic that would have been saved in the accounts list
    login.delete()
    onboarding.delete()

    status.startMessenger()
    profile.init(args.account)
    wallet.init()
    provider.init()
    chat.init()
    utilsController.init()
    browserController.init()

    wallet.checkPendingTransactions()
    wallet.start()


  engine.setRootContextProperty("loginModel", login.variant)
  engine.setRootContextProperty("onboardingModel", onboarding.variant)

  let isExperimental = if getEnv("EXPERIMENTAL") == "1": "1" else: "0" # value explicity passed to avoid trusting input
  let experimentalFlag = newQVariant(isExperimental)
  engine.setRootContextProperty("isExperimental", experimentalFlag)

  defer:
    error "TODO: if user is logged in, logout"
    provider.delete()
    engine.delete()
    app.delete()
    signalController.delete()
    login.delete()
    onboarding.delete()
    wallet.delete()
    chat.delete()
    profile.delete()
    utilsController.delete()
    browserController.delete()
    status.tasks.teardown()


  # Initialize only controllers whose init functions
  # do not need a running node
  proc initControllers() =
    node.init()
    login.init()
    onboarding.init()

  initControllers()

  # Handle node.stopped signal when user has logged out
  status.events.once("nodeStopped") do(a: Args):
    # TODO: remove this once accounts are not tracked in the AccountsModel
    status.reset()

    # 1. Reset controller data
    login.reset()
    onboarding.reset()
    # TODO: implement all controller resets
    # chat.reset()
    # node.reset()
    # wallet.reset()
    # profile.reset()

    # 2. Re-init controllers that don't require a running node
    initControllers()

  engine.setRootContextProperty("signals", signalController.variant)

  engine.load(newQUrl("qrc:///main.qml"))

  # Please note that this must use the `cdecl` calling convention because
  # it will be passed as a regular C function to libstatus. This means that
  # we cannot capture any local variables here (we must rely on globals)
  var callback: SignalCallback = proc(p0: cstring) {.cdecl.} =
    signal_handler(signalsQObjPointer, p0, "receiveSignal")

  status_go.setSignalEventCallback(callback)

  # Qt main event loop is entered here
  # The termination of the loop will be performed when exit() or quit() is called
  info "Starting application..."
  app.exec()

when isMainModule:
  mainProc()
