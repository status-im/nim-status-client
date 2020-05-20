import NimQml
import app/chat/core as chat
import app/wallet/core as wallet
import app/node/core as node
import app/profile/core as profile
import app/signals/core as signals
import state
import strformat
import strutils
import json
import status/core as status
import status/chat as status_chat
import status/test as status_test
import status/types as types
import status/wallet as status_wallet
import status/libstatus
import state

var signalsQObjPointer: pointer

proc mainProc() =
  let app = newQApplication()
  let engine = newQQmlApplicationEngine()
  let signalController = signals.newController(app)

  defer: # Defer will run this just before mainProc() function ends
    app.delete()
    engine.delete()
    signalController.delete()

  # We need this global variable in order to be able to access the application
  # from the non-closure callback passed to `libstatus.setSignalEventCallback`
  signalsQObjPointer = cast[pointer](signalController.vptr)

  var appState = state.newAppState()
  echo appState.title

  var accounts = status_test.setupNewAccount()
  echo "---------"
  echo parseJSON(accounts)[0]
  echo parseJSON(accounts)[1]
  echo "---------"

  status_chat.startMessenger()

  var wallet = wallet.newController()
  wallet.init()
  engine.setRootContextProperty("assetsModel", wallet.variant)

  var chat = chat.newController()
  chat.init()
  engine.setRootContextProperty("chatsModel", chat.variant)

  var node = node.newController()
  node.init()
  engine.setRootContextProperty("nodeModel", node.variant)

  var profile = profile.newController()
  profile.init(accounts)
  engine.setRootContextProperty("profileModel", profile.variant)

  signalController.init()
  signalController.addSubscriber(SignalType.Wallet, wallet)
  signalController.addSubscriber(SignalType.Wallet, node)
  signalController.addSubscriber(SignalType.Message, chat)

  engine.setRootContextProperty("signals", signalController.variant)

  appState.subscribe(proc () =
    # chatsModel.names = @[]
    for channel in appState.channels:
      echo channel.name
      # chatsModel.addNameTolist(channel.name)
      chat.join(channel.name)
  )

  appState.addChannel("test")
  appState.addChannel("test2")

  engine.load("../ui/main.qml")

  # Please note that this must use the `cdecl` calling convention because
  # it will be passed as a regular C function to libstatus. This means that
  # we cannot capture any local variables here (we must rely on globals)
  var callback: SignalCallback = proc(p0: cstring) {.cdecl.} =
    setupForeignThreadGc()
    signal_handler(signalsQObjPointer, p0, "receiveSignal")
    tearDownForeignThreadGc()

  libstatus.setSignalEventCallback(callback)

  # Qt main event loop is entered here
  # The termination of the loop will be performed when exit() or quit() is called
  app.exec()

when isMainModule:
  mainProc()
  GC_fullcollect()
