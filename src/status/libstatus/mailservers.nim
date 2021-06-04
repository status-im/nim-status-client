import json, times
import core, utils

proc ping*(mailservers: seq[string], timeoutMs: int): string =
  var addresses: seq[string] = @[]
  for mailserver in mailservers:
    addresses.add(mailserver)
  result = callPrivateRPC("mailservers_ping", %* [
    { "addresses": addresses, "timeoutMs": timeoutMs }
  ])

proc update*(peer: string) =
  discard callPrivateRPC("updateMailservers".prefix, %* [[peer]])

proc delete*(peer: string) =
  discard callPrivateRPC("mailservers_deleteMailserver", %* [peer])

proc requestAllHistoricMessages*(): string =
  return callPrivateRPC("requestAllHistoricMessages".prefix, %*[])

proc requestStoreMessages*(topics: seq[string], symKeyID: string, peer: string, numberOfMessages: int, fromTimestamp: int64 = 0, toTimestamp: int64 = 0, force: bool = false) =
  var toValue = times.toUnix(times.getTime())
  var fromValue = toValue - 86400
  if fromTimestamp != 0:
    fromValue = fromTimestamp
  if toTimestamp != 0:
    toValue = toTimestamp

  echo callPrivateRPC("requestMessages".prefix, %* [
    {
        "topics": topics,
        "mailServerPeer": "16Uiu2HAmVVi6Q4j7MAKVibquW8aA27UNrA4Q8Wkz9EetGViu8ZF1",
        "timeout": 30,
        "limit": numberOfMessages,
        "cursor": nil,
        "from": fromValue,
        "to": toValue,
        "force": force
    }
  ])

proc syncChatFromSyncedFrom*(chatId: string): string =
  return callPrivateRPC("syncChatFromSyncedFrom".prefix, %*[chatId])

proc fillGaps*(chatId: string, messageIds: seq[string]): string =
  return callPrivateRPC("fillGaps".prefix, %*[chatId, messageIds])
