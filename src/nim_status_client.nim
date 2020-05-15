import NimQml
import application/applicationView
import chat/core as chat
import wallet/core as wallet
import node/core as node
import state

import status/core as status
# import status/chat as status_chat
import status/test as status_test
import status/types

proc mainProc() =
  # From QT docs:
  # For any GUI application using Qt, there is precisely one QApplication object,
  # no matter whether the application has 0, 1, 2 or more windows at any given time.
  # For non-QWidget based Qt applications, use QGuiApplication instead, as it does
  # not depend on the QtWidgets library. Use QCoreApplication for non GUI apps
  var app = newQApplication()
  defer: app.delete() # Defer will run this just before mainProc() function ends

  var engine = newQQmlApplicationEngine()
  defer: engine.delete()

  var appState = state.newAppState()
  echo appState.title

  status.init(appState)

  status_test.setupNewAccount()
  discard status_test.addPeer("enode://2c8de3cbb27a3d30cbb5b3e003bc722b126f5aef82e2052aaef032ca94e0c7ad219e533ba88c70585ebd802de206693255335b100307645ab5170e88620d2a81@47.244.221.14:443")
  echo status.callPrivateRPC("{\"jsonrpc\":\"2.0\", \"method\":\"wakuext_requestMessages\", \"params\":[{\"topics\": [\"0x7998f3c8\"]}], \"id\": 1}")

  let applicationView = newApplicationView(app)
  defer: applicationView.delete

  status.startMessenger()

  var wallet = wallet.newController()
  wallet.init()
  engine.setRootContextProperty("assetsModel", wallet.variant)

  var chat = chat.newController()
  chat.init()
  engine.setRootContextProperty("chatsModel", chat.variant)

  var node = node.newController()
  node.init()
  engine.setRootContextProperty("nodeModel", node.variant)

  engine.load("../ui/main.qml")

  appState.subscribe(proc () =
    # chatsModel.names = @[]
    for channel in appState.channels:
      echo channel.name
      # chatsModel.addNameTolist(channel.name)
      chat.join(channel.name)
  )

  appState.addChannel("test")
  appState.addChannel("test2")

  # EXAMPLE: this will be triggered once a message is received
  appState.onSignal(SignalType.Message, proc(myMessage: string): void =
    echo "I received a message: ", myMessage
  );

  # Handle signals as part of the state
  var signalWorker: Thread[AppState]
  signalWorker.createThread(proc(s:AppState) = s.processSignals, appState)
  defer: signalWorker.joinThread()

  # Qt main event loop is entered here
  # The termination of the loop will be performed when exit() or quit() is called
  app.exec()

when isMainModule:
  mainProc()
  GC_fullcollect()
