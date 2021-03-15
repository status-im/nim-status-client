## API available to QML

### Wallet Model
The wallet model (exposed as `walletModel`) is used for functions pertaining to the wallet and accounts on the node.

#### Signals
The `walletModel` exposes the following signals, which can be consumed in QML using the `Connections` component (with a target of `walletModel` and prefixed with `on`).
| Name          | Parameters     | Description  |
|---------------|----------|--------------|
| `etherscanLinkChanged` | none | fired when the etherscan link has changed |
| `signingPhraseChanged` | none | fired when the signing phrase has changed |
| `currentCollectiblesListsChanged` | none | fired when the list of collectibles for the currently selected account has changed |
| `currentTransactionsChanged` | none | fired when the transactions for the currently selected account have changed |
| `currentAccountChanged` | none | fired when the currently selected account in the wallet has changed |
| `focusedAccountChanged` | none | fired when the currently selected account in the chat transaction model has changed |
| `currentAssetListChanged` | none | fired when the token assets for the currently selected account have changed |
| `totalFiatBalanceChanged` | none | fired when the total equivalent fiat balance of all accounts has changed |
| `accountListChanged` | none | fired when accounts on the node have chagned |
| `transactionWasSent` | `txResult` (`string`): JSON stringified result of sending a transaction | fired when a transaction was sent (wallet, sticker purchase, ENS, etc) |
| `defaultCurrencyChanged` | none | fired when the user's default currency has chagned |
| `gasPricePredictionsChanged` | none | fired when the gas price predictions have changed, typically after getting a gas price prediction response |
| `historyWasFetched` | none | fired when `status-go` completes fetching of transaction history |
| `loadingTrxHistoryChanged` | `isLoading` (`bool`): `true` if the transaction history is loading | fired when the loading of transfer history starts and completes |
| `ensWasResolved` | `resolvedAddress` (`string`): address resolved from the ENS name<br>`uuid` (`string`): unique identifier that was used to identify the request in QML so that only specific components can respond when needed | fired when an ENS name was resolved |
| `transactionCompleted` | `success` (`bool`): `true` if the transaction was successful<br>`txHash` (`string`): has of the transaction<br>`revertReason` (`string`): reason transaction was reverted (if provided and if the transaction was reverted) | fired when a tracked transction (from the wallet or ENS) was completed |
| `dappBrowserAccountChanged` | none | fired when the select dapp browser wallet account has changed |

### QtProperties
The following properties can be accessed directly on the `walletModel`, ie `walletModel.etherscanLink`
| Name          | Type | Accessibility | Signal | Description  |
|---------------|------|---------------|--------|--------------|
| `etherscanLink` | `QVariant<string>` | `read` | `etherscanLinkChanged` | link to Etherscan from the current network settings |
| `signingPhrase` | `QVariant<string>` | `read` | `signingPhraseChanged` | gets the signing phrase |
| `collectiblesLists` | `QVariant<CollectiblesList>` | `read`/`write` | `currentCollectiblesListsChanged` | gets or sets the list of collectibles for the currently selected wallet |
| `transactions` | `QVariant<TransactionList>` | `read`/`write` | `currentTransactionsChanged` | gets or sets the list of transactions for the currently selected wallet |
| `currentAccount` | `QVariant<AccountItemView>` | `read`/`write` | `currentAccountChanged` | gets or sets the currently selected account |
| `focusedAccount` | `QVariant<AccountItemView>` | `read`/`write` | `focusedAccountChanged` | gets or sets the currently focused account in the chat transaction modal |
| `assets` | `QVariant<AssetList>` | `read`/`write` | `currentAssetListChanged` | gets or sets list of token assets for the currently selected wallet account |
| `totalFiatBalance` | `QVariant<string>` | `read`/`write` | `totalFiatBalanceChanged` | gets or sets the total equivalent fiat balance of all wallets in the format `#.##` |
| `accounts` | `QVariant<AccountList>` | `read` | `accountListChanged` | returns list of accounts on the node |
| `defaultCurrency` | `QVariant<string>` | `read`/`write` | `defaultCurrencyChanged` | gets or sets the default currency in the current user's settings |
| `safeLowGasPrice` | `QVariant<string>` | `read` | `gasPricePredictionsChanged` | gets the current Ethereum networks's safe low gas price, in gwei |
| `standardGasPrice` | `QVariant<string>` | `read` | `gasPricePredictionsChanged` | gets the current Ethereum networks's standard gas price, in gwei |
| `fastGasPrice` | `QVariant<string>` | `read` | `gasPricePredictionsChanged` | gets the current Ethereum networks's fast gas price, in gwei |
| `fastestGasPrice` | `QVariant<string>` | `read` | `gasPricePredictionsChanged` | gets the current Ethereum networks's fastest gas price, in gwei |
| `fastestGasPrice` | `QVariant<string>` | `read` | none | gets the default gas limit for sending Ethereum, which is `"21000"` |
| `defaultTokenList` | `QVariant<TokenList>` | `read` | none | gets the non-custom list of ERC-20 tokens for the currently selected wallet account |
| `customTokenList` | `QVariant<TokenList>` | `read` | none | gets the custom list of ERC-20 tokens added by the user |
| `dappBrowserAccount` | `QVariant<AccountItemView>` | `read` | `dappBrowserAccountChanged` | the wallet account currently used in the dapp browser |

### Methods
Methods can be invoked by calling them directly on the `walletModel`, ie `walletModel.getSigningPhrase()`.

| Name          | Params | Return type     | Description  |
|-----------------------------------|---------|-----|-------------------------------------|
| `getEtherscanLink` | none | `QVariant<string>`| Gets the link to Etherscan from the current network settings |
| `getSigningPhrase` | none | `QVariant<string>`| Gets the link to Etherscan from the current network settings |
| `getStatusToken` | none | `string`| Gets the Status token for the current network (ie SNT for mainnet and STT for Ropsten) and returns a stringified JSON object containing `name`, `symbol`, and `address` for the token. |
| `getCurrentCollectiblesLists` | none | `QVariant<CollectiblesList>`| Gets the list of collectibles for the currently selected wallet. |
| `getCurrentTransactions` | none | `QVariant<TransactionList>`| Gets the list of transactions for the currently selected wallet. |
| `setCurrentAccountByIndex` | `index` (`int`): index of the account in the list of accounts | `void`| sets the currently selected account to the account at the provided index |
| `getCurrentAccount` | none | `QVariant<AccountItemView>`| gets the currently selected account |
| `setFocusedAccountByAddress` | `address` (`string`): address of the account to focus | `void`| sets the focused account in the chat transaction modal to the account with the provided address |
| `getFocusedAccount` | none | `QVariant<AccountItemView>`| gets the currently focused account in the chat transaction modal |
| `getCurrentAssetList` | none | `QVariant<AssetList>`| returns list of token assets for the currently selected wallet account |
| `getTotalFiatBalance` | none | `QVariant<string>`| returns the total equivalent fiat balance of all wallets in the format `#.##` |
| `getFiatValue` | `cryptoBalance` (`string`): balance whole (ie ETH)<br>`cryptoSymbol` (`string`): symbol to convert from<br>`fiatSymbol` (`string`) symbol of fiat currency to convert to | `QVariant<string>`| returns the total equivalent fiat balance in the format `#.##` |
| `getCryptoValue` | `fiatBalance` (`string`): balance whole (ie USD)<br>`fiatSymbol` (`string`): fiat currency symbol to convert from<br>`cryptoSymbol` (`string`) symbol of fiat currency to convert to | `QVariant<string>`| returns the total equivalent crypto balance in the format `#.##` |
| `getGasEthValue` | `gweiValue` (`string`): gas price in gwei<br>`gasLimit` (`string`): gas limit | `string` | gets maximum gas spend by multiplying the gas limit by the gas price |
| `generateNewAccount` | `password` (`string`): password for the current user account<br>`accountName` (`string`): name for the new wallet account<br>`color` (`string`) hex code of the custom wallet color | `string` | creates a new account on the node with a custom name and color |
| `addAccountsFromSeed` | `seed` (`string`): seed phrase of account<br>`password` (`string`): password of the current user account<br>`accountName` (`string`): name for the new wallet account<br>`color` (`string`) hex code of the custom wallet color | `string` | adds an account to the status-go node from the provided seed phrase |
| `addAccountsFromPrivateKey` | `privateKey` (`string`): private key of account<br>`password` (`string`): password of the current user account<br>`accountName` (`string`): name for the new wallet account<br>`color` (`string`) hex code of the custom wallet color | `string` | adds an account to the status-go node from the provided private key |
| `addWatchOnlyAccount` | `address` (`string`): address of account to watch<br>`accountName` (`string`): name for the new wallet account<br>`color` (`string`) hex code of the custom wallet color | `string` | watches an account without adding it to the status-go node |
| `changeAccountSettings` | `address` (`string`): address of account<br>`accountName` (`string`): updated name for the wallet account<br>`color` (`string`) updated hex code of the account | `string` | updates the account's name and color |
| `deleteAccount` | `address` (`string`): address of account | `string` | deletes an account from the status-go node and returns an error string or empty string if no error |
| `getAccountList` | none | `QVariant<AccountList>` | returns list of accounts on status-go node |
| `estimateGas` | `from_addr` (`string`): from address for the transaction<br>`to` (`string`): to address for the transaction<br>`assetAddress` (`string`): token contract address (use `"0x0000000000000000000000000000000000000000"` for Ethereum transactions)<br>`value` (`string`): amount of Ethereum to send (in whole Ethereum units)<br>`data` (`string`): encoded transaction data | `string` |returns a stringified JSON response from status with the transaction gas estimate and an `error` field if an error occurred. |
| `transactionSent` | `txResult` (`string`): transaction result<br> | `void` | fires the QML signal `walletModel.transactionWasSent` |
| `sendTransaction` | `from_addr` (`string`): from address for the transaction<br>`to` (`string`): to address for the transaction<br>`assetAddress` (`string`): token contract address (use `"0x0000000000000000000000000000000000000000"` for Ethereum transactions)<br>`value` (`string`): amount of Ethereum to send (in whole Ethereum units)<br>`gas` (`string`): gas to use for the transaction<br>`gas` (`string`): gas price for the transaction<br>`password` (`string`): password of the current user account<br>`uuid` (`string`): a unique identifier for the transaction request,so it can be idenified in QML when upon asynchronous completion<br> | `void` | sends a transaction in a separate thread. |
| `getDefaultAccount` | none | `string` | returns the address of the currently selected account |
| `defaultCurrency` | none | `string` | returns the currency symbol from settings |
| `setDefaultCurrency` | `currency` (`string`): currency symbol, ie `"USD"` | `string` | set a new default currency in the current user's settings |
| `hasAsset` | `account` (`string`): account to check for enabled token<br>`symbol` (`string`): token symbol, ie `"SNT"` | `bool` | returns true if token with `symbol` is enabled, false other wise |
| `toggleAsset` | `symbol` (`string`): token symbol, ie `"SNT"` | `void` | enables a token with `symbol` or disables it it's already enabled |
| `removeCustomToken` | `tokenAddress` (`string`): token contract address | `void` | removes the custom token from the list of tokens available in the wallet |
| `addCustomToken` | `address` (`string`): token contract address<br>`name` (`string`): display name for the token<br>`symbol` (`string`): token symbol<br>`decimals` (`string`): number of decimals supported by the token | `void` | adds the custom token to the list of tokens available in the wallet |
| `setCollectiblesResult` | `collectibleType` (`string`): `"cryptokitty"`, `"kudo"`, `"ethermon"`, `"stickers"` | `void` | sets the current wallet's collectibles |
| `reloadCollectible` | `collectiblesJSON` (`string`): stringified JSON structure of collectibles | `void` | reloads the current wallet's collectibles in another thread |
| `getGasPricePredictions` | none | `void` | gets current ethereum network gas predictions in a new thread |
| `getGasPricePredictionsResult` | `gasPricePredictionsJson` (`string`): JSON stringified response of gas predictions | `void` | updates the current gas predictions for the ethereum network, and fires the `gasPricePredictionsChanged` signal |
| `safeLowGasPrice` | none | `string` | returns the current Ethereum networks's safe low gas price, in gwei |
| `standardGasPrice` | none | `string` | returns the current Ethereum networks's standard gas price, in gwei |
| `fastGasPrice` | none | `string` | returns the current Ethereum networks's fast gas price, in gwei |
| `fastestGasPrice` | none | `string` | returns the current Ethereum networks's fastest gas price, in gwei |
| `defaultGasLimit` | none | `string` | returns the default gas limit for sending Ethereum, which is `"21000"` |
| `getDefaultAddress` | none | `string` | returns the address of the first wallet account on the node |
| `getDefaultTokenList` | none | `QVariant<TokenList>` | returns the non-custom list of ERC-20 tokens for the currently selected wallet account |
| `loadCustomTokens` | none | none | loads the custom tokens in to the `TokenList` added by the user in to `walletModel.customTokenList` |
| `getCustomTokenList` | none | `QVariant<TokenList>` | returns the custom list of ERC-20 tokens added by the user |
| `isFetchingHistory` | `address` (`string`): address of the account to check | `bool` | returns `true` if `status-go` is currently fetching the transaction history for the specified account |
| `isKnownTokenContract` | `address` (`string`): contract address | `bool` | returns `true` if the specified address is in the list of default or custom (user-added) contracts |
| `decodeTokenApproval` | `tokenAddress` (`string`): contract address<br>`data` (`string`): response received from the ERC-20 token `Approve` function call | `string` | Returns stringified JSON result of the decoding. The JSON will contain only an `error` field if there was an error during decoding. Otherwise, it will contain a `symbol` (the token symbol) and an `amount` (amount approved to spend) field. |
| `isHistoryFetched` | `address` (`string`): address of the account to check | `bool` | returns `true` if `status-go` has returned transfer history for the specified account (result of `wallet_getTransfersByAddress`) |
| `loadTransactionsForAccount` | `address` (`string`): address of the account to load transactions for | `void` | loads the transfer history for the specified account (result of `wallet_getTransfersByAddress`) in a separate thread |
| `setTrxHistoryResult` | `historyJSON` (`string`): stringified JSON result from `status-go`'s response to `wallet_getTransfersByAddress` | `void` | sets the transaction history for the account requested. If the requested account was tracked by the `walletModel`, it will have its transactions updated (including `currentAccount`). The `loadingTrxHistoryChanged` signal is also fired with `false` as a parameter. |
| `resolveENS` | `ens` (`string`): the ENS name to resolve | `void` | resolves an ENS name in a separate thread |
| `ensResolved` | `ens` (`string`): the ENS name to resolve<br>`uuid` (`string`): a unique identifier to identify the request in QML so that only specific components can respond when needed | `void` | fires the `ensWasResolved` signal with the resolved address (`address`) and the unique identifier (`uuid`) |
| `setDappBrowserAddress` | none | `void` | sets the dapp browser account to the account specified in settings and then fires the `dappBrowserAccountChanged` signal |
| `getDappBrowserAccount` | none | `QVariant<AccountItemView>` | returns the wallet account currently used in the dapp browser |

#### AccountList
`QAbstractListModel` to expose node accounts.
The following roles are available to the model when bound to a QML control:

| Name          | Description  |
|---------------|--------------|
| `name` | account name defined by user |
| `address` | account address |
| `iconColor` | account color chosen by user |
| `balance` | equivalent fiat balance for display, in format `$#.##` |
| `fiatBalance` | the wallet's equivalent fiat balance in the format `#.##` (no currency as in `balance`) |
| `assets` | returns an `AssetList` (see below) |
| `isWallet` | flag indicating whether the asset is a token or a wallet |
| `walletType` | in the case of a wallet, indicates the type of wallet ("key", "seed", "watch", "generated"). See `AccountItemView`for more information on wallet types. |

#### AssetList
`QAbstractListModel` exposes ERC-20 token assets owned by a wallet account.
The following roles are available to the model when bound to a QML control:

| Name          | Description  |
|---------------|--------------|
| `name` | token name |
| `symbol` | token ticker symbol |
| `value` | amount of token (in wei or equivalent) |
| `fiatBalanceDisplay` | equivalent fiat balance for display, in format `$#.##` |
| `address` | token contract address |
| `fiatBalance` | equivalent fiat balance (not for display) |

#### CollectiblesList
`QAbstractListModel` exposes ERC-721 assets for a wallet account.
The following roles are available to the model when bound to a QML control:

| Name          | Description  |
|---------------|--------------|
| `collectibleType` | the type of collectible ("cryptokitty", "kudo", "ethermon", "stickers") |
| `collectiblesJSON` | JSON representation of all collectibles in the list (schema is different for each type of collectible) |
| `error` | error encountered while fetching the collectibles |

#### TransactionList
`QAbstractListModel` to expose transactions for the currently selected wallet.
The following roles are available to the model when bound to a QML control:

| Name          | Description  |
|---------------|--------------|
| `typeValue` | the transaction type |
| `address` | ?? |
| `blockNumber` | the block number the transaction was included in |
| `blockHash` | the hash of the block |
| `timestamp` | Unix timestamp of when the block was created |
| `gasPrice` | gas price used in the transaction |
| `gasLimit` | maximum gas allowed in this block |
| `gasUsed` | amount of gas used in the transaction |
| `nonce` | transaction nonce |
| `txStatus` | transaction status |
| `value` | value (in wei) of the transaction |
| `fromAddress` | address the transaction was sent from |
| `to` | address the transaction was sent to |
| `contract` | ?? likely in a transfer transaction, the token contract interacted with |

#### AccountItemView
This type can be accessed by any of the properties in the `walletModel` that return `QtObject<AccountItemView>`, ie `walletModel.currentAccount.name`. See the `walletModel`table above.

| Name          | Type     | Description  |
|---------------|----------|--------------|
| `name*` | `string` | display name given to the wallet by the user |
| `address*` | `string` | wallet's ethereum address |
| `iconColor*` | `string` | wallet hexadecimal colour assigned to the wallet by the user |
| `balance*` | `string` | the wallet's fiat balance used for display purposes in the format of `#.## USD` |
| `fiatBalance*` | `string` | the wallet's equivalent fiat balance in the format `#.##` (no currency as in `balance`) |
| `path*` | `string` | the wallet's HD derivation path |
| `walletType*` | `string` | type determined by how the wallet was created. Values include: |
|  | | `"key"` - wallet was created with a private key |
|  | |   `"seed"` - wallet was created with a seed phrase |
|  | |   `"watch"` - wallet was created as to watch an Ethereum address (like a read-only wallet) |
|  | |   `"generated"` - wallet was generated by the app |

#### TokenList
`QAbstractListModel` exposes all displayable ERC-20 tokens.
The following roles are available to the model when bound to a QML control:

| Name          | Description  |
|---------------|--------------|
| `name` | token display name |
| `symbol` | token ticker symbol |
| `hasIcon` | flag indicating whether or not the token has an icon |
| `address` | the token's ERC-20 contract address |
| `decimals` | the number of decimals held by the token |
| `isCustom` | flag indicating whether the token was added by the user |

### Chats Model
The wallet model (exposed as `chatsModel`) is used for functions pertaining to chatting.

#### Signals
The `chatsModel` exposes the following signals, which can be consumed in QML using the `Connections` component (with a target of `chatsModel` and prefixed with `on`).
| Name          | Parameters     | Description  |
|---------------|----------|--------------|
| `oldestMessageTimestampChanged` | none | fired when the oldest message timestamp has changed |
| `activeChannelChanged` | none | fired when the active chat channel has changed |
| `contextChannelChanged` | none | fired when the context menu (right-click menu) channel has changed |
| `sendingMessage` | none | typically fired once messages in the chat have been sent |
| `appReady` | none | fired once chats, profile updates, and timeline have been loaded |
| `sendingMessageFailed` | none | fired after a message has failed to be sent |
| `messagePushed` | none | fired after a message was added to the timeline or to any chat message list |
| `newMessagePushed` | `messageIndex` (`int`): index of the message in the message list | fired after a message was newly received in the currently active chat and was added to active chat message list |
| `messageNotificationPushed` | `chatId` (`string`): id of the chat the message belongs to<br>`text` (`string`): text of the notification<br>`messageType` (`string`): type of message<br>`chatType` (`int`) integer representation of the type of chat<br>`timestamp` (`string`): string represnetation of the UNIX timestamp of the message<br>`identiticon` (`string`): base64-encoded image of the sender's identicon<br>`username` (`string`): sender's three-word alias<br>`hasMention` (`bool`): `true` if the message contains a mention of another user<br>`isAddedContact` (`bool`): `true` if the sender has been added as a contact<br>`channelName` (`string`): name of the channel the message was sent on | fired after a message was newly received in the currently active chat and was added to active chat message list |
| `messagesCleared` | none | removes messages from being displayed for all the chats |
| `linkPreviewDataWasReceived` | `previewData` (`string`) JSON string of the data returned | fired when link preview data was returned from status-go |
| `messagesLoaded` | none | fired after previous messages were fetched (fetch more messages) |
| `loadingMessagesChanged` | `value` (`bool`): `true` if loading messages from status-go | fired after the flag indicating whether or not messages are loading has changed |
| `unreadMessagesCntChanged` | none | fired after the unread messages count has changed |
| `ensWasResolved` | `resolvedPubKey` (`string`): public key that was resolved from the ENS name | fired after the ENS resolution has completed, passing in the resolved public key |
| `onlineStatusChanged` | `connected` (`bool`): `true` if connected to the internet | fired after the internet connectivity status has changed (based on peer count reported by status-go) |

### QtProperties
The following properties can be accessed directly on the `chatsModel`, ie `chatsModel.oldestMsgTimestamp`
| Name          | Type | Accessibility | Signal | Description  |
|---------------|------|---------------|--------|--------------|
| `oldestMsgTimestamp` | `QVariant<int64>` | `read` | `oldestMessageTimestampChanged` | Gets the last set UNIX timestamp of the oldest message. See `setLastMessageTimestamp` for logic on how this is determined. |
| `chats` | `QVariant<ChannelsList>` | `read` | none | Gets the `ChannelsList` containing the chat channels views. See `ChannelsList` below for more information. |
| `communities` | `QVariant<CommunitiesView>` | `read` | none | Gets the `CommunitiesView` containing the communities view. See `CommunitiesView` below for more information. |
| `activeChannelIndex` | `int` | `read`/`write` | `activeChannelChanged` | Gets the index of the currently active community in the list of communities (if activated) or the currently active channel in the list of chats. |
| `activeChannel` | `QVariant<ChatItemView>` | `read`/`write` | `activeChannelChanged` | Gets the currently active channel in the list of chats. |
| `contextChannel` | `QVariant<ChatItemView>` | `read`/`write` | `contextChannelChanged` | Gets the current channel used for the context menu (right-click menu). |
| `suggestionList` | `QVariant<SuggestionsList>` | `read` | none | Gets the current suggestion list view. |


### Methods
Methods can be invoked by calling them directly on the `chatsModel`, ie `chatsModel.getOldestMessageTimestamp()`.

| Name          | Params | Return type     | Description  |
|-----------------------------------|---------|-----|-------------------------------------|
| `getOldestMessageTimestamp` | none | `QVariant<int64>`| Returns the last set UNIX timestamp of the oldest message. See `setLastMessageTimestamp` for logic on how this is determined.  |
**WIP**

#### ChannelsList
`QAbstractListModel` to expose chat channels.
The following roles are available to the model when bound to a QML control:

| Name          | Description  |
|---------------|--------------|
| `name` | name of the channel |
**WIP**

*chatsModel.chats* - get channel list (list)

channel object:
* name - 
* timestamp - 
* lastMessage.text - 
* unviewedMessagesCount - 
* identicon - 
* chatType - 
* color - 

*chatsModel.activeChannelIndex* - 
*chatsModel.activeChannel* - return currently active channel (object)

active channel object:
* id - 
* name - 
* color - 
* identicon - 
* chatType - (int)
* members - (list)
  * userName
  * pubKey
  * isAdmin
  * joined
  * identicon
* isMember(pubKey: string) - check if `pubkey` is a group member (bool)
* isAdmin(pubKey: string) - check if `pubkey` is a group admin (bool)

*chatsModel.messageList* - returns messages for the current channel (list)

message object:
* userName - 
* message - 
* timestamp - 
* clock - 
* identicon - 
* isCurrentUser - 
* contentType - 
* sticker - 
* fromAuthor - 
* chatId - 
* sectionIdentifier - 
* messageId - 

*chatsModel.sendMessage(message: string)* - send a message to currently active channel

*chatsModel.joinChat(channel: string, chatTypeInt: int)* - join a channel

*chatsModel.groups.join()* - confirm joining group

*chatsModel.leaveActiveChat()* - leave currently active channel

*chatsModel.clearChatHistory()* - clear chat history of currently active channel

*chatsModel.groups.rename(newName: string)* - rename current active group

*chatsModel.blockContact(id: string)* - block contact

*chatsModel.addContact(id: string)*

*chatsModel.groups.create(groupName: string, pubKeys: string)*

**TODO**: document all exposed APIs to QML

