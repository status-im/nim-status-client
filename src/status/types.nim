import json, options, typetraits, tables, sequtils, strutils
import web3/ethtypes, json_serialization, stint
import libstatus/accounts/constants
import ../eventemitter

type SignalType* {.pure.} = enum
  Message = "messages.new"
  Wallet = "wallet"
  NodeReady = "node.ready"
  NodeCrashed = "node.crashed"
  NodeStarted = "node.started"
  NodeStopped = "node.stopped"
  NodeLogin = "node.login"
  EnvelopeSent = "envelope.sent"
  EnvelopeExpired = "envelope.expired"
  MailserverRequestCompleted = "mailserver.request.completed"
  MailserverRequestExpired = "mailserver.request.expired"
  DiscoveryStarted = "discovery.started"
  DiscoveryStopped = "discovery.stopped"
  DiscoverySummary = "discovery.summary"
  SubscriptionsData = "subscriptions.data"
  SubscriptionsError = "subscriptions.error"
  WhisperFilterAdded = "whisper.filter.added"
  CommunityFound = "community.found"
  Unknown

proc event*(self:SignalType):string =
  result = "signal:" & $self

type GasPricePrediction* = object
  safeLow*: float
  standard*: float
  fast*: float
  fastest*: float

type DerivedAccount* = object
  publicKey*: string
  address*: string
  derivationPath*: string

type MultiAccounts* = object
  whisper* {.serializedFieldName(PATH_WHISPER).}: DerivedAccount
  walletRoot* {.serializedFieldName(PATH_WALLET_ROOT).}: DerivedAccount
  defaultWallet* {.serializedFieldName(PATH_DEFAULT_WALLET).}: DerivedAccount
  eip1581* {.serializedFieldName(PATH_EIP_1581).}: DerivedAccount

type
  IdentityImage* = ref object
    thumbnail*: string
    large*: string

type
  Account* = ref object of RootObj
    name*: string
    keyUid* {.serializedFieldName("key-uid").}: string
    identityImage*: IdentityImage
    identicon*: string

type
  NodeAccount* = ref object of Account
    timestamp*: int
    keycardPairing* {.serializedFieldName("keycard-pairing").}: string

type
  GeneratedAccount* = ref object
    publicKey*: string
    address*: string
    id*: string
    mnemonic*: string
    derived*: MultiAccounts
    # FIXME: should inherit from Account but multiAccountGenerateAndDeriveAddresses
    # response has a camel-cased properties like "publicKey" and "keyUid", so the
    # serializedFieldName pragma would need to be different
    name*: string
    keyUid*: string
    identicon*: string
    identityImage*: IdentityImage

type RpcError* = ref object
  code*: int
  message*: string

type
  RpcResponse* = ref object
    jsonrpc*: string
    result*: string
    id*: int
    error*: RpcError
  # TODO: replace all RpcResponse and RpcResponseTyped occurances with a generic
  # form of RpcReponse. IOW, rename RpceResponseTyped*[T] to RpcResponse*[T] and
  # remove RpcResponse.
  RpcResponseTyped*[T] = object
    jsonrpc*: string
    result*: T
    id*: int
    error*: RpcError

proc toAccount*(account: GeneratedAccount): Account =
  result = Account(name: account.name, identityImage: account.identityImage, identicon: account.identicon, keyUid: account.keyUid)

proc toAccount*(account: NodeAccount): Account =
  result = Account(name: account.name, identityImage: account.identityImage, identicon: account.identicon, keyUid: account.keyUid)

type AccountArgs* = ref object of Args
    account*: Account

type
  StatusGoException* = object of CatchableError

type
  Transaction* = ref object
    id*: string
    typeValue*: string
    address*: string
    blockNumber*: string
    blockHash*: string
    contract*: string
    timestamp*: string
    gasPrice*: string
    gasLimit*: string
    gasUsed*: string
    nonce*: string
    txStatus*: string
    value*: string
    fromAddress*: string
    to*: string
  
type 
  TransactionData* = object
    source*: Address             # the address the transaction is send from.
    to*: Option[Address]         # (optional when creating new contract) the address the transaction is directed to.
    gas*: Option[Quantity]            # (optional, default: 90000) integer of the gas provided for the transaction execution. It will return unused gas.
    gasPrice*: Option[int]       # (optional, default: To-Be-Determined) integer of the gasPrice used for each paid gas.
    value*: Option[Uint256]          # (optional) integer of the value sent with this transaction.
    data*: string                # the compiled code of a contract OR the hash of the invoked method signature and encoded parameters. For details see Ethereum Contract ABI.
    nonce*: Option[Nonce]        # (optional) integer of a nonce. This allows to overwrite your own pending transactions that use the same nonce
    

proc cmpTransactions*(x, y: Transaction): int =
  # Sort proc to compare transactions from a single account.
  # Compares first by block number, then by nonce
  result = cmp(x.blockNumber.parseHexInt, y.blockNumber.parseHexInt)
  if result == 0:
    result = cmp(x.nonce, y.nonce)

type
  RpcException* = object of CatchableError

type Sticker* = object
  hash*: string
  packId*: int

type StickerPack* = object
  author*: string
  id*: int
  name*: string
  price*: Stuint[256]
  preview*: string
  stickers*: seq[Sticker]
  thumbnail*: string

proc `%`*(stuint256: Stuint[256]): JsonNode =
  newJString($stuint256)

proc readValue*(reader: var JsonReader, value: var Stuint[256])
               {.raises: [IOError, SerializationError, Defect].} =
  try:
    let strVal = reader.readValue(string)
    value = strVal.parse(Stuint[256])
  except:
    try:
      let intVal = reader.readValue(int)
      value = intVal.stuint(256)
    except:
      raise newException(SerializationError, "Expected string or int representation of Stuint[256]")

type
  Network* {.pure.} = enum
    Mainnet = "mainnet_rpc",
    Testnet = "testnet_rpc",
    Rinkeby = "rinkeby_rpc",
    Goerli = "goerli_rpc",
    XDai = "xdai_rpc",
    Poa = "poa_rpc",
    Other = "other"

  Setting* {.pure.} = enum
    Appearance = "appearance",
    Bookmarks = "bookmarks",
    Currency = "currency"
    EtherscanLink = "etherscan-link"
    InstallationId = "installation-id"
    MessagesFromContactsOnly = "messages-from-contacts-only"
    Mnemonic = "mnemonic"
    Networks_Networks = "networks/networks"
    Networks_CurrentNetwork = "networks/current-network"
    NodeConfig = "node-config"
    PublicKey = "public-key"
    DappsAddress = "dapps-address"
    Stickers_PacksInstalled = "stickers/packs-installed"
    Stickers_Recent = "stickers/recent-stickers"
    WalletRootAddress = "wallet-root-address"
    LatestDerivedPath = "latest-derived-path"
    PreferredUsername = "preferred-name"
    Usernames = "usernames"
    SigningPhrase = "signing-phrase"
    Fleet = "fleet"
    VisibleTokens = "wallet/visible-tokens"
    PinnedMailservers = "pinned-mailservers"

  UpstreamConfig* = ref object
    enabled* {.serializedFieldName("Enabled").}: bool
    url* {.serializedFieldName("URL").}: string

  NodeConfig* = ref object
    networkId* {.serializedFieldName("NetworkId").}: int
    dataDir* {.serializedFieldName("DataDir").}: string
    upstreamConfig* {.serializedFieldName("UpstreamConfig").}: UpstreamConfig

  NetworkDetails* = ref object
    id*: string
    name*: string
    etherscanLink* {.serializedFieldName("etherscan-link").}: string
    config*: NodeConfig

type PendingTransactionType* {.pure.} = enum
  RegisterENS = "RegisterENS",
  SetPubKey = "SetPubKey",
  ReleaseENS = "ReleaseENS",
  BuyStickerPack = "BuyStickerPack"
  WalletTransfer = "WalletTransfer" 

type Bookmark* = ref object
  name*: string
  url*: string
  imageUrl*: string

type
  Fleet* {.pure.} = enum
    Prod = "eth.prod",
    Staging = "eth.staging",
    Test = "eth.test",
    WakuV2Test = "wakuv2.test"

  FleetNodes* {.pure.} = enum
    Bootnodes = "boot",
    Mailservers = "mail",
    Rendezvous = "rendezvous",
    Whisper = "whisper",
    Waku = "waku"

  FleetMeta* = object
    hostname*: string
    timestamp*: uint64

  FleetConfig* = object
    fleet*: Table[string, Table[string, Table[string, string]]]
    meta*: FleetMeta


proc toFleetConfig*(jsonString: string): FleetConfig =
  let fleetJson = jsonString.parseJSON
  result.meta.hostname = fleetJson["meta"]["hostname"].getStr
  result.meta.timestamp = fleetJson["meta"]["timestamp"].getBiggestInt.uint64
  result.fleet = initTable[string, Table[string, Table[string, string]]]()

  for fleet in fleetJson["fleets"].keys():
    result.fleet[fleet] = initTable[string, Table[string, string]]()
    for nodes in fleetJson["fleets"][fleet].keys():
      result.fleet[fleet][nodes] = initTable[string, string]()
      for server in fleetJson["fleets"][fleet][nodes].keys():
        result.fleet[fleet][nodes][server] = fleetJson["fleets"][fleet][nodes][server].getStr


proc getNodes*(self: FleetConfig, fleet: Fleet, nodeType: FleetNodes = FleetNodes.Bootnodes): seq[string] =
  result = toSeq(self.fleet[$fleet][$nodeType].values)

proc getMailservers*(self: FleetConfig, fleet: Fleet): Table[string, string] =
  result = self.fleet[$fleet][$FleetNodes.Mailservers]

