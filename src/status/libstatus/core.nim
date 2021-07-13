import json, nimcrypto, chronicles
import status_go, ../utils

logScope:
  topics = "rpc"

proc callRPC*(inputJSON: string): string =
  return $status_go.callRPC(inputJSON)

proc callPrivateRPCRaw*(inputJSON: string): string =
  return $status_go.callPrivateRPC(inputJSON)

proc callPrivateRPC*(methodName: string, payload = %* []): string =
  try:
    let inputJSON = %* {
      "jsonrpc": "2.0",
      "method": methodName,
      "params": %payload
    }
    debug "callPrivateRPC", rpc_method=methodName
    let response = status_go.callPrivateRPC($inputJSON)
    result = $response
    if parseJSON(result).hasKey("error"):
      writeStackTrace()
      error "rpc response error", result, payload, methodName
  except Exception as e:
    error "error doing rpc request", methodName = methodName, exception=e.msg

proc sendTransaction*(inputJSON: string, password: string): string =
  var hashed_password = "0x" & $keccak_256.digest(password)
  return $status_go.sendTransaction(inputJSON, hashed_password)

proc startMessenger*() =
  discard callPrivateRPC("startMessenger".prefix)

proc addPeer*(peer: string) =
  discard callPrivateRPC("admin_addPeer", %* [peer])

proc removePeer*(peer: string) =
  discard callPrivateRPC("admin_removePeer", %* [peer])

proc markTrustedPeer*(peer: string) =
  discard callPrivateRPC("markTrustedPeer".prefix(false), %* [peer])

proc getContactByID*(id: string): string =
  result = callPrivateRPC("getContactByID".prefix, %* [id])

proc getBlockByNumber*(blockNumber: string): string =
  result = callPrivateRPC("eth_getBlockByNumber", %* [blockNumber, false])

proc getTransfersByAddress*(address: string, toBlock: string, limit: string, fetchMore: bool = false): string =
  let toBlockParsed = if not fetchMore: newJNull() else: %toBlock
  result = callPrivateRPC("wallet_getTransfersByAddress", %* [address, toBlockParsed, limit, fetchMore])

proc signMessage*(rpcParams: string): string =
  return $status_go.signMessage(rpcParams)

proc signTypedData*(data: string, address: string, password: string): string =
  return $status_go.signTypedData(data, address, password)
