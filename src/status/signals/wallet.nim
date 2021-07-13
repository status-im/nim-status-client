import json
import types

proc fromEvent*(jsonSignal: JsonNode): Signal = 
  var signal:WalletSignal = WalletSignal()
  signal.content = $jsonSignal  
  if jsonSignal["event"].kind != JNull:
    signal.eventType = jsonSignal["event"]["type"].getStr
    signal.blockNumber = jsonSignal["event"]{"blockNumber"}.getInt
    signal.baseFeePerGas = jsonSignal["event"]{"baseFeePerGas"}.getStr
    signal.erc20 = jsonSignal["event"]{"erc20"}.getBool
    signal.accounts = @[]
    if jsonSignal["event"]["accounts"].kind != JNull:
      for account in jsonSignal["event"]["accounts"]:
        signal.accounts.add(account.getStr)
  result = signal
  