pragma Singleton

import QtQuick 2.13

QtObject {
    readonly property int chatTypeOneToOne: 1
    readonly property int chatTypePublic: 2
    readonly property int chatTypePrivateGroupChat: 3

    readonly property int limitLongChatText: 500
    readonly property int limitLongChatTextCompactMode: 1000

    readonly property int fetchMoreMessagesButton: -2
    readonly property int chatIdentifier: -1
    readonly property int unknownContentType: 0
    readonly property int messageType: 1
    readonly property int stickerType: 2
    readonly property int statusType: 3
    readonly property int emojiType: 4
    readonly property int transactionType: 5
    readonly property int systemMessagePrivateGroupType: 6
    readonly property int imageType: 7
    readonly property int audioType: 8

    readonly property string watchWalletType: "watch"
    readonly property string keyWalletType: "key"
    readonly property string seedWalletType: "seed"
    readonly property string generatedWalletType: "generated"

    // Transaction states
    readonly property int addressRequested: 1
    readonly property int declined: 2
    readonly property int addressReceived: 3
    readonly property int transactionRequested: 4
    readonly property int transactionDeclined: 5
    readonly property int pending: 6
    readonly property int confirmed: 7

    readonly property int maxTokens: 200

    readonly property string zeroAddress: "0x0000000000000000000000000000000000000000"

    readonly property var accountColors: [
        "#9B832F",
        "#D37EF4",
        "#1D806F",
        "#FA6565",
        "#7CDA00",
        "#887af9",
        "#8B3131"
    ]


    readonly property string api_request: "api-request"
    readonly property string web3SendAsyncReadOnly: "web3-send-async-read-only"

    readonly property string permission_web3: "web3"
    readonly property string permission_contactCode: "contact-code"

}
