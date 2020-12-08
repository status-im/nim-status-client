import json
import os

const GENERATED* = "generated"
const SEED* = "seed"
const KEY* = "key"
const WATCH* = "watch"

const ZERO_ADDRESS* = "0x0000000000000000000000000000000000000000"

const PATH_WALLET_ROOT* = "m/44'/60'/0'/0"
# EIP1581 Root Key, the extended key from which any whisper key/encryption key can be derived
const PATH_EIP_1581* = "m/43'/60'/1581'"
# BIP44-0 Wallet key, the default wallet key
const PATH_DEFAULT_WALLET* = PATH_WALLET_ROOT & "/0"
# EIP1581 Chat Key 0, the default whisper key
const PATH_WHISPER* = PATH_EIP_1581 & "/0'/0"

# set via `nim c` param `-d:INFURA_TOKEN:[token]`; should be set in CI/release builds
const INFURA_TOKEN {.strdefine.} = ""
# allow runtime override via environment variable; core contributors can set a
# release token in this way for local development
let INFURA_TOKEN_ENV = $getEnv("INFURA_TOKEN")

let INFURA_TOKEN_RESOLVED =
  if INFURA_TOKEN_ENV != "":
    INFURA_TOKEN_ENV
  else:
    INFURA_TOKEN

let DEFAULT_NETWORKS* = %* [
  {
    "id": "testnet_rpc",
    "etherscan-link": "https://ropsten.etherscan.io/address/",
    "name": "Ropsten with upstream RPC",
    "config": {
      "NetworkId": 3,
      "DataDir": "/ethereum/testnet_rpc",
      "UpstreamConfig": {
        "Enabled": true,
        "URL": "https://ropsten.infura.io/v3/" & INFURA_TOKEN_RESOLVED
      }
    }
  },
  {
    "id": "rinkeby_rpc",
    "etherscan-link": "https://rinkeby.etherscan.io/address/",
    "name": "Rinkeby with upstream RPC",
    "config": {
      "NetworkId": 4,
      "DataDir": "/ethereum/rinkeby_rpc",
      "UpstreamConfig": {
        "Enabled": true,
        "URL": "https://rinkeby.infura.io/v3/" & INFURA_TOKEN_RESOLVED
      }
    }
  },
  {
    "id": "goerli_rpc",
    "etherscan-link": "https://goerli.etherscan.io/address/",
    "name": "Goerli with upstream RPC",
    "config": {
      "NetworkId": 5,
      "DataDir": "/ethereum/goerli_rpc",
      "UpstreamConfig": {
        "Enabled": true,
        "URL": "https://goerli.blockscout.com/"
      }
    }
  },
  {
    "id": "mainnet_rpc",
    "etherscan-link": "https://etherscan.io/address/",
    "name": "Mainnet with upstream RPC",
    "config": {
      "NetworkId": 1,
      "DataDir": "/ethereum/mainnet_rpc",
      "UpstreamConfig": {
        "Enabled": true,
        "URL": "https://mainnet.infura.io/v3/" & INFURA_TOKEN_RESOLVED
      }
    }
  },
  {
    "id": "xdai_rpc",
    "name": "xDai Chain",
    "config": {
      "NetworkId": 100,
      "DataDir": "/ethereum/xdai_rpc",
      "UpstreamConfig": {
        "Enabled": true,
        "URL": "https://dai.poa.network"
      }
    }
  },
  {
    "id": "poa_rpc",
    "name": "POA Network",
    "config": {
      "NetworkId": 99,
      "DataDir": "/ethereum/poa_rpc",
      "UpstreamConfig": {
        "Enabled": true,
        "URL": "https://core.poa.network"
      }
    }
  }
]

var NODE_CONFIG* = %* {
  "BrowsersConfig": {
    "Enabled": true
  },
  "ClusterConfig": {
    "Enabled": true
  },
  "DataDir": "./ethereum/mainnet",
  "EnableNTPSync": true,
  "KeyStoreDir": "./keystore",
  "ListenAddr": ":30304",
  "LogEnabled": true,
  "LogFile": "geth.log",
  "LogLevel": "INFO",
  "MailserversConfig": {
    "Enabled": true
  },
  "Name": "StatusDesktop",
  "NetworkId": 1,
  "NoDiscovery": false,
  "PermissionsConfig": {
    "Enabled": true
  },
  "Rendezvous": true,
  "RequireTopics": {
    "whisper": {
      "Max": 2,
      "Min": 2
    }
  },
  "ShhextConfig": {
    "BackupDisabledDataDir": "./",
    "DataSyncEnabled": true,
    "InstallationID": "aef27732-8d86-5039-a32e-bdbe094d8791",
    "MailServerConfirmations": true,
    "MaxMessageDeliveryAttempts": 6,
    "PFSEnabled": true,
    "VerifyENSContractAddress": "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
    "VerifyENSURL": "https://mainnet.infura.io/v3/" & INFURA_TOKEN_RESOLVED,
    "VerifyTransactionChainID": 1,
    "VerifyTransactionURL": "https://mainnet.infura.io/v3/" & INFURA_TOKEN_RESOLVED
  },
  "StatusAccountsConfig": {
    "Enabled": true
  },
  "UpstreamConfig": {
    "Enabled": true,
    "URL": "https://mainnet.infura.io/v3/" & INFURA_TOKEN_RESOLVED
  },
  "WakuConfig": {
    "BloomFilterMode": nil,
    "Enabled": true,
    "LightClient": true,
    "MinimumPoW": 0.001
  },
  "WalletConfig": {
    "Enabled": true
  }
}

const DEFAULT_NETWORK_NAME* = "mainnet_rpc"

let sep = if defined(windows): "\\" else: "/"

let homeDir = getHomeDir()

let parentDir =
  if getEnv("NIM_STATUS_CLIENT_DEV").string != "":
    "."
  elif homeDir == "":
    "."
  elif defined(macosx):
    joinPath(homeDir, "Library", "Application Support")
  elif defined(windows):
    let targetDir = getEnv("LOCALAPPDATA").string
    if targetDir == "":
      joinPath(homeDir, "AppData", "Local")
    else:
      targetDir
  else:
    let targetDir = getEnv("XDG_CONFIG_HOME").string
    if targetDir == "":
      joinPath(homeDir, ".config")
    else:
      targetDir

let clientDir =
  if parentDir != ".":
    joinPath(parentDir, "Status")
  else:
    parentDir

let DATADIR* = joinPath(clientDir, "data") & sep
let KEYSTOREDIR* = joinPath(clientDir, "data", "keystore") & sep
let TMPDIR* = joinPath(clientDir, "tmp") & sep
