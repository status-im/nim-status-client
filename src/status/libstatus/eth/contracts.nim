import
  sequtils, sugar, macros, tables, strutils

import
  web3/ethtypes, stew/byteutils, nimcrypto, json_serialization, chronicles

import
  ../types, ../settings, ../coder, transactions, methods, ../utils

export
  GetPackData, PackData, BuyToken, ApproveAndCall, Transfer, BalanceOf, Register, SetPubkey,
  TokenOfOwnerByIndex, TokenPackId, TokenUri, FixedBytes, DynamicBytes, toHex, fromHex,
  decodeContractResponse, encodeAbi, estimateGas, send, call


logScope:
  topics = "contracts"

const ERC20_METHODS = @[
  ("name", Method(signature: "name()")),
  ("symbol", Method(signature: "symbol()")),
  ("decimals", Method(signature: "decimals()")),
  ("totalSupply", Method(signature: "totalSupply()")),
  ("balanceOf", Method(signature: "balanceOf(address)")),
  ("transfer", Method(signature: "transfer(address,uint256)")),
  ("allowance", Method(signature: "allowance(address,address)")),
  ("approve", Method(signature: "approve(address,uint256)")),
  ("transferFrom", Method(signature: "approve(address,address,uint256)")),
  ("increaseAllowance", Method(signature: "increaseAllowance(address,uint256)")),
  ("decreaseAllowance", Method(signature: "decreaseAllowance(address,uint256)")),
  ("approveAndCall", Method(signature: "approveAndCall(address,uint256,bytes)"))
]

const ERC721_ENUMERABLE_METHODS = @[
  ("balanceOf", Method(signature: "balanceOf(address)")),
  ("ownerOf", Method(signature: "ownerOf(uint256)")),
  ("name", Method(signature: "name()")),
  ("symbol", Method(signature: "symbol()")),
  ("tokenURI", Method(signature: "tokenURI(uint256)")),
  ("baseURI", Method(signature: "baseURI()")),
  ("tokenOfOwnerByIndex", Method(signature: "tokenOfOwnerByIndex(address,uint256)")),
  ("totalSupply", Method(signature: "totalSupply()")),
  ("tokenByIndex", Method(signature: "tokenByIndex(uint256)")),
  ("approve", Method(signature: "approve(address,uint256)")),
  ("getApproved", Method(signature: "getApproved(uint256)")),
  ("setApprovalForAll", Method(signature: "setApprovalForAll(address,bool)")),
  ("isApprovedForAll", Method(signature: "isApprovedForAll(address,address)")),
  ("transferFrom", Method(signature: "transferFrom(address,address,uint256)")),
  ("safeTransferFrom", Method(signature: "safeTransferFrom(address,address,uint256)")),
  ("safeTransferFromWithData", Method(signature: "safeTransferFrom(address,address,uint256,bytes)"))
]

type
  Contract* = ref object of RootObj
    name*: string
    network*: Network
    address*: Address
    methods* {.dontSerialize.}: Table[string, Method]
 
  Erc20Contract* = ref object of Contract
    symbol*: string
    decimals*: int
    hasIcon* {.dontSerialize.}: bool
    color*: string

  Erc721Contract* = ref object of Contract
    symbol*: string
    hasIcon*: bool

proc newErc20Contract*(name: string, network: Network, address: Address, symbol: string, decimals: int, hasIcon: bool): Erc20Contract =
  Erc20Contract(name: name, network: network, address: address, methods: ERC20_METHODS.toTable, symbol: symbol, decimals: decimals, hasIcon: hasIcon)

proc newErc20Contract*(network: Network, address: Address): Erc20Contract =
  Erc20Contract(name: "", network: network, address: address, methods: ERC20_METHODS.toTable, symbol: "", decimals: 0, hasIcon: false)

proc newErc721Contract(name: string, network: Network, address: Address, symbol: string, hasIcon: bool, addlMethods: seq[tuple[name: string, meth: Method]] = @[]): Erc721Contract =
  Erc721Contract(name: name, network: network, address: address, symbol: symbol, hasIcon: hasIcon, methods: ERC721_ENUMERABLE_METHODS.concat(addlMethods).toTable)


var 
  contracts {.threadvar.}: seq[Contract]
  contractsInited {.threadvar.}: bool
proc allContracts(): seq[Contract] =
  if contractsInited:
    result = contracts
  else:
    contracts = @[
      # Mainnet contracts
      newErc20Contract("Status Network Token", Network.Mainnet, parseAddress("0x744d70fdbe2ba4cf95131626614a1763df805b9e"), "SNT", 18, true),
      newErc20Contract("Dai Stablecoin", Network.Mainnet, parseAddress("0x6b175474e89094c44da98b954eedeac495271d0f"), "DAI", 18, true),
      newErc20Contract("Sai Stablecoin v1.0", Network.Mainnet, parseAddress("0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"), "SAI", 18, true),
      newErc20Contract("MKR", Network.Mainnet, parseAddress("0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2"), "MKR", 18, true),
      newErc20Contract("EOS", Network.Mainnet, parseAddress("0x86fa049857e0209aa7d9e616f7eb3b3b78ecfdb0"), "EOS", 18, true),
      newErc20Contract("OMGToken", Network.Mainnet, parseAddress("0xd26114cd6ee289accf82350c8d8487fedb8a0c07"), "OMG", 18, true),
      newErc20Contract("Populous Platform", Network.Mainnet, parseAddress("0xd4fa1460f537bb9085d22c7bccb5dd450ef28e3a"), "PPT", 8, true),
      newErc20Contract("Reputation", Network.Mainnet, parseAddress("0x1985365e9f78359a9b6ad760e32412f4a445e862"), "REP", 18, true),
      newErc20Contract("PowerLedger", Network.Mainnet, parseAddress("0x595832f8fc6bf59c85c527fec3740a1b7a361269"), "POWR", 6, true),
      newErc20Contract("TenX Pay Token", Network.Mainnet, parseAddress("0xb97048628db6b661d4c2aa833e95dbe1a905b280"), "PAY", 18, true),
      newErc20Contract("Veros", Network.Mainnet, parseAddress("0x92e78dae1315067a8819efd6dca432de9dcde2e9"), "VRS", 6, false),
      newErc20Contract("Golem Network Token", Network.Mainnet, parseAddress("0xa74476443119a942de498590fe1f2454d7d4ac0d"), "GNT", 18, true),
      newErc20Contract("Salt", Network.Mainnet, parseAddress("0x4156d3342d5c385a87d264f90653733592000581"), "SALT", 8, true),
      newErc20Contract("BNB", Network.Mainnet, parseAddress("0xb8c77482e45f1f44de1745f52c74426c631bdd52"), "BNB", 18, true),
      newErc20Contract("Basic Attention Token", Network.Mainnet, parseAddress("0x0d8775f648430679a709e98d2b0cb6250d2887ef"), "BAT", 18, true),
      newErc20Contract("Kyber Network Crystal", Network.Mainnet, parseAddress("0xdd974d5c2e2928dea5f71b9825b8b646686bd200"), "KNC", 18, true),
      newErc20Contract("BTU Protocol", Network.Mainnet, parseAddress("0xb683D83a532e2Cb7DFa5275eED3698436371cc9f"), "BTU", 18, true),
      newErc20Contract("Digix DAO", Network.Mainnet, parseAddress("0xe0b7927c4af23765cb51314a0e0521a9645f0e2a"), "DGD", 9, true),
      newErc20Contract("Aeternity", Network.Mainnet, parseAddress("0x5ca9a71b1d01849c0a95490cc00559717fcf0d1d"), "AE", 18, true),
      newErc20Contract("Tronix", Network.Mainnet, parseAddress("0xf230b790e05390fc8295f4d3f60332c93bed42e2"), "TRX", 6, true),
      newErc20Contract("Ethos", Network.Mainnet, parseAddress("0x5af2be193a6abca9c8817001f45744777db30756"), "ETHOS", 8, true),
      newErc20Contract("Raiden Token", Network.Mainnet, parseAddress("0x255aa6df07540cb5d3d297f0d0d4d84cb52bc8e6"), "RDN", 18, true),
      newErc20Contract("SingularDTV", Network.Mainnet, parseAddress("0xaec2e87e0a235266d9c5adc9deb4b2e29b54d009"), "SNGLS", 0, true),
      newErc20Contract("Gnosis Token", Network.Mainnet, parseAddress("0x6810e776880c02933d47db1b9fc05908e5386b96"), "GNO", 18, true),
      newErc20Contract("StorjToken", Network.Mainnet, parseAddress("0xb64ef51c888972c908cfacf59b47c1afbc0ab8ac"), "STORJ", 8, true),
      newErc20Contract("AdEx", Network.Mainnet, parseAddress("0x4470bb87d77b963a013db939be332f927f2b992e"), "ADX", 4, false),
      newErc20Contract("FunFair", Network.Mainnet, parseAddress("0x419d0d8bdd9af5e606ae2232ed285aff190e711b"), "FUN", 8, true),
      newErc20Contract("Civic", Network.Mainnet, parseAddress("0x41e5560054824ea6b0732e656e3ad64e20e94e45"), "CVC", 8, true),
      newErc20Contract("ICONOMI", Network.Mainnet, parseAddress("0x888666ca69e0f178ded6d75b5726cee99a87d698"), "ICN", 18, true),
      newErc20Contract("Walton Token", Network.Mainnet, parseAddress("0xb7cb1c96db6b22b0d3d9536e0108d062bd488f74"), "WTC", 18, true),
      newErc20Contract("Bytom", Network.Mainnet, parseAddress("0xcb97e65f07da24d46bcdd078ebebd7c6e6e3d750"), "BTM", 8, true),
      newErc20Contract("0x Protocol Token", Network.Mainnet, parseAddress("0xe41d2489571d322189246dafa5ebde1f4699f498"), "ZRX", 18, true),
      newErc20Contract("Bancor Network Token", Network.Mainnet, parseAddress("0x1f573d6fb3f13d689ff844b4ce37794d79a7ff1c"), "BNT", 18, true),
      newErc20Contract("Metal", Network.Mainnet, parseAddress("0xf433089366899d83a9f26a773d59ec7ecf30355e"), "MTL", 8, false),
      newErc20Contract("PayPie", Network.Mainnet, parseAddress("0xc42209accc14029c1012fb5680d95fbd6036e2a0"), "PPP", 18, true),
      newErc20Contract("ChainLink Token", Network.Mainnet, parseAddress("0x514910771af9ca656af840dff83e8264ecf986ca"), "LINK", 18, true),
      newErc20Contract("Kin", Network.Mainnet, parseAddress("0x818fc6c2ec5986bc6e2cbf00939d90556ab12ce5"), "KIN", 18, true),
      newErc20Contract("Aragon Network Token", Network.Mainnet, parseAddress("0x960b236a07cf122663c4303350609a66a7b288c0"), "ANT", 18, true),
      newErc20Contract("MobileGo Token", Network.Mainnet, parseAddress("0x40395044ac3c0c57051906da938b54bd6557f212"), "MGO", 8, true),
      newErc20Contract("Monaco", Network.Mainnet, parseAddress("0xb63b606ac810a52cca15e44bb630fd42d8d1d83d"), "MCO", 8, true),
      newErc20Contract("loopring", Network.Mainnet, parseAddress("0xef68e7c694f40c8202821edf525de3782458639f"), "LRC", 18, true),
      newErc20Contract("Zeus Shield Coin", Network.Mainnet, parseAddress("0x7a41e0517a5eca4fdbc7fbeba4d4c47b9ff6dc63"), "ZSC", 18, true),
      newErc20Contract("Streamr DATAcoin", Network.Mainnet, parseAddress("0x0cf0ee63788a0849fe5297f3407f701e122cc023"), "DATA", 18, true),
      newErc20Contract("Ripio Credit Network Token", Network.Mainnet, parseAddress("0xf970b8e36e23f7fc3fd752eea86f8be8d83375a6"), "RCN", 18, true),
      newErc20Contract("WINGS", Network.Mainnet, parseAddress("0x667088b212ce3d06a1b553a7221e1fd19000d9af"), "WINGS", 18, true),
      newErc20Contract("Edgeless", Network.Mainnet, parseAddress("0x08711d3b02c8758f2fb3ab4e80228418a7f8e39c"), "EDG", 0, true),
      newErc20Contract("Melon Token", Network.Mainnet, parseAddress("0xbeb9ef514a379b997e0798fdcc901ee474b6d9a1"), "MLN", 18, true),
      newErc20Contract("Moeda Loyalty Points", Network.Mainnet, parseAddress("0x51db5ad35c671a87207d88fc11d593ac0c8415bd"), "MDA", 18, true),
      newErc20Contract("PILLAR", Network.Mainnet, parseAddress("0xe3818504c1b32bf1557b16c238b2e01fd3149c17"), "PLR", 18, true),
      newErc20Contract("QRL", Network.Mainnet, parseAddress("0x697beac28b09e122c4332d163985e8a73121b97f"), "QRL", 8, true),
      newErc20Contract("Modum Token", Network.Mainnet, parseAddress("0x957c30ab0426e0c93cd8241e2c60392d08c6ac8e"), "MOD", 0, true),
      newErc20Contract("Token-as-a-Service", Network.Mainnet, parseAddress("0xe7775a6e9bcf904eb39da2b68c5efb4f9360e08c"), "TAAS", 6, true),
      newErc20Contract("GRID Token", Network.Mainnet, parseAddress("0x12b19d3e2ccc14da04fae33e63652ce469b3f2fd"), "GRID", 12, true),
      newErc20Contract("SANtiment network token", Network.Mainnet, parseAddress("0x7c5a0ce9267ed19b22f8cae653f198e3e8daf098"), "SAN", 18, true),
      newErc20Contract("SONM Token", Network.Mainnet, parseAddress("0x983f6d60db79ea8ca4eb9968c6aff8cfa04b3c63"), "SNM", 18, true),
      newErc20Contract("Request Token", Network.Mainnet, parseAddress("0x8f8221afbb33998d8584a2b05749ba73c37a938a"), "REQ", 18, true),
      newErc20Contract("Substratum", Network.Mainnet, parseAddress("0x12480e24eb5bec1a9d4369cab6a80cad3c0a377a"), "SUB", 2, true),
      newErc20Contract("Decentraland MANA", Network.Mainnet, parseAddress("0x0f5d2fb29fb7d3cfee444a200298f468908cc942"), "MANA", 18, true),
      newErc20Contract("AirSwap Token", Network.Mainnet, parseAddress("0x27054b13b1b798b345b591a4d22e6562d47ea75a"), "AST", 4, true),
      newErc20Contract("R token", Network.Mainnet, parseAddress("0x48f775efbe4f5ece6e0df2f7b5932df56823b990"), "R", 0, true),
      newErc20Contract("FirstBlood Token", Network.Mainnet, parseAddress("0xaf30d2a7e90d7dc361c8c4585e9bb7d2f6f15bc7"), "1ST", 18, true),
      newErc20Contract("Cofoundit", Network.Mainnet, parseAddress("0x12fef5e57bf45873cd9b62e9dbd7bfb99e32d73e"), "CFI", 18, true),
      newErc20Contract("Enigma", Network.Mainnet, parseAddress("0xf0ee6b27b759c9893ce4f094b49ad28fd15a23e4"), "ENG", 8, true),
      newErc20Contract("Amber Token", Network.Mainnet, parseAddress("0x4dc3643dbc642b72c158e7f3d2ff232df61cb6ce"), "AMB", 18, true),
      newErc20Contract("XPlay Token", Network.Mainnet, parseAddress("0x90528aeb3a2b736b780fd1b6c478bb7e1d643170"), "XPA", 18, true),
      newErc20Contract("Open Trading Network", Network.Mainnet, parseAddress("0x881ef48211982d01e2cb7092c915e647cd40d85c"), "OTN", 18, true),
      newErc20Contract("Trustcoin", Network.Mainnet, parseAddress("0xcb94be6f13a1182e4a4b6140cb7bf2025d28e41b"), "TRST", 6, true),
      newErc20Contract("Monolith TKN", Network.Mainnet, parseAddress("0xaaaf91d9b90df800df4f55c205fd6989c977e73a"), "TKN", 8, true),
      newErc20Contract("RHOC", Network.Mainnet, parseAddress("0x168296bb09e24a88805cb9c33356536b980d3fc5"), "RHOC", 8, true),
      newErc20Contract("Target Coin", Network.Mainnet, parseAddress("0xac3da587eac229c9896d919abc235ca4fd7f72c1"), "TGT", 1, false),
      newErc20Contract("Everex", Network.Mainnet, parseAddress("0xf3db5fa2c66b7af3eb0c0b782510816cbe4813b8"), "EVX", 4, true),
      newErc20Contract("ICOS", Network.Mainnet, parseAddress("0x014b50466590340d41307cc54dcee990c8d58aa8"), "ICOS", 6, true),
      newErc20Contract("district0x Network Token", Network.Mainnet, parseAddress("0x0abdace70d3790235af448c88547603b945604ea"), "DNT", 18, true),
      newErc20Contract("Dentacoin", Network.Mainnet, parseAddress("0x08d32b0da63e2c3bcf8019c9c5d849d7a9d791e6"), "٨", 0, false),
      newErc20Contract("Eidoo Token", Network.Mainnet, parseAddress("0xced4e93198734ddaff8492d525bd258d49eb388e"), "EDO", 18, true),
      newErc20Contract("BitDice", Network.Mainnet, parseAddress("0x29d75277ac7f0335b2165d0895e8725cbf658d73"), "CSNO", 8, false),
      newErc20Contract("Cobinhood Token", Network.Mainnet, parseAddress("0xb2f7eb1f2c37645be61d73953035360e768d81e6"), "COB", 18, true),
      newErc20Contract("Enjin Coin", Network.Mainnet, parseAddress("0xf629cbd94d3791c9250152bd8dfbdf380e2a3b9c"), "ENJ", 18, false),
      newErc20Contract("AVENTUS", Network.Mainnet, parseAddress("0x0d88ed6e74bbfd96b831231638b66c05571e824f"), "AVT", 18, false),
      newErc20Contract("Chronobank TIME", Network.Mainnet, parseAddress("0x6531f133e6deebe7f2dce5a0441aa7ef330b4e53"), "TIME", 8, false),
      newErc20Contract("Cindicator Token", Network.Mainnet, parseAddress("0xd4c435f5b09f855c3317c8524cb1f586e42795fa"), "CND", 18, true),
      newErc20Contract("Stox", Network.Mainnet, parseAddress("0x006bea43baa3f7a6f765f14f10a1a1b08334ef45"), "STX", 18, true),
      newErc20Contract("Xaurum", Network.Mainnet, parseAddress("0x4df812f6064def1e5e029f1ca858777cc98d2d81"), "XAUR", 8, true),
      newErc20Contract("Vibe", Network.Mainnet, parseAddress("0x2c974b2d0ba1716e644c1fc59982a89ddd2ff724"), "VIB", 18, true),
      newErc20Contract("PRG", Network.Mainnet, parseAddress("0x7728dfef5abd468669eb7f9b48a7f70a501ed29d"), "PRG", 6, false),
      newErc20Contract("Delphy Token", Network.Mainnet, parseAddress("0x6c2adc2073994fb2ccc5032cc2906fa221e9b391"), "DPY", 18, true),
      newErc20Contract("CoinDash Token", Network.Mainnet, parseAddress("0x2fe6ab85ebbf7776fee46d191ee4cea322cecf51"), "CDT", 18, true),
      newErc20Contract("Tierion Network Token", Network.Mainnet, parseAddress("0x08f5a9235b08173b7569f83645d2c7fb55e8ccd8"), "TNT", 8, true),
      newErc20Contract("DomRaiderToken", Network.Mainnet, parseAddress("0x9af4f26941677c706cfecf6d3379ff01bb85d5ab"), "DRT", 8, true),
      newErc20Contract("SPANK", Network.Mainnet, parseAddress("0x42d6622dece394b54999fbd73d108123806f6a18"), "SPANK", 18, true),
      newErc20Contract("Berlin Coin", Network.Mainnet, parseAddress("0x80046305aaab08f6033b56a360c184391165dc2d"), "BRLN", 18, true),
      newErc20Contract("USD//C", Network.Mainnet, parseAddress("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"), "USDC", 6, true),
      newErc20Contract("Livepeer Token", Network.Mainnet, parseAddress("0x58b6a8a3302369daec383334672404ee733ab239"), "LPT", 18, true),
      newErc20Contract("Simple Token", Network.Mainnet, parseAddress("0x2c4e8f2d746113d0696ce89b35f0d8bf88e0aeca"), "ST", 18, true),
      newErc20Contract("Wrapped BTC", Network.Mainnet, parseAddress("0x2260fac5e5542a773aa44fbcfedf7c193bc2c599"), "WBTC", 8, true),
      newErc20Contract("Bloom Token", Network.Mainnet, parseAddress("0x107c4504cd79c5d2696ea0030a8dd4e92601b82e"), "BLT", 18, true),
      Contract(name: "stickers", network: Network.Mainnet, address: parseAddress("0x0577215622f43a39f4bc9640806dfea9b10d2a36"),
        methods: [
          ("packCount", Method(signature: "packCount()")),
          ("getPackData", Method(signature: "getPackData(uint256)"))
        ].toTable
      ),
      Contract(name: "sticker-market", network: Network.Mainnet, address: parseAddress("0x12824271339304d3a9f7e096e62a2a7e73b4a7e7"),
        methods: [
          ("buyToken", Method(signature: "buyToken(uint256,address,uint256)"))
        ].toTable
      ),
      newErc721Contract("sticker-pack", Network.Mainnet, parseAddress("0x110101156e8F0743948B2A61aFcf3994A8Fb172e"), "PACK", false, @[("tokenPackId", Method(signature: "tokenPackId(uint256)"))]),
      # Strikers seems dead. Their website doesn't work anymore
      newErc721Contract("strikers", Network.Mainnet, parseAddress("0xdcaad9fd9a74144d226dbf94ce6162ca9f09ed7e"), "STRK", true),
      newErc721Contract("ethermon", Network.Mainnet, parseAddress("0xb2c0782ae4a299f7358758b2d15da9bf29e1dd99"), "EMONA", true),
      newErc721Contract("kudos", Network.Mainnet, parseAddress("0x2aea4add166ebf38b63d09a75de1a7b94aa24163"), "KDO", true),
      newErc721Contract("crypto-kitties", Network.Mainnet, parseAddress("0x06012c8cf97bead5deae237070f9587f8e7a266d"), "CK", true),
      Contract(name: "ens-usernames", network: Network.Mainnet, address: parseAddress("0xDB5ac1a559b02E12F29fC0eC0e37Be8E046DEF49"),
          methods: [
            ("register", Method(signature: "register(bytes32,address,bytes32,bytes32)")),
            ("getPrice", Method(signature: "getPrice()"))
          ].toTable
      ),
      Contract(name: "ens-resolver", network: Network.Mainnet, address: parseAddress("0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41"),
          methods: [
            ("setPubkey", Method(signature: "setPubkey(bytes32,bytes32,bytes32)"))
          ].toTable
      ),

      # Testnet (Ropsten) contracts
      newErc20Contract("Status Test Token", Network.Testnet, parseAddress("0xc55cf4b03948d7ebc8b9e8bad92643703811d162"), "STT", 18, true),
      newErc20Contract("Handy Test Token", Network.Testnet, parseAddress("0xdee43a267e8726efd60c2e7d5b81552dcd4fa35c"), "HND", 0, false),
      newErc20Contract("Lucky Test Token", Network.Testnet, parseAddress("0x703d7dc0bc8e314d65436adf985dda51e09ad43b"), "LXS", 2, false),
      newErc20Contract("Adi Test Token", Network.Testnet, parseAddress("0xe639e24346d646e927f323558e6e0031bfc93581"), "ADI", 7, false),
      newErc20Contract("Wagner Test Token", Network.Testnet, parseAddress("0x2e7cd05f437eb256f363417fd8f920e2efa77540"), "WGN", 10, false),
      newErc20Contract("Modest Test Token", Network.Testnet, parseAddress("0x57cc9b83730e6d22b224e9dc3e370967b44a2de0"), "MDS", 18, false),
      Contract(name: "tribute-to-talk", network: Network.Testnet, address: parseAddress("0xC61aa0287247a0398589a66fCD6146EC0F295432")),
      Contract(name: "stickers", network: Network.Testnet, address: parseAddress("0x8cc272396be7583c65bee82cd7b743c69a87287d"),
        methods: [
          ("packCount", Method(signature: "packCount()")),
          ("getPackData", Method(signature: "getPackData(uint256)"))
        ].toTable
      ),
      Contract(name: "sticker-market", network: Network.Testnet, address: parseAddress("0x6CC7274aF9cE9572d22DFD8545Fb8c9C9Bcb48AD"),
        methods: [
          ("buyToken", Method(signature: "buyToken(uint256,address,uint256)"))
        ].toTable
      ),
      newErc721Contract("sticker-pack", Network.Testnet, parseAddress("0xf852198d0385c4b871e0b91804ecd47c6ba97351"), "PACK", false, @[("tokenPackId", Method(signature: "tokenPackId(uint256)"))]),
      newErc721Contract("kudos", Network.Testnet, parseAddress("0xcd520707fc68d153283d518b29ada466f9091ea8"), "KDO", true),
      Contract(name: "ens-usernames", network: Network.Testnet, address: parseAddress("0x11d9F481effd20D76cEE832559bd9Aca25405841"),
          methods: [
            ("register", Method(signature: "register(bytes32,address,bytes32,bytes32)")),
            ("getPrice", Method(signature: "getPrice()"))
          ].toTable
      ),
      Contract(name: "ens-resolver", network: Network.Testnet, address: parseAddress("0x42D63ae25990889E35F215bC95884039Ba354115"),
          methods: [
            ("setPubkey", Method(signature: "setPubkey(bytes32,bytes32,bytes32)"))
          ].toTable
      ),

      # Rinkeby contracts
      newErc20Contract("Moksha Coin", Network.Rinkeby, parseAddress("0x6ba7dc8dd10880ab83041e60c4ede52bb607864b"), "MOKSHA", 18, false),
      newErc20Contract("WIBB", Network.Rinkeby, parseAddress("0x7d4ccf6af2f0fdad48ee7958bcc28bdef7b732c7"), "WIBB", 18, false),
      newErc20Contract("Status Test Token", Network.Rinkeby, parseAddress("0x43d5adc3b49130a575ae6e4b00dfa4bc55c71621"), "STT", 18, false),

      # xDai contracts
      newErc20Contract("buffiDai", Network.XDai, parseAddress("0x3e50bf6703fc132a94e4baff068db2055655f11b"), "BUFF", 18, false),

      newErc20Contract("Uniswap", Network.Mainnet, parseAddress("0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"), "UNI", 18, true),
      newErc20Contract("Compound", Network.Mainnet, parseAddress("0xc00e94cb662c3520282e6f5717214004a7f26888"), "COMP", 18, true),
      newErc20Contract("Balancer", Network.Mainnet, parseAddress("0xba100000625a3754423978a60c9317c58a424e3d"), "BAL", 18, true),
      newErc20Contract("Akropolis", Network.Mainnet, parseAddress("0x8ab7404063ec4dbcfd4598215992dc3f8ec853d7"), "AKRO", 18, true),
      newErc20Contract("Orchid", Network.Mainnet, parseAddress("0x4575f41308EC1483f3d399aa9a2826d74Da13Deb"), "OXT", 18, false),
    ]
    contractsInited = true
    result = contracts

proc getContract(network: Network, name: string): Contract =
  let found = allContracts().filter(contract => contract.name == name and contract.network == network)
  result = if found.len > 0: found[0] else: nil

proc getContract*(name: string): Contract =
  let network = settings.getCurrentNetwork()
  getContract(network, name)

proc getErc20ContractBySymbol*(contracts: seq[Erc20Contract], symbol: string): Erc20Contract =
  let found = contracts.filter(contract => contract.symbol.toLower == symbol.toLower)
  result = if found.len > 0: found[0] else: nil

proc getErc20ContractByAddress*(contracts: seq[Erc20Contract], address: Address): Erc20Contract =
  let found = contracts.filter(contract => contract.address == address)
  result = if found.len > 0: found[0] else: nil

proc getErc20Contract*(symbol: string): Erc20Contract =
  let network = settings.getCurrentNetwork()
  result = allContracts().filter(contract => contract.network == network and contract of Erc20Contract).map(contract => Erc20Contract(contract)).getErc20ContractBySymbol(symbol)

proc getErc20Contract*(address: Address): Erc20Contract =
  let network = settings.getCurrentNetwork()
  result = allContracts().filter(contract => contract.network == network and contract of Erc20Contract).map(contract => Erc20Contract(contract)).getErc20ContractByAddress(address)

proc getErc20Contracts*(): seq[Erc20Contract] =
  let network = settings.getCurrentNetwork()
  result = allContracts().filter(contract => contract of Erc20Contract and contract.network == network).map(contract => Erc20Contract(contract))

proc getErc721Contract(network: Network, name: string): Erc721Contract =
  let found = allContracts().filter(contract => contract of Erc721Contract and Erc721Contract(contract).name.toLower == name.toLower and contract.network == network)
  result = if found.len > 0: Erc721Contract(found[0]) else: nil

proc getErc721Contract*(name: string): Erc721Contract =
  let network = settings.getCurrentNetwork()
  getErc721Contract(network, name)

proc getErc721Contracts*(): seq[Erc721Contract] =
  let network = settings.getCurrentNetwork()
  result = allContracts().filter(contract => contract of Erc721Contract and contract.network == network).map(contract => Erc721Contract(contract))

proc getSntContract*(): Erc20Contract =
  if settings.getCurrentNetwork() == Network.Mainnet:
    result = getErc20Contract("snt")
  else:
    result = getErc20Contract("stt")
  if result == nil:
    # TODO: xDai network does not have an SNT contract listed. We will need to handle
    # having no SNT contract in other places in the code (ie anywhere that 
    # getSntContract() is called)
    raise newException(ValueError, "A status contract could not be found for the current network")