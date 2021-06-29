import ens, chat/stickers, wallet, settings, permissions
import ../eventemitter
import types
import libstatus/accounts
import libstatus/core
import libstatus/settings as status_settings
import json, json_serialization, sets, strutils
import chronicles
import nbaser
import stew/byteutils
from base32 import nil

const HTTPS_SCHEME* = "https"
const IPFS_GATEWAY* =  ".infura.status.im"
const SWARM_GATEWAY* = "swarm-gateways.net"

const base58* = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

logScope:
  topics = "provider-model"

type
  RequestTypes {.pure.} = enum
    Web3SendAsyncReadOnly = "web3-send-async-read-only",
    HistoryStateChanged = "history-state-changed",
    APIRequest = "api-request"
    Unknown = "unknown"

  ResponseTypes {.pure.} = enum
    Web3SendAsyncCallback = "web3-send-async-callback",
    APIResponse = "api-response",
    Web3ResponseError = "web3-response-error"

type
  Payload = ref object
    id: JsonNode
    rpcMethod: string

  Web3SendAsyncReadOnly = ref object
    messageId: JsonNode
    payload: Payload
    request: string
    hostname: string

  APIRequest = ref object
    isAllowed: bool
    messageId: JsonNode
    permission: Permission
    hostname: string

const AUTH_METHODS = toHashSet(["eth_accounts", "eth_coinbase", "eth_sendTransaction", "eth_sign", "keycard_signTypedData", "eth_signTypedData", "eth_signTypedData_v3", "personal_sign", "personal_ecRecover"])
const SIGN_METHODS = toHashSet(["eth_sign", "personal_sign", "eth_signTypedData", "eth_signTypedData_v3"])
const ACC_METHODS = toHashSet(["eth_accounts", "eth_coinbase"])

type ProviderModel* = ref object
  events*: EventEmitter
  permissions*: PermissionsModel

proc newProviderModel*(events: EventEmitter, permissions: PermissionsModel): ProviderModel =
  result = ProviderModel()
  result.events = events
  result.permissions = permissions

proc requestType(message: string): RequestTypes = 
  let data = message.parseJson
  result = RequestTypes.Unknown
  try:
    result = parseEnum[RequestTypes](data["type"].getStr())
  except:
    warn "Unknown request type received", value=data["permission"].getStr()

proc toWeb3SendAsyncReadOnly(message: string): Web3SendAsyncReadOnly =
  let data = message.parseJson
  result = Web3SendAsyncReadOnly(
    messageId: data["messageId"],
    request: $data["payload"],
    hostname: data{"hostname"}.getStr(),
    payload: Payload(
      id: data["payload"]{"id"},
      rpcMethod: data["payload"]["method"].getStr()
    )
  )

proc toAPIRequest(message: string): APIRequest = 
  let data = message.parseJson

  result = APIRequest(
    messageId: data["messageId"],
    isAllowed: data{"isAllowed"}.getBool(),
    permission: data["permission"].getStr().toPermission(),
    hostname: data{"hostname"}.getStr()
  )

proc process(self: ProviderModel, data: Web3SendAsyncReadOnly): string =
  if AUTH_METHODS.contains(data.payload.rpcMethod) and not self.permissions.hasPermission(data.hostname, Permission.Web3):
    return $ %* {
      "type": ResponseTypes.Web3SendAsyncCallback,
      "messageId": data.messageId,
      "error": {
        "code": 4100
      }
    }
  
  if data.payload.rpcMethod == "eth_sendTransaction":
    try:
      let request = data.request.parseJson
      let fromAddress = request["params"][0]["from"].getStr()
      let to = request["params"][0]{"to"}.getStr()
      let value = if (request["params"][0]["value"] != nil):
        request["params"][0]["value"].getStr()
      else:
        "0"
      let password = request["password"].getStr()
      let selectedGasLimit = request["selectedGasLimit"].getStr()
      let selectedGasPrice = request["selectedGasPrice"].getStr()
      let txData = if (request["params"][0].hasKey("data") and request["params"][0]["data"].kind != JNull):
        request["params"][0]["data"].getStr()
      else:
        ""

      var success: bool
      # TODO make this async
      let response = wallet.sendTransaction(fromAddress, to, value, selectedGasLimit, selectedGasPrice, password, success, txData)
      let errorMessage = if not success:
        if response == "":
          "web3-response-error"
        else:
          response
      else:
        ""

      return $ %* {
        "type": ResponseTypes.Web3SendAsyncCallback,
        "messageId": data.messageId,
        "error": errorMessage,
        "result": {
          "jsonrpc": "2.0",
          "id": data.payload.id,
          "result": if (success): response else: ""
        }
      }
    except Exception as e:
      error "Error sending the transaction", msg = e.msg
      return $ %* {
        "type": ResponseTypes.Web3SendAsyncCallback,
        "messageId": data.messageId,
        "error": {
          "code": 4100,
          "message": e.msg
        }
      }

  if SIGN_METHODS.contains(data.payload.rpcMethod):
    try: 
      let request = data.request.parseJson
      var params = request["params"]
      let password = hashPassword(request["password"].getStr())
      let dappAddress = status_settings.getSetting[string](Setting.DappsAddress)
      var rpcResult = "{}"

      case data.payload.rpcMethod:
        of "eth_signTypedData", "eth_signTypedData_v3":
          rpcResult = signTypedData(params[1].getStr(), dappAddress, password)
        else:
          rpcResult = signMessage($ %* {
            "data": params[0].getStr(),
            "password": password,
            "account": dappAddress
          })
      
      let jsonRpcResult = rpcResult.parseJson
      let success: bool = not jsonRpcResult.hasKey("error")
      let errorMessage = if success: "" else: jsonRpcResult["error"]{"message"}.getStr()
      let response = if success: jsonRpcResult["result"].getStr() else: ""

      return $ %* {
        "type": ResponseTypes.Web3SendAsyncCallback,
        "messageId": data.messageId,
        "error": errorMessage,
        "result": {
          "jsonrpc": "2.0",
          "id": if data.payload.id == nil: newJNull() else: data.payload.id,
          "result": if (success): response else: ""
        }
      }

    except Exception as e:
        error "Error signing message", msg = e.msg
        return $ %* {
          "type": ResponseTypes.Web3SendAsyncCallback,
          "messageId": data.messageId,
          "error": {
            "code": 4100,
            "message": e.msg
          }
        }


  
  if ACC_METHODS.contains(data.payload.rpcMethod):
      let dappAddress = status_settings.getSetting[string](Setting.DappsAddress)
      return $ %* {
        "type": ResponseTypes.Web3SendAsyncCallback,
        "messageId": data.messageId,
        "result": {
          "jsonrpc": "2.0",
          "id": data.payload.id,
          "result": if data.payload.rpcMethod == "eth_coinbase": newJString(dappAddress) else: %*[dappAddress]
          }
        }
  
  let rpcResult = callRPC(data.request)

  return $ %* {
    "type": ResponseTypes.Web3SendAsyncCallback,
    "messageId": data.messageId,
    "error": (if rpcResult == "": newJString("web3-response-error") else: newJNull()),
    "result": rpcResult.parseJson
  }

proc process*(self: ProviderModel, data: APIRequest): string =   
  var value:JsonNode = case data.permission
  of Permission.Web3: %* [status_settings.getSetting[string](Setting.DappsAddress, "0x0000000000000000000000000000000000000000")]
  of Permission.ContactCode: %* status_settings.getSetting[string](Setting.PublicKey, "0x0")
  of Permission.Unknown: newJNull()

  let isAllowed = data.isAllowed and data.permission != Permission.Unknown

  info "API request received", host=data.hostname, value=data.permission, isAllowed

  if isAllowed: self.permissions.addPermission(data.hostname, data.permission)

  return $ %* {
    "type": ResponseTypes.APIResponse,
    "isAllowed": isAllowed,
    "permission": data.permission,
    "messageId": data.messageId,
    "data": value
  }

proc postMessage*(self: ProviderModel, message: string): string =
    case message.requestType():
    of RequestTypes.Web3SendAsyncReadOnly: self.process(message.toWeb3SendAsyncReadOnly())
    of RequestTypes.HistoryStateChanged: """{"type":"TODO-IMPLEMENT-THIS"}""" ############# TODO:
    of RequestTypes.APIRequest: self.process(message.toAPIRequest())
    else:  """{"type":"TODO-IMPLEMENT-THIS"}""" ##################### TODO:

proc ensResourceURL*(self: ProviderModel, ens: string, url: string): (string, string, string, string, bool) =
    let contentHash = contenthash(ens)
    if contentHash == "": # ENS does not have a content hash
      return (url, url, HTTPS_SCHEME, "", false)

    let decodedHash = contentHash.decodeENSContentHash()
    case decodedHash[0]:
    of ENSType.IPFS:
      let base32Hash = base32.encode(string.fromBytes(base58.decode(decodedHash[1]))).toLowerAscii().replace("=", "")
      result = (url, base32Hash & IPFS_GATEWAY, HTTPS_SCHEME, "", true)
    of ENSType.SWARM:
      result = (url, SWARM_GATEWAY, HTTPS_SCHEME, "/bzz:/" & decodedHash[1] & "/", true)
    of ENSType.IPNS:
      result = (url, decodedHash[1], HTTPS_SCHEME, "", true)
    else: 
      warn "Unknown content for", ens, contentHash
