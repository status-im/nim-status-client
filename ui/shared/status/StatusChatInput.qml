import QtQuick 2.13
import QtQuick.Controls 2.13
import QtGraphicalEffects 1.13
import QtQuick.Layouts 1.13
import QtMultimedia 5.13
import QtQuick.Dialogs 1.3
import "../../imports"
import "../../shared"
import "../../app/AppLayouts/Chat/ChatColumn/samples"
import "../../app/AppLayouts/Chat/ChatColumn"

import "./emojiList.js" as EmojiJSON

Rectangle {
    id: control
    signal sendTransactionCommandButtonClicked()
    signal receiveTransactionCommandButtonClicked()
    signal stickerSelected(string hashId, string packId)
    signal sendMessage(var event)

    property bool emojiEvent: false;
    property bool paste: false;
    property bool isColonPressed: false;
    property bool isReply: false
    property bool isImage: false

    property var recentStickers
    property var stickerPackList

    property int extraHeightFactor: calculateExtraHeightFactor()
    property int messageLimit: control.isStatusUpdateInput ? 300 : 2000
    property int messageLimitVisible: control.isStatusUpdateInput ? 50 : 200

    property int chatType

    //% "Type a message."
    property string chatInputPlaceholder: qsTrId("type-a-message-")

    property alias textInput: messageInputField
    property bool isStatusUpdateInput: chatType === Constants.chatTypeStatusUpdate

    property var fileUrls: []

    property alias suggestionsList: suggestions
    property alias suggestions: suggestionsBox

    property var imageErrorMessageLocation: StatusChatInput.ImageErrorMessageLocation.Top

    enum ImageErrorMessageLocation {
        Top,
        Bottom
    }

    height: {
        if (extendedArea.visible) {
            return messageInput.height + extendedArea.height + (control.isStatusUpdateInput ? 0 : Style.current.bigPadding)
        }
        if (messageInput.height > messageInput.defaultInputFieldHeight) {
            if (messageInput.height >= messageInput.maxInputFieldHeight) {
                return messageInput.maxInputFieldHeight + (control.isStatusUpdateInput ? 0 : Style.current.bigPadding)
            }
            return messageInput.height + (control.isStatusUpdateInput ? 0 : Style.current.bigPadding)
        }
        return control.isStatusUpdateInput ? 56 : 64
    }
    anchors.left: parent.left
    anchors.right: parent.right

    color: Style.current.background

    function calculateExtraHeightFactor() {
        const factor = (messageInputField.length / 500) + 1;
        return (factor > 5) ? 5 : factor;
    }

    function insertInTextInput(start, text) {
        // Repace new lines with entities because `insert` gets rid of them
        messageInputField.insert(start, text.replace(/\n/g, "<br/>"));
    }

    property var interpretMessage: function (msg) {
        if (msg.startsWith("/shrug")) {
            return  msg.replace("/shrug", "") + " ¯\\\\\\_(ツ)\\_/¯"
        }
        if (msg.startsWith("/tableflip")) {
            return msg.replace("/tableflip", "") + " (╯°□°）╯︵ ┻━┻"
        }

        return msg
    }

    function isUploadFilePressed(event) {
        return (event.key === Qt.Key_U) && (event.modifiers & Qt.ControlModifier) && imageBtn.visible && !imageDialog.visible
    }

    function checkTextInsert() {
        if (emojiSuggestions.visible) {
            emojiSuggestions.addEmoji();
            return true
        }
        if (suggestionsBox.visible) {
            suggestionsBox.selectCurrentItem();
            return true
        }
        return false
    }

    function onKeyPress(event){
        if (event.modifiers === Qt.NoModifier && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
            if (checkTextInsert()) {
                event.accepted = true;
                return
            }

            if (control.isStatusUpdateInput) {
                return // Status update require the send button to be clicked
            }
            if (messageInputField.length < messageLimit) {
                control.sendMessage(event)
                control.hideExtendedArea();
                event.accepted = true
                return;
            }
            if(event) event.accepted = true
            messageTooLongDialog.open()
        }

        if (event.key === Qt.Key_Tab) {
            if (checkTextInsert()) {
                event.accepted = true;
                return
            }
        }

        const message = control.extrapolateCursorPosition();

        // handle new line in blockquote
        if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && (event.modifiers & Qt.ShiftModifier) && message.data.startsWith(">")) {
            if(message.data.startsWith(">") && !message.data.endsWith("\n\n")) {
                let newMessage1 = ""
                if (message.data.endsWith("\n> ")) {
                    newMessage1 = message.data.substr(0, message.data.lastIndexOf("> ")) + "\n\n"
                } else {
                    newMessage1 = message.data + "\n> ";
                }
                messageInputField.remove(0, messageInputField.cursorPosition);
                insertInTextInput(0, Emoji.parse(newMessage1));
            }
            event.accepted = true
        }
        // handle backspace when entering an existing blockquote
        if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete)) {
            if(message.data.startsWith(">") && message.data.endsWith("\n\n")) {
                const newMessage = message.data.substr(0, message.data.lastIndexOf("\n")) + "> ";
                messageInputField.remove(0, messageInputField.cursorPosition);
                insertInTextInput(0, Emoji.parse(newMessage));
                event.accepted = true
            }
        }

        if ((event.key === Qt.Key_V) && (event.modifiers & Qt.ControlModifier)) {
            paste = true;
        }

        // ⌘⇧U
        if (isUploadFilePressed(event)) {
            imageBtn.clicked()
            event.accepted = true
        }

        if (event.key === Qt.Key_Down) {
            suggestionsBox.listView.incrementCurrentIndex()
            return emojiSuggestions.listView.incrementCurrentIndex()
        }
        if (event.key === Qt.Key_Up) {
            suggestionsBox.listView.decrementCurrentIndex()
            return emojiSuggestions.listView.decrementCurrentIndex()
        }
        if (event.key === Qt.Key_Escape) {
            suggestionsBox.hide()
        }

        isColonPressed = (event.key === Qt.Key_Colon) && (event.modifiers & Qt.ShiftModifier);
    }

    function wrapSelection(wrapWith) {
        if (messageInputField.selectionStart - messageInputField.selectionEnd === 0) return

        insertInTextInput(messageInputField.selectionStart, wrapWith);
        insertInTextInput(messageInputField.selectionEnd, wrapWith);

        messageInputField.deselect()
        formatInputMessage()
    }
    function unwrapSelection(unwrapWith, selectedTextWithFormationChars) {
        if (messageInputField.selectionStart - messageInputField.selectionEnd === 0) return

        selectedTextWithFormationChars = selectedTextWithFormationChars.trim()
        // Check if the selectedTextWithFormationChars has formation chars and if so, calculate how many so we can adapt the start and end pos
        const selectTextDiff = (selectedTextWithFormationChars.length - messageInputField.selectedText.length) / 2

        const changedString = selectedTextWithFormationChars.replace(unwrapWith, '').replace(unwrapWith, '')

        messageInputField.remove(messageInputField.selectionStart - selectTextDiff, messageInputField.selectionEnd + selectTextDiff)

        insertInTextInput(messageInputField.selectionStart, changedString)

        messageInputField.deselect()
        formatInputMessage()
    }

    function getPlainText() {
        const textWithoutMention = messageInputField.text.replace(/<span style="[ :#0-9a-z;\-\.,\(\)]+">(@([a-z\.]+(\ ?[a-z]+\ ?[a-z]+)?))<\/span>/ig, "\[\[mention\]\]$1\[\[mention\]\]")

        const deparsedEmoji = Emoji.deparse(textWithoutMention);

        return chatsModel.plainText(deparsedEmoji);
    }

    function removeMentions(currentText) {
        return currentText.replace(/\[\[mention\]\]/g, '')
    }

    function parseMarkdown(markdownText) {
        const htmlText = markdownText
          .replace(/\~\~([^*]+)\~\~/gim, '~~<span style="text-decoration: line-through">$1</span>~~')
          .replace(/\*\*([^*]+)\*\*/gim, ':asterisk::asterisk:<b>$1</b>:asterisk::asterisk:')
          .replace(/\`([^*]+)\`/gim, '`<code>$1</code>`')
          .replace(/\*([^*]+)\*/gim, ':asterisk:<i>$1</i>:asterisk:')
        return htmlText.replace(/\:asterisk\:/gim, "*")
    }

    function parseBackText(plainText) {
        return parseMarkdown(Emoji.parse(plainText.replace(/\n/g, "<br />")))
    }

    function getFormattedText(start, end) {
        start = start || 0
        end = end || messageInputField.length

        const oldFormattedText = messageInputField.getFormattedText(start, end)

        const found = oldFormattedText.match(/<!--StartFragment-->([\w\W\s]*)<!--EndFragment-->/m);

        return found[1]
    }

    function setFormatInInput(formationFunction, startTag, endTag, formationChar, numFormationChars) {
        const inputText = getFormattedText()
        const plainInputText = messageInputField.getText(0, messageInputField.length)

        let lengthDifference

        try {
            const result = formationFunction(inputText)

            if (!result) {
                return
            }
            const parsed = JSON.parse(result)

            let substring
            let nbEmojis
            parsed.forEach(function (match) {
                match[1] += 1
                const truncatedInputText = inputText.substring(0, match[1] + numFormationChars)
                const truncatedPlainText = plainInputText.substring(0, messageInputField.cursorPosition)

                const lengthDifference = truncatedInputText.length - truncatedPlainText.length

                nbEmojis = Emoji.nbEmojis(truncatedInputText)


                match[1] += (nbEmojis * -2)
                match[0] += (nbEmojis * -2)
                substring = inputText.substring(match[0], match[1])

                if (plainInputText.charAt(match[0] - 1) !== formationChar) {
                    match[0] -= lengthDifference
                    match[1] -= lengthDifference
                } else {
                    match[1] -= lengthDifference
                }

                messageInputField.remove(match[0], match[1])
                insertInTextInput(match[0], `${startTag}${substring}${endTag}`)
            })
        } catch (e) {
            //
        }
    }

    function formatInputMessage() {
        const posBeforeEnd = messageInputField.length - messageInputField.cursorPosition;

        // Remove align center spans
        // TODO fix Those spans are added automatically by QT when you press space after an emoji. They break the code formation process

        // strikethrough
        setFormatInInput(chatsModel.formatInputView.formatInputStrikeThrough, '<span style=" text-decoration: line-through;">', '</span>', '~', 2)
        // bold
        setFormatInInput(chatsModel.formatInputView.formatInputBold, '<b>', '</b>', '*', 2)
        // code
        setFormatInInput(chatsModel.formatInputView.formatInputCode, '<code>', '</code>', '`', 1)
        // italic
        setFormatInInput(chatsModel.formatInputView.formatInputItalic, '<i>', '</i>', '*', 1)
    }

    function onRelease(event) {
        if (event.key === Qt.Key_Backspace && textFormatMenu.opened) {
            textFormatMenu.close()
        }

        // the text doesn't get registered to the textarea fast enough
        // we can only get it in the `released` event
        if (paste) {
            paste = false;
            interrogateMessage();
            // TODO use the new formatInputMessage function instead
            const plainText = getPlainText()
            const newText = parseBackText(plainText)
            messageInputField.remove(0, messageInputField.length)
            insertInTextInput(0, newText)
        } else {
            if (event.key === Qt.Key_Asterisk ||
                event.key === Qt.Key_QuoteLeft ||
                event.key === Qt.Key_Space ||
                event.key === Qt.Key_AsciiTilde) {
                formatInputMessage()
            }
        }

        if (event.key !== Qt.Key_Escape) {
            emojiEvent = emojiHandler(event);
            if (!emojiEvent) {
                emojiSuggestions.close()
            }
        }
    }

    function interrogateMessage() {
        // TODO change this function to use remove and insert instead of replcing the whole text
        const text = chatsModel.plainText(Emoji.deparse(messageInputField.text));

        var words = text.split(' ');

        let madeChanges = false
        let transform = true;
        for (var i = 0; i < words.length; i++) {
            transform = true;
            if (words[i].charAt(0) === ':') {
                for (var j = 0; j < words[i].length; j++) {
                    if (Utils.isSpace(words[i].charAt(j)) === true || Utils.isPunct(words[i].charAt(j)) === true) {
                        transform = false;
                    }
                }

                if (transform) {
                    madeChanges = true
                    const codePoint = Emoji.getEmojiUnicode(words[i]);
                    words[i] = words[i].replace(words[i], (codePoint !== undefined) ? Emoji.fromCodePoint(codePoint) : words[i]);
                }
            }
        }

        if (madeChanges) {
            messageInputField.remove(0, messageInputField.length);
            insertInTextInput(0, Emoji.parse(words.join('&nbsp;')));
        }
    }

    // since emoji length is not 1 we need to match that position that TextArea returns
    // to the actual position in the string.
    function extrapolateCursorPosition() {
        // we need only the message part to be html
        const text = getPlainText()
        const completelyPlainText = removeMentions(text)
        const plainText = Emoji.parse(text);

        var bracketEvent = false;
        var almostMention = false;
        var mentionEvent = false;
        var length = 0;

        // This loop calculates the cursor position inside the plain text which contains the image tags (<img>) and the mention tags ([[mention]])
        const cursorPos = messageInputField.cursorPosition
        let character = ""
        for (var i = 0; i < plainText.length; i++) {
            if (length >= cursorPos) break;

            character = plainText.charAt(i)
            if (!bracketEvent && character !== '<' && !mentionEvent && character !== '[')  {
                length++;
            } else if (!bracketEvent && character === '<') {
                bracketEvent = true;
            } else if (bracketEvent && character === '>') {
                bracketEvent = false;
                length++;
            } else if (!mentionEvent && almostMention && plainText.charAt(i) === '[') {
                almostMention = false
                mentionEvent = true
            } else if (!mentionEvent && !almostMention && plainText.charAt(i) === '[') {
                almostMention = true
            } else if (!mentionEvent && almostMention && plainText.charAt(i) !== '[') {
                almostMention = false
            } else if (mentionEvent && !almostMention && plainText.charAt(i) === ']') {
                almostMention = true
            } else if (mentionEvent && almostMention && plainText.charAt(i) === ']') {
                almostMention = false
                mentionEvent = false
            }
        }

        let textBeforeCursor = Emoji.deparseFromParse(plainText.substr(0, i));

        return {
            cursor: countEmojiLengths(plainText.substr(0, i)) + messageInputField.cursorPosition + text.length - completelyPlainText.length,
            data: textBeforeCursor,
        };
    }

    function emojiHandler(event) {
        let message = extrapolateCursorPosition();
        pollEmojiEvent(message);

        // state machine to handle different forms of the emoji event state
        if (!emojiEvent && isColonPressed) {
            return (message.data.length <= 1 || Utils.isSpace(message.data.charAt(message.cursor - 1))) ? true : false;
        } else if (emojiEvent && isColonPressed) {
            const index = message.data.lastIndexOf(':', message.cursor - 2);
            if (index >= 0 && message.cursor > 0) {
                const shortname = message.data.substr(index, message.cursor);
                const codePoint = Emoji.getEmojiUnicode(shortname);
                if (codePoint !== undefined) {
                    replaceWithEmoji(message, shortname, codePoint);
                }
                return false;
            }
            return true;
        } else if (emojiEvent && isKeyValid(event.key) && !isColonPressed) {
            // popup
            const index2 = message.data.lastIndexOf(':', message.cursor - 1);
            if (index2 >= 0 && message.cursor > 0) {
                const emojiPart = message.data.substr(index2, message.cursor);
                if (emojiPart.length > 2) {
                    const emojis = EmojiJSON.emoji_json.filter(function (emoji) {
                        return emoji.name.includes(emojiPart) ||
                                emoji.shortname.includes(emojiPart) ||
                                emoji.aliases.some(a => a.includes(emojiPart))
                    })

                    emojiSuggestions.openPopup(emojis, emojiPart)
                }
                return true;
            }
        } else if (emojiEvent && !isKeyValid(event.key) && !isColonPressed) {
            return false;
        }
        return false;
    }

    function countEmojiLengths(value) {
        const match = Emoji.getEmojis(value);
        var length = 0;

        if (match && match.length > 0) {
            for (var i = 0; i < match.length; i++) {
                length += Emoji.deparseFromParse(match[i]).length;
            }
            length = length - match.length;
        }
        return length;
    }

    function replaceWithEmoji(message, shortname, codePoint) {
        const encodedCodePoint = Emoji.getEmojiCodepoint(codePoint)
        messageInputField.remove(messageInputField.cursorPosition - shortname.length, messageInputField.cursorPosition);
        insertInTextInput(messageInputField.cursorPosition, Emoji.parse(encodedCodePoint) + " ");
        emojiSuggestions.close()
        emojiEvent = false
    }

    // check if user has placed cursor near valid emoji colon token
    function pollEmojiEvent(message) {
        const index = message.data.lastIndexOf(':', message.cursor);
        if (index >= 0) {
            emojiEvent = validSubstr(message.data.substr(index, message.cursor - index));
        }
    }

    function validSubstr(substr) {
        for(var i = 0; i < substr.length; i++) {
            var c = substr.charAt(i);
            if (Utils.isSpace(c) === true || Utils.isPunct(c) === true)
                return false;
        }
        return true;
    }

    function isKeyValid(key) {
        if (key === Qt.Key_Space || key ===  Qt.Key_Tab ||
            (key >= Qt.Key_Exclam && key <= Qt.Key_Slash) ||
            (key >= Qt.Key_Semicolon && key <= Qt.Key_Question) ||
            (key >= Qt.Key_BracketLeft && key <= Qt.Key_hyphen))
            return false;
        return true;
    }

    function hideExtendedArea() {
        isImage = false;
        isReply = false;
        control.fileUrls = []
        imageArea.imageSource = [];
        replyArea.userName = ""
        replyArea.identicon = ""
        replyArea.message = ""
        for (let i=0; i<validators.children.length; i++) {
            const validator = validators.children[i]
            validator.images = []
        }
    }

    function validateImages(imagePaths) {
        // needed because imageArea.imageSource is not a normal js array
        const existing = (imageArea.imageSource || []).map(x => x.toString())
        let validImages = Utils.deduplicate(existing.concat(imagePaths))
        for (let i=0; i<validators.children.length; i++) {
            const validator = validators.children[i]
            validator.images = validImages
            validImages = validImages.filter(validImage => validator.validImages.includes(validImage))
        }
        return validImages
    }

    function showImageArea(imagePaths) {
        isImage = true;
        isReply = false;
        imageArea.imageSource = imagePaths
        control.fileUrls = imageArea.imageSource
    }

    function showReplyArea(userName, message, identicon) {
        isReply = true
        replyArea.userName = userName
        replyArea.message = message
        replyArea.identicon = identicon
        messageInputField.forceActiveFocus();
    }

    Connections {
        target: applicationWindow.dragAndDrop
        onDroppedOnValidScreen: (drop) => {
            let validImages = validateImages(drop.urls)
            if (validImages.length > 0) {
                showImageArea(validImages)
                drop.acceptProposedAction()
            }
        }
    }

    ListModel {
        id: suggestions
    }

    FileDialog {
        id: imageDialog
        //% "Please choose an image"
        title: qsTrId("please-choose-an-image")
        folder: shortcuts.pictures
        selectMultiple: true
        nameFilters: [
            qsTr("Image files (%1)").arg(Constants.acceptedDragNDropImageExtensions.map(img => "*" + img).join(" "))
        ]
        onAccepted: {
            imageBtn.highlighted = false
            imageBtn2.highlighted = false
            let validImages = validateImages(imageDialog.fileUrls)
            if (validImages.length > 0) {
                control.showImageArea(validImages)
            }
            messageInputField.forceActiveFocus();
        }
        onRejected: {
            imageBtn.highlighted = false
            imageBtn2.highlighted = false
        }
    }

    MessageDialog {
        id: messageTooLongDialog
        //% "Your message is too long."
        title: qsTrId("your-message-is-too-long.")
        icon: StandardIcon.Critical
        //% "Please make your message shorter. We have set the limit to 2000 characters to be courteous of others."
        text: qsTrId("please-make-your-message-shorter.-we-have-set-the-limit-to-2000-characters-to-be-courteous-of-others.")
        standardButtons: StandardButton.Ok
    }

    StatusEmojiSuggestionPopup {
        id: emojiSuggestions
    }

    SuggestionBox {
        id: suggestionsBox
        model: suggestions
        x : messageInput.x
        y: -height - Style.current.smallPadding
        width: messageInput.width
        filter: messageInputField.text
        cursorPosition: messageInputField.cursorPosition
        property: "ensName, localNickname, alias"
        onItemSelected: function (item, lastAtPosition, lastCursorPosition) {
            const hasEmoji = Emoji.hasEmoji(messageInputField.text)

            const properties = "ensName, alias"; // Ignore localNickname

            let aliasName = item[properties.split(",").map(p => p.trim()).find(p => !!item[p])]
            aliasName = aliasName.replace(/(\.stateofus)?\.eth/, "")

            const spanPlusAlias = `${Constants.mentionSpanTag}@${aliasName}</span> `

            let rightIndex = hasEmoji ? lastCursorPosition + 2 : lastCursorPosition

            messageInputField.remove(lastAtPosition, rightIndex)

            messageInputField.insert(lastAtPosition, spanPlusAlias)


            messageInputField.cursorPosition = lastAtPosition + aliasName.length + 2
            if (messageInputField.cursorPosition === 0) {
                // It reset to 0 for some reason, go back to the end
                messageInputField.cursorPosition = messageInputField.length
            }

            suggestionsBox.suggestionsModel.clear()
        }
    }

    StatusChatCommandsPopup {
        id: chatCommandsPopup
        x: 8
        y: -height
        onSendTransactionCommandButtonClicked: {
            control.sendTransactionCommandButtonClicked()
            chatCommandsPopup.close()
        }
        onReceiveTransactionCommandButtonClicked: {
            control.receiveTransactionCommandButtonClicked()
            chatCommandsPopup.close()
        }
        onClosed: {
            chatCommandsBtn.highlighted = false
        }
    }

    StatusEmojiPopup {
        id: emojiPopup
        width: 360
        height: 440
        x: parent.width - width - Style.current.halfPadding
        y: -height
        emojiSelected: function (text, atCursor) {
            insertInTextInput(atCursor ? messageInputField.cursorPosition : messageInputField.length, text)
            emojiBtn.highlighted = false
            messageInputField.forceActiveFocus();
        }
        onClosed: {
            emojiBtn.highlighted = false
        }
    }

    StatusStickersPopup {
        id: stickersPopup
        x: parent.width - width - Style.current.halfPadding
        y: -height
        enabled: !!control.recentStickers && !!control.stickerPackList
        recentStickers: control.recentStickers
        stickerPackList: control.stickerPackList
        onStickerSelected: {
            control.stickerSelected(hashId, packId)
            messageInputField.forceActiveFocus();
        }
        onClosed: {
            stickersBtn.highlighted = false
        }
    }

    StatusIconButton {
        id: chatCommandsBtn
        icon.name: "chat-commands"
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        visible: control.chatType === Constants.chatTypeOneToOne && !control.isStatusUpdateInput
        onClicked: {
            highlighted = true
            chatCommandsPopup.open()
        }
    }

    StatusIconButton {
        id: imageBtn
        icon.name: "images_icon"
        icon.height: 18
        icon.width: 20
        anchors.left: chatCommandsBtn.visible ? chatCommandsBtn.right : parent.left
        anchors.leftMargin: chatCommandsBtn.visible ? 2 : 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        visible: control.chatType !== Constants.chatTypePublic && !control.isStatusUpdateInput

        onClicked: {
            highlighted = true
            imageDialog.open()
        }
    }

    Rectangle {
        id: messageInput
        property int maxInputFieldHeight: control.isStatusUpdateInput ? 124 : 112
        property int defaultInputFieldHeight: control.isStatusUpdateInput ? 56 : 40
        anchors.left: imageBtn.visible ? imageBtn.right : parent.left
        anchors.leftMargin: imageBtn.visible ? 5 : Style.current.smallPadding
        anchors.top: control.isStatusUpdateInput ? parent.top : undefined
        anchors.bottom: !control.isStatusUpdateInput ? parent.bottom : undefined
        anchors.bottomMargin: control.isStatusUpdateInput ? 0 : 12
        anchors.right: parent.right
        anchors.rightMargin: Style.current.smallPadding
        height: {
            if (messageInputField.implicitHeight <= messageInput.defaultInputFieldHeight) {
                return messageInput.defaultInputFieldHeight
            }
            if (messageInputField.implicitHeight >= messageInput.maxInputFieldHeight) {
                return messageInput.maxInputFieldHeight
            }
            return messageInputField.implicitHeight
        }

        color: Style.current.inputBackground
        radius: control.isStatusUpdateInput ? 36 :
          height > defaultInputFieldHeight + 1 || extendedArea.visible ? 16 : 32

    ColumnLayout {
        id: validators
        anchors.bottom: control.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Top ? extendedArea.top : undefined
        anchors.bottomMargin: control.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Top ? -4 : undefined
        anchors.top: control.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Bottom ? extendedArea.bottom : undefined
        anchors.topMargin: control.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Bottom ? (isImage ? -4 : 4) : undefined
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        z: 1
        StatusChatImageExtensionValidator {
            Layout.alignment: Qt.AlignHCenter
        }
        StatusChatImageSizeValidator {
            Layout.alignment: Qt.AlignHCenter
        }
        StatusChatImageQtyValidator {
            Layout.alignment: Qt.AlignHCenter
        }
    }

        Rectangle {
            id: extendedArea
            visible: isImage || isReply
            height: {
              if (visible) {
                  if (isImage) {
                      return imageArea.height
                  }

                  if (isReply) {
                      return replyArea.height + replyArea.anchors.topMargin
                  }
              }
              return 0
            }
            anchors.left: messageInput.left
            anchors.right: messageInput.right
            anchors.bottom: control.isStatusUpdateInput ? undefined : messageInput.top
            anchors.top: control.isStatusUpdateInput ? messageInput.bottom : undefined
            anchors.topMargin: control.isStatusUpdateInput ? -Style.current.halfPadding : 0
            color: Style.current.inputBackground
            radius: control.isStatusUpdateInput ? 36 : 16

            Rectangle {
                color: parent.color
                anchors.right: parent.right
                anchors.left: parent.left
                height: control.isStatusUpdateInput ? 64 : 30
                anchors.top: control.isStatusUpdateInput ? parent.top : undefined
                anchors.topMargin: control.isStatusUpdateInput ? -24 : 0
                anchors.bottom: control.isStatusUpdateInput ? undefined : parent.bottom
                anchors.bottomMargin: control.isStatusUpdateInput ? 0 : -height/2
            }

            StatusChatInputImageArea {
                id: imageArea
                anchors.left: parent.left
                anchors.leftMargin: control.isStatusUpdateInput ? profileImage.width + Style.current.padding : Style.current.halfPadding
                anchors.right: parent.right
                anchors.rightMargin: control.isStatusUpdateInput ? actions.width + 2* Style.current.padding : Style.current.halfPadding
                anchors.top: parent.top
                anchors.topMargin: control.isStatusUpdateInput ? 0 : Style.current.halfPadding
                visible: isImage
                width: messageInputField.width - actions.width
                onImageRemoved: {
                    if (control.fileUrls.length > index && control.fileUrls[index]) {
                        control.fileUrls.splice(index, 1)
                    }
                    isImage = control.fileUrls.length > 0
                    validateImages(control.fileUrls)
                }
            }

            StatusChatInputReplyArea {
                id: replyArea
                visible: isReply
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.top: parent.top
                anchors.topMargin: 2
                onCloseButtonClicked: {
                    isReply = false
                }
            }
        }

        StatusImageIdenticon {
            id: profileImage
            source: profileModel.profile.identicon
            anchors.left: parent.left
            anchors.leftMargin: Style.current.smallPadding
            anchors.top: parent.top
            anchors.topMargin: Style.current.halfPadding
            visible: control.isStatusUpdateInput
        }

        ScrollView {
            id: scrollView
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: profileImage.visible ? profileImage.right : parent.left
            anchors.leftMargin: Style.current.smallPadding
            anchors.right: actions.left
            anchors.rightMargin: Style.current.halfPadding
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            TextArea {
                property var lastClick: 0

                id: messageInputField
                textFormat: Text.RichText
                font.pixelSize: 15
                font.family: Style.current.fontRegular.name
                wrapMode: TextArea.Wrap
                //% "Type a message"
                placeholderText: qsTrId("type-a-message")
                placeholderTextColor: Style.current.secondaryText
                selectByMouse: true
                color: Style.current.textColor
                topPadding: control.isStatusUpdateInput ? 18 : Style.current.smallPadding
                bottomPadding: control.isStatusUpdateInput ? 14 : 12
                Keys.onPressed: onKeyPress(event)
                Keys.onReleased: onRelease(event) // gives much more up to date cursorPosition
                Keys.onShortcutOverride: event.accepted = isUploadFilePressed(event)
                leftPadding: 0
                background: Rectangle {
                    color: "transparent"
                }
                selectionColor: Style.current.primarySelectionColor
                persistentSelection: true
                onReleased: function (event) {
                    const now = Date.now()
                    if (messageInputField.selectedText.trim() !== "") {
                        // If it's a double click, just check the mouse position
                        // If it's a mouse select, use the start and end position average)
                        let x = now < messageInputField.lastClick + 500 ? x = event.x :
                                                        (messageInputField.cursorRectangle.x + event.x) / 2
                        x -= textFormatMenu.width / 2

                        textFormatMenu.popup(x, -messageInputField.height-2)
                        messageInputField.forceActiveFocus();
                    }
                    lastClick = now
                }

                StatusTextFormatMenu {
                    readonly property var formationChars: (["*", "`", "~"])
                    property string selectedTextWithFormationChars: {
                        let i = 1
                        let text = ""
                        while(true) {
                            if (messageInputField.selectionStart - i < 0 && messageInputField.selectionEnd + i > messageInputField.length) {
                                break
                            }

                            text = messageInputField.getText(messageInputField.selectionStart - i, messageInputField.selectionEnd + i)

                            if (!formationChars.includes(text.charAt(0)) ||
                                    !formationChars.includes(text.charAt(text.length - 1))) {
                                break
                            }
                            i++
                        }
                        return text
                    }

                    id: textFormatMenu
                    function surroundedBy(chars) {
                        if (selectedTextWithFormationChars === "") {
                            return false
                        }

                        const firstIndex = selectedTextWithFormationChars.indexOf(chars)
                        if (firstIndex === -1) {
                            return false
                        }

                        return selectedTextWithFormationChars.lastIndexOf(chars) > firstIndex
                    }
                    StatusChatInputTextFormationAction {
                        wrapper: "**"
                        icon.name: "format-text-bold"
                        //% "Bold"
                        text: qsTrId("bold")
                    }
                    StatusChatInputTextFormationAction {
                        wrapper: "*"
                        icon.name: "format-text-italic"
                        //% "Italic"
                        text: qsTrId("italic")
                        checked: textFormatMenu.surroundedBy("*") && !textFormatMenu.surroundedBy("**")
                    }
                    StatusChatInputTextFormationAction {
                        wrapper: "~~"
                        icon.name: "format-text-strike-through"
                        icon.width: 45
                        //% "Strikethrough"
                        text: qsTrId("strikethrough")
                    }
                    StatusChatInputTextFormationAction {
                        wrapper: "`"
                        icon.name: "format-text-code"
                        icon.width: 45
                        //% "Code"
                        text: qsTrId("code")
                    }
                }
            }

            Shortcut {
                enabled: messageInputField.activeFocus
                sequence: StandardKey.Bold
                onActivated: wrapSelection("**")
            }
            Shortcut {
                enabled: messageInputField.activeFocus
                sequence: StandardKey.Italic
                onActivated: wrapSelection("*")
            }
            Shortcut {
                enabled: messageInputField.activeFocus
                sequence: "Ctrl+Shift+Alt+C"
                onActivated: wrapSelection("```")
            }
            Shortcut {
                enabled: messageInputField.activeFocus
                sequence: "Ctrl+Shift+C"
                onActivated: wrapSelection("`")
            }
            Shortcut {
                enabled: messageInputField.activeFocus
                sequence: "Ctrl+Alt+-"
                onActivated: wrapSelection("~~")
            }
            Shortcut {
                enabled: messageInputField.activeFocus
                sequence: "Ctrl+Shift+X"
                onActivated: wrapSelection("~~")
            }
            Shortcut {
                enabled: messageInputField.activeFocus
                sequence: "Ctrl+Meta+Space"
                onActivated: emojiBtn.clicked()
            }

        }

        Rectangle {
            color: parent.color
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            visible: !control.isStatusUpdateInput
            height: parent.height / 2
            width: 32
            radius: Style.current.radius
        }

        StyledText {
            id: messageLengthLimit
            property int remainingChars: messageLimit - messageInputField.length
            text: remainingChars.toString()
            visible: remainingChars <= control.messageLimitVisible
            color: (remainingChars <= 0) ? Style.current.danger : Style.current.textColor
            anchors.right: parent.right
            anchors.bottom: actions.top
            anchors.rightMargin: control.isStatusUpdateInput ? Style.current.padding : Style.current.radius
            leftPadding: Style.current.halfPadding
            rightPadding: Style.current.halfPadding
        }

        Item {
            id: actions
            width: control.isStatusUpdateInput ?
              imageBtn2.width + sendBtn.anchors.leftMargin + sendBtn.width :
              emojiBtn.width + stickersBtn.anchors.leftMargin + stickersBtn.width
            anchors.bottom: control.isStatusUpdateInput && extendedArea.visible ? extendedArea.bottom : parent.bottom
            anchors.bottomMargin: control.isStatusUpdateInput ? Style.current.smallPadding+2: 4
            anchors.right: parent.right
            anchors.rightMargin: Style.current.radius
            height: emojiBtn.height

            StatusIconButton {
                id: imageBtn2
                icon.name: "images_icon"
                icon.height: 18
                icon.width: 20
                anchors.right: sendBtn.left
                anchors.rightMargin: 2
                anchors.bottom: parent.bottom
                visible: control.isStatusUpdateInput

                onClicked: {
                    highlighted = true
                    imageDialog.open()
                }
            }

            StatusButton {
                id: sendBtn
                icon.source: "../../app/img/send.svg"
                icon.width: 16
                icon.height: 18
                borderRadius: 16
                //% "Send"
                text: qsTrId("command-button-send")
                type: "secondary"
                flat: true
                showBorder: true
                forceBgColorOnHover: true
                anchors.right: parent.right
                anchors.rightMargin: Style.current.halfPadding
                anchors.bottom: parent.bottom
                visible: imageBtn2.visible
                highlighted: chatsModel.plainText(Emoji.deparse(messageInputField.text)).length > 0 || isImage
                enabled: highlighted && messageInputField.length < messageLimit
                onClicked: function (event) {
                    control.sendMessage(event)
                    control.hideExtendedArea();
                }
            }

            StatusIconButton {
                id: emojiBtn
                visible: !imageBtn2.visible
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                icon.name: "emojiBtn"
                type: "secondary"
                onClicked: {
                    stickersPopup.close()
                    if (emojiPopup.opened) {
                        emojiPopup.close()
                        highlighted = false
                    } else {
                        emojiPopup.open()
                        highlighted = true
                    }
                }
            }

            StatusIconButton {
                id: stickersBtn
                anchors.left: emojiBtn.right
                anchors.leftMargin: 2
                anchors.bottom: parent.bottom
                icon.name: "stickers_icon"
                visible: profileModel.network.current === Constants.networkMainnet && emojiBtn.visible
                width: visible ? 32 : 0
                type: "secondary"
                onClicked: {
                    emojiPopup.close()
                    if (stickersPopup.opened) {
                        stickersPopup.close()
                        highlighted = false
                    } else {
                        stickersPopup.open()
                        highlighted = true
                    }
                }
            }
        }
    }
}
