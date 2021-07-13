pragma Singleton

import QtQuick 2.13
import "../shared/xss.js" as XSS
import "../shared/polyfill.number.toLocaleString.js" as NumberPolyFill

QtObject {
    function isHex(value) {
        return /^(-0x|0x)?[0-9a-fA-F]*$/i.test(value)
    }

    function startsWith0x(value) {
        return value.startsWith('0x')
    }

    function isChatKey(value) {
        return startsWith0x(value) && isHex(value) && value.length === 132
    }

    function isValidETHNamePrefix(value) {
        return !(value.trim() === "" || value.endsWith(".") || value.indexOf("..") > -1)
    }

    function isAddress(value) {
        return startsWith0x(value) && isHex(value) && value.length === 42
    }

    function isPrivateKey(value) {
        return isHex(value) && ((startsWith0x(value) && value.length === 66) ||
                                (!startsWith0x(value) && value.length === 64))
    }

    function getCurrentThemeAccountColor(color) {
        const upperCaseColor = color.toUpperCase()
        if (Style.current.accountColors.indexOf(upperCaseColor) > -1) {
            return upperCaseColor
        }

        let colorIndex
        if (Style.current.name === Constants.lightThemeName) {
            colorIndex = Style.darkTheme.accountColors.indexOf(upperCaseColor)
        } else {
             colorIndex = Style.lightTheme.accountColors.indexOf(upperCaseColor)
        }
        if (colorIndex === -1) {
            // Unknown color
            return false
        }
        return Style.current.accountColors[colorIndex]
    }

    function getMessageWithStyle(msg, useCompactMode, isCurrentUser, hoveredLink = "") {
        return `<style type="text/css">` +
                    `p, img, a, del, code, blockquote { margin: 0; padding: 0; }` +
                    `code {` +
                        `background-color: ${Style.current.codeBackground};` +
                        `color: ${Style.current.white};` +
                        `white-space: pre;` +
                    `}` +
                    `p {` +
                        `line-height: 22px;` +
                    `}` +
                    `a {` +
                        `color: ${Style.current.linkColor};` +
                    `}` +
                    `a.mention {` +
                        `color: ${Style.current.mentionColor};` +
                        `background-color: ${Style.current.mentionBgColor};` +
                        `text-decoration: none;` +
                        `padding: 0px 2px;` +
                    `}` +
                    (hoveredLink !== "" ? `a.mention[href="${hoveredLink}"] { background-color: ${Style.current.mentionBgHoverColor}; }` : ``) +
                    `del {` +
                        `text-decoration: line-through;` +
                    `}` +
                    `table.blockquote td {` +
                        `padding-left: 10px;` +
                        `color: ${isCurrentUser ? Style.current.chatReplyCurrentUser : Style.current.secondaryText};` +
                    `}` +
                    `table.blockquote td.quoteline {` +
                        `background-color: ${isCurrentUser ? Style.current.chatReplyCurrentUser : Style.current.secondaryText};` +
                        `height: 100%;` +
                        `padding-left: 0;` +
                    `}` +
                    `.emoji {` +
                        `vertical-align: bottom;` +
                    `}` +
                    `span.isEdited {` +
                        `color: ${Style.current.secondaryText};` +
                        `margin-left: 5px` +
                    `}` +
                `</style>` +
                `${msg}`
    }

    function getReplyMessageStyle(msg, isCurrentUser, useCompactMode) {
        return `<style type="text/css">`+
                                `a {`+
                                    `color: ${isCurrentUser && !useCompactMode ? Style.current.white : Style.current.textColor};`+
                                `}`+
                                `a.mention {`+
                                    `color: ${isCurrentUser ? Style.current.cyan : Style.current.turquoise};`+
                                `}`+
                                `</style>`+
                            `</head>`+
                            `<body>`+
                                `${msg}`+
                            `</body>`+
                        `</html>`
    }

    function getAppSectionIndex(section) {
        let sectionId = -1
        switch (section) {
        case Constants.chat: sectionId = 0; break;
        case Constants.wallet: sectionId = 1; break;
        case Constants.browser: sectionId = 2; break;
        case Constants.timeline: sectionId = 3; break;
        case Constants.profile: sectionId = 4; break;
        case Constants.node: sectionId = 5; break;
        case Constants.ui: sectionId = 6; break;
        case Constants.community: sectionId = 99; break;
        }
        if (sectionId === -1) {
            throw new Exception ("Unknown section name. Check the Constants to know the available ones")
        }
        return sectionId
    }

    function getDisplayName(publicKey, contactIndex) {
        if (contactIndex === undefined) {
            contactIndex = profileModel.contacts.list.getContactIndexByPubkey(publicKey)
        }

        if (contactIndex === -1) {
            return utilsModel.generateAlias(publicKey)
        }
        const ensVerified = profileModel.contacts.list.rowData(contactIndex, 'ensVerified')
        if (!ensVerified) {
            const nickname = profileModel.contacts.list.rowData(contactIndex, 'localNickname')
            if (nickname) {
                return nickname
            }
        }
        return profileModel.contacts.list.rowData(contactIndex, 'name')
    }

    function isMnemonic(value) {
        if(!value.match(/^([a-z\s]+)$/)){
            return false;
        }
        return  Utils.seedPhraseValidWordCount(value);
    }

    function compactAddress(addr, numberOfChars) {
        if(addr.length <= 5 + (numberOfChars * 2)){  //   5 represents these chars 0x...
            return addr;
        }
        return addr.substring(0, 2 + numberOfChars) + "..." + addr.substring(addr.length - numberOfChars);
    }

    function linkifyAndXSS(inputText) {
        //URLs starting with http://, https://, or ftp://
        var replacePattern1 = /(\b(https?|ftp|statusim):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/gim;
        var replacedText = inputText.replace(replacePattern1, "<a href='$1'>$1</a>");

        //URLs starting with "www." (without // before it, or it'd re-link the ones done above).
        var replacePattern2 = /(^|[^\/])(www\.[\S]+(\b|$))/gim;
        replacedText = replacedText.replace(replacePattern2, "$1<a href='http://$2'>$2</a>");

        return XSS.filterXSS(replacedText)
    }

    function filterXSS(inputText) {
        return XSS.filterXSS(inputText)
    }

    function toLocaleString(val, locale, options) {
      return NumberPolyFill.toLocaleString(val, locale, options)
    }

    function isOnlyEmoji(inputText) {
        var emoji_regex = /^(?:[\u2700-\u27bf]|(?:\ud83c[\udde6-\uddff]){2}|[\ud800-\udbff][\udc00-\udfff]|[\u0023-\u0039]\ufe0f?\u20e3|\u3299|\u3297|\u303d|\u3030|\u24c2|\ud83c[\udd70-\udd71]|\ud83c[\udd7e-\udd7f]|\ud83c\udd8e|\ud83c[\udd91-\udd9a]|\ud83c[\udde6-\uddff]|[\ud83c[\ude01-\ude02]|\ud83c\ude1a|\ud83c\ude2f|[\ud83c[\ude32-\ude3a]|[\ud83c[\ude50-\ude51]|\u203c|\u2049|[\u25aa-\u25ab]|\u25b6|\u25c0|[\u25fb-\u25fe]|\u00a9|\u00ae|\u2122|\u2139|\ud83c\udc04|[\u2600-\u26FF]|\u2b05|\u2b06|\u2b07|\u2b1b|\u2b1c|\u2b50|\u2b55|\u231a|\u231b|\u2328|\u23cf|[\u23e9-\u23f3]|[\u23f8-\u23fa]|\ud83c\udccf|\u2934|\u2935|[\u2190-\u21ff]|\s)+$/;
        return emoji_regex.test(inputText);
    }

    function removeStatusEns(userName){
        return userName.endsWith(".stateofus.eth") ? userName.substr(0, userName.length - 14) : userName
    }

    function isValidAddress(inputValue) {
        return inputValue !== "0x" && /^0x[a-fA-F0-9]{40}$/.test(inputValue)
    }

    function isValidEns(inputValue) {
        if (!inputValue) {
            return false
        }
        const isEmail = /(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])/.test(inputValue)
        const isDomain = /(?:(?:(?<thld>[\w\-]*)(?:\.))?(?<sld>[\w\-]*))\.(?<tld>[\w\-]*)/.test(inputValue)
        return isEmail || isDomain || (inputValue.startsWith("@") && inputValue.length > 1)
    }


    /**
     * Removes trailing zeros from a string-representation of a number. Throws
     * if parameter is not a string
     */
    function stripTrailingZeros(strNumber) {
        if (!(typeof strNumber === "string")) {
            try {
                strNumber = strNumber.toString()
            } catch(e) {
                throw "[Utils.stripTrailingZeros] input parameter must be a string"
            }
        }
        return strNumber.replace(/(\.[0-9]*[1-9])0+$|\.0*$/,'$1')
    }

    /**
     * Removes starting zeros from a string-representation of a number. Throws
     * if parameter is not a string
     */
    function stripStartingZeros(strNumber) {
        if (!(typeof strNumber === "string")) {
            try {
                strNumber = strNumber.toString()
            } catch(e) {
                throw "[Utils.stripStartingZeros] input parameter must be a string"
            }
        }
        return strNumber.replace(/^(0*)([0-9\.]+)/, "$2")
    }


    function setColorAlpha(color, alpha) {
        return Qt.hsla(color.hslHue, color.hslSaturation, color.hslLightness, alpha)
    }

    function formatTime(timestamp) {
        let messageDate = new Date(Math.floor(timestamp))
        let minutes = messageDate.getMinutes();
        let hours = messageDate.getHours();
        return (hours < 10 ? "0" + hours : hours) + ":" + (minutes < 10 ? "0" + minutes : minutes)
    }

    function formatShortDateStr(longStr) {
        const dmKeys = {
            // Days
            //% "Sun"
            Sunday: qsTrId("sun"),
            //% "Mon"
            Monday: qsTrId("mon"),
            //% "Tue"
            Tuesday: qsTrId("tue"),
            //% "Wed"
            Wednesday: qsTrId("wed"),
            //% "Thu"
            Thursday: qsTrId("thu"),
            //% "Fri"
            Friday: qsTrId("fri"),
            //% "Sat"
            Saturday: qsTrId("sat"),
            // Months
            //% "Jan"
            January: qsTrId("jan"),
            //% "Feb"
            February: qsTrId("feb"),
            //% "Mar"
            March: qsTrId("mar"),
            //% "Apr"
            April: qsTrId("apr"),
            //% "May"
            May: qsTrId("may"),
            //% "Jun"
            June: qsTrId("jun"),
            //% "Jul"
            July: qsTrId("jul"),
            //% "Aug"
            August: qsTrId("aug"),
            //% "Sep"
            September: qsTrId("sep"),
            //% "Oct"
            October: qsTrId("oct"),
            //% "Nov"
            November: qsTrId("nov"),
            //% "Dec"
            December: qsTrId("dec")
        };

        let shortStr = longStr;
        for (const [key, value] of Object.entries(dmKeys)) {
            shortStr = shortStr.replace(key, value);
            shortStr = shortStr.replace(key.toLowerCase(), value);
            shortStr = shortStr.replace(key.toUpperCase(), value);
        }

        return shortStr;
    }

    function formatDateTime(timestamp, locale) {
        let now = new Date()
        let yesterday = new Date()
        yesterday.setDate(now.getDate()-1)
        let messageDate = new Date(Math.floor(timestamp))
        let lastWeek = new Date()
        lastWeek.setDate(now.getDate()-7)

        let minutes = messageDate.getMinutes();
        let hours = messageDate.getHours();

        if (now.toDateString() === messageDate.toDateString()) {
            return (hours < 10 ? "0" + hours : hours) + ":" + (minutes < 10 ? "0" + minutes : minutes)
        } else if (yesterday.toDateString() === messageDate.toDateString()) {
            //% "Yesterday"
            return qsTrId("yesterday")
        } else if (lastWeek.getTime() < messageDate.getTime()) {
            //% "Sunday"
            let days = [qsTrId("sunday"),
                        //% "Monday"
                        qsTrId("monday"),
                        //% "Tuesday"
                        qsTrId("tuesday"),
                        //% "Wednesday"
                        qsTrId("wednesday"),
                        //% "Thursday"
                        qsTrId("thursday"),
                        //% "Friday"
                        qsTrId("friday"),
                        //% "Saturday"
                        qsTrId("saturday")];
            return days[messageDate.getDay()];
        } else {
            return formatShortDateStr(new Date().toLocaleDateString(Qt.locale(locale)))
        }
    }

    function findAssetBySymbol(assets, symbolToFind) {
        for(var i=0; i<assets.rowCount(); i++) {
            const symbol = assets.rowData(i, "symbol")
            if (symbol.toLowerCase() === symbolToFind.toLowerCase()) {
                return {
                    name: assets.rowData(i, "name"),
                    symbol,
                    value: assets.rowData(i, "value"),
                    fiatBalanceDisplay: assets.rowData(i, "fiatBalanceDisplay"),
                    address: assets.rowData(i, "address"),
                    fiatBalance: assets.rowData(i, "fiatBalance")
                }
            }
        }
    }

    function isValidChannelName(channelName) {
        return (/^[a-z0-9\-]+$/.test(channelName))
    }

    function isURL(text) {
        return (/https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}(\.[a-zA-Z0-9()]{1,6})?\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)/.test(text))
    }

    function isURLWithOptionalProtocol(text) {
        return (/^(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)/.test(text))
    }

    function isHexColor(c) {
        return (/^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$/i.test(c))
    }

    function isSpace(c) {
        return (/( |\t|\n|\r)/.test(c))
    }

    function getLinkTitleAndCb(link) {
        const result = {
            title: "Status",
            callback: null
        }

        // Link to send a direct message
        let index = link.indexOf("/u/")
        if (index === -1) {
            // Try /p/ as well
            index = link.indexOf("/p/")
        }
        if (index > -1) {
            const pk = link.substring(index + 3)
            result.title = qsTr("Start a 1 on 1 chat with %1").arg(utilsModel.generateAlias(pk))
            result.callback = function () {
                chatsModel.channelView.joinPrivateChat(pk, "");
            }
            return result
        }

        // Community
        index = link.lastIndexOf("/c/")
        if (index > -1) {
            const communityId = link.substring(index + 3)

            const communityName = chatsModel.communities.getCommunityNameById(communityId)

            if (!communityName) {
                // Unknown community, fetch the info if possible
                chatsModel.communities.requestCommunityInfo(communityId)
                result.communityId = communityId
                result.fetching = true
                return result
            }

            result.title = qsTr("Join the %1 community").arg(communityName)
            result.communityId = communityId
            result.callback = function () {
                const isUserMemberOfCommunity = chatsModel.communities.isUserMemberOfCommunity(communityId)
                if (isUserMemberOfCommunity) {
                    chatsModel.communities.setActiveCommunity(communityId)
                    return
                }
                const userCanJoin = chatsModel.communities.userCanJoin(communityId)
                // TODO find what to do when you can't join
                if (userCanJoin) {
                    chatsModel.communities.joinCommunity(communityId, true)
                }
            }
            return result
        }

        // Public chat
        // This needs to be the last check because it is as VERY loose check
        index = link.lastIndexOf("/")
        if (index > -1) {
            const chatId = link.substring(index + 1)
            result.title = qsTr("Join the %1 public channel").arg(chatId)
            result.callback = function () {
                chatsModel.channelView.joinPublicChat(chatId);
            }
            return result
        }

        return result
    }

    function getLinkDataForStatusLinks(link) {
        if (!link.includes(Constants.deepLinkPrefix) && !link.includes(Constants.joinStatusLink)) {
            return
        }

        const result = getLinkTitleAndCb(link)

        return {
            site: qsTr("Status app link"),
            title: result.title,
            communityId: result.communityId,
            fetching: result.fetching,
            thumbnailUrl: "../../../../img/status.png",
            contentType: "",
            height: 0,
            width: 0,
            callback: result.callback
        }
    }

    function getTick(wordCount) {
        return (wordCount === 12 || wordCount === 15 ||
                wordCount === 18 || wordCount === 21 || wordCount === 24)
                ? "✓ " : "";
    }

    function isValidNumberOfWords(wordCount) {
        return !!getTick(wordCount);
    }

    function countWords(text) {
        if (text.trim() === "")
            return 0;
        return text.trim().replace(/  +/g, " ").split(" ").length;
    }

    function seedPhraseValidWordCount(text) {
        return isValidNumberOfWords(countWords(text))
    }

    /**
     * Returns text in the format "✓ 12 words" for seed phrases input boxes
     */
    function seedPhraseWordCountText(text) {
        let wordCount = countWords(text);
        //% "words"
        return getTick(wordCount) + wordCount.toString() + " " + qsTrId("words")
    }

    function uuid() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 5)
    }

    function getNetworkName(network){
        switch(network){
            //% "Mainnet with upstream RPC"
            case Constants.networkMainnet: return qsTrId("mainnet-with-upstream-rpc")
            //% "POA Network"
            case Constants.networkPOA: return qsTrId("poa-network")
            //% "xDai Chain"
            case Constants.networkXDai: return qsTrId("xdai-chain")
            //% "Goerli with upstream RPC"
            case Constants.networkGoerli: return qsTrId("goerli-with-upstream-rpc")
            //% "Rinkeby with upstream RPC"
            case Constants.networkRinkeby: return qsTrId("rinkeby-with-upstream-rpc")
            //% "Ropsten with upstream RPC"
            case Constants.networkRopsten: return qsTrId("ropsten-with-upstream-rpc")
            default: return network
        }
    }

    function validatePasswords(item, firstPasswordField, repeatPasswordField) {
        switch (item) {
            case "first":
                if (firstPasswordField.text === "") {
                    //% "You need to enter a password"
                    return [false, qsTrId("you-need-to-enter-a-password")];
                } else if (firstPasswordField.text.length < 6) {
                    return [false, qsTrId("Password needs to be 6 characters or more")];
                }
                return [true, ""];

            case "repeat":
                if (repeatPasswordField.text === "") {
                    //% "You need to repeat your password"
                    return [false, qsTrId("you-need-to-repeat-your-password")];
                } else if (repeatPasswordField.text !== firstPasswordField.text) {
                    //% "Passwords don't match"
                    return [false, qsTrId("passwords-don-t-match")];
                }
                return [true, ""];

            default:
                return [false, ""];
        }
    }

    function getHostname(url) {
        const rgx = /\:\/\/(?:[a-zA-Z0-9\-]*\.{1,}){1,}[a-zA-Z0-9]*/i
        const matches = rgx.exec(url)
        if (!matches || !matches.length) {
            if (url.includes(Constants.deepLinkPrefix)) {
                return Constants.deepLinkPrefix
            }
            return  ""
        }
        return matches[0].substring(3)
    }

    function hasImageExtension(url) {
        return Constants.acceptedImageExtensions.some(ext => url.toLowerCase().includes(ext))
    }

    function hasDragNDropImageExtension(url) {
        return Constants.acceptedDragNDropImageExtensions.some(ext => url.toLowerCase().includes(ext))
    }

    function deduplicate(array) {
        return Array.from(new Set(array))
    }

    function hasUpperCaseLetter(str) {
        return (/[A-Z]/.test(str))
    }

    function convertSpacesToDashesAndUpperToLowerCase(str)
    {
        if (str.includes(" "))
            str = str.replace(/ /g, "-")

        if(hasUpperCaseLetter(str))
            str = str.toLowerCase()

        return str
    }

    /* Validation section start */

    enum Validate {
        NoEmpty = 0x01,
        TextLength = 0x02,
        TextHexColor = 0x04,
        TextLowercaseLettersNumberAndDashes = 0x08
    }

    function validateAndReturnError(str, validation, fieldName = "field", limit = 0)
    {
        let errMsg = ""

        if(validation & Utils.Validate.NoEmpty && str === "") {
            errMsg = qsTr("You need to enter a %1").arg(fieldName)
        }

        if(validation & Utils.Validate.TextLength && str.length > limit) {
            errMsg = qsTr("The %1 cannot exceed %2 characters").arg(fieldName, limit)
        }

        if(validation & Utils.Validate.TextHexColor && !isHexColor(str)) {
            errMsg = qsTr("Must be an hexadecimal color (eg: #4360DF)")
        }

        if(validation & Utils.Validate.TextLowercaseLettersNumberAndDashes && !isValidChannelName(str)) {
            errMsg = qsTr("Use only lowercase letters (a to z), numbers & dashes (-). Do not use chat keys.")
        }

        return errMsg
    }

    /* Validation section end */



    // Leave this function at the bottom of the file as QT Creator messes up the code color after this
    function isPunct(c) {
        return /(!|\@|#|\$|%|\^|&|\*|\(|\)|_|\+|\||-|=|\\|{|}|[|]|"|;|'|<|>|\?|,|\.|\/)/.test(c)
    }

    function isInvalidPasswordMessage(msg) {
        return (
            msg.includes("could not decrypt key with given password") ||
            msg.includes("invalid password")
        );
    }
}
