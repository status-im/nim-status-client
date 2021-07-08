import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0
import "../../imports"
import "../../shared"

import "./emojiList.js" as EmojiJSON

Popup {
    id: popup
    property var emojiSelected: function () {}
    property var categories: []
    property alias searchString: searchBox.text
    property var skinColors: ["1f3fb", "1f3fc", "1f3fd", "1f3fe", "1f3ff"]

    modal: false
    width: 360
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    background: Rectangle {
        radius: Style.current.radius
        color: Style.current.background
        border.color: Style.current.border
        layer.enabled: true
        layer.effect: DropShadow{
            verticalOffset: 3
            radius: 8
            samples: 15
            fast: true
            cached: true
            color: "#22000000"
        }
    }

    function containsSkinColor(code) {
      return skinColors.some(function (color) {
        return code.includes(color)
      });
    }

    function addEmoji(emoji) {
        const MAX_EMOJI_NUMBER = 36
        const extenstionIndex = emoji.filename.lastIndexOf('.');
        let iconCodePoint = emoji.filename
        if (extenstionIndex > -1) {
            iconCodePoint = iconCodePoint.substring(0, extenstionIndex)
        }

        // Split the filename to get all the parts and then encode them from hex to utf8
        const splitCodePoint = iconCodePoint.split('-')
        let codePointParts = []
        splitCodePoint.forEach(function (codePoint) {
            codePointParts.push(`0x${codePoint}`)
        })
        const encodedIcon = String.fromCodePoint(...codePointParts);

        // Add at the  start of the list
        let recentEmojis = appSettings.recentEmojis
        recentEmojis.unshift(emoji)
        // Remove duplicates
        recentEmojis = recentEmojis.filter(function (e, index) {
            return !recentEmojis.some(function (e2, index2) {
                return index2 < index && e2.filename === e.filename
            })
        })
        if (recentEmojis.length > MAX_EMOJI_NUMBER) {
            // remove last one
            recentEmojis.splice(MAX_EMOJI_NUMBER - 1)
        }
        emojiSectionsRepeater.itemAt(0).allEmojis = recentEmojis
        appSettings.recentEmojis = recentEmojis

        popup.emojiSelected(Emoji.parse(encodedIcon) + ' ', true) // Adding a space because otherwise, some emojis would fuse since emoji is just a string
        popup.close()
    }

    function populateCategories() {
        var categoryNames = {"recent": 0}
        var newCategories = [[]]

        EmojiJSON.emoji_json.forEach(function (emoji) {
            if (!categoryNames[emoji.category] && categoryNames[emoji.category] !== 0) {
                categoryNames[emoji.category] = newCategories.length
                newCategories.push([])
            }

            var emojisWithColors = [
                        "1f64c",
                        "1f44f",
                        "1f44b",
                        "1f44d",
                        "1f44e",
                        "1f44a",
                        "270a",
                        "270c",
                        "1f44c",
                        "270b",
                        "1f450",
                        "1f4aa",
                        "1f64f",
                        "261d",
                        "1f446",
                        "1f447",
                        "1f448",
                        "1f449",
                        "1f595",
                        "1f590",
                        "1f918",
                        "1f596",
                        "270d",
                        "1f485",
                        "1f442",
                        "1f443",
                        "1f476",
                        "1f466",
                        "1f467",
                        "1f468",
                        "1f469",
                        "1f471",
                        "1f474",
                        "1f475",
                        "1f472",
                        "1f473",
                        "1f46e",
                        "1f477",
                        "1f482",
                        "1f385",
                        "1f47c",
                        "1f478",
                        "1f470",
                        "1f6b6",
                        "1f3c3",
                        "1f483",
                        "1f647",
                        "1f481",
                        "1f645",
                        "1f646",
                        "1f64b",
                        "1f64e",
                        "1f64d",
                        "1f487",
                        "1f486",
                        "1f6a3",
                        "1f3ca",
                        "1f3c4",
                        "1f6c0",
                        "26f9",
                        "1f3cb",
                        "1f6b4",
                        "1f6b5",
                        "1f3c7",
                        "1f575"
                    ]


            if (appSettings.skinColor !== "") {
                if (emoji.unicode.includes(appSettings.skinColor)) {
                    newCategories[categoryNames[emoji.category]].push(Object.assign({}, emoji, {filename: emoji.unicode + '.svg'}));
                } else {
                    if (!emojisWithColors.includes(emoji.unicode) && !containsSkinColor(emoji.unicode))  {
                        newCategories[categoryNames[emoji.category]].push(Object.assign({}, emoji, {filename: emoji.unicode + '.svg'}));
                    }
                }
            } else {
                if (!containsSkinColor(emoji.unicode)) {
                    newCategories[categoryNames[emoji.category]].push(Object.assign({}, emoji, {filename: emoji.unicode + '.svg'}));
                }
            }
        })

        if (newCategories[categoryNames.recent].length === 0) {
            newCategories[categoryNames.recent].push({category: "recent", empty: true })
        }

        categories = newCategories;
    }

    Connections {
        id: connectionSettings
        target: appMain
        function onSettingsLoaded() {
            connectionSettings.enabled = false
            // Add recent
            if (!appSettings.recentEmojis || !appSettings.recentEmojis.length) {
                return
            }
            categories[0] = appSettings.recentEmojis
            emojiSectionsRepeater.itemAt(0).allEmojis = appSettings.recentEmojis
        }
    }

    onOpened: {
        searchBox.text = ""
        searchBox.forceActiveFocus(Qt.MouseFocusReason)
        Qt.callLater(populateCategories);
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            property int headerMargin: 8

            id: emojiHeader
            Layout.fillWidth: true
            height: searchBox.height + emojiHeader.headerMargin

            SearchBox {
                id: searchBox
                anchors.right: skinToneEmoji.left
                anchors.rightMargin: emojiHeader.headerMargin
                anchors.top: parent.top
                anchors.topMargin: emojiHeader.headerMargin
                anchors.left: parent.left
                anchors.leftMargin: emojiHeader.headerMargin
            }

            Row {
                id: skinToneEmoji
                property bool expandSkinColorOptions: false
                width: expandSkinColorOptions ? (22 * skinColorEmojiRepeater.count) : 22
                height: 22
                opacity: expandSkinColorOptions ? 1.0 : 0.0
                Behavior on width { NumberAnimation  { duration: 400 } }
                Behavior on opacity { NumberAnimation  { duration: 200 } }
                visible: (opacity > 0.1)
                anchors.verticalCenter: searchBox.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: emojiHeader.headerMargin
                Repeater {
                    id: skinColorEmojiRepeater
                    model: ["1f590-1f3fb", "1f590-1f3fc", "1f590-1f3fd", "1f590-1f3fe", "1f590-1f3ff", "1f590"]
                    delegate: SVGImage {
                        width: 22
                        height: 22
                        source: "../../imports/twemoji/72x72/" + modelData + ".png"
                        MouseArea {
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent
                            onClicked: {
                                appSettings.skinColor = (index === 5) ? "" : modelData.split("-")[1];
                                popup.populateCategories();
                                skinToneEmoji.expandSkinColorOptions = false;
                            }
                        }
                    }
                }
            }

            SVGImage {
                width: 22
                height: 22
                anchors.verticalCenter: searchBox.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: emojiHeader.headerMargin
                visible: !skinToneEmoji.expandSkinColorOptions
                source: "../../imports/twemoji/72x72/1f590" + ((appSettings.skinColor !== "" && visible) ? ("-" + appSettings.skinColor) : "") + ".png"
                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: {
                        skinToneEmoji.expandSkinColorOptions = true;
                    }
                }
            }
        }

        ScrollView {
            property ScrollBar vScrollBar: ScrollBar.vertical
            property var categrorySectionHeightRatios: []
            property int activeCategory: 0

            id: scrollView
            topPadding: Style.current.smallPadding
            leftPadding: Style.current.smallPadding
            rightPadding: Style.current.smallPadding / 2
            Layout.fillWidth: true
            Layout.rightMargin: Style.current.smallPadding / 2
            Layout.topMargin: Style.current.smallPadding
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            Layout.preferredHeight: 400 - Style.current.smallPadding - emojiHeader.height
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOn
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ScrollBar.vertical.onPositionChanged: function () {
                if (vScrollBar.position < categrorySectionHeightRatios[scrollView.activeCategory - 1]) {
                    scrollView.activeCategory--
                } else if (vScrollBar.position > categrorySectionHeightRatios[scrollView.activeCategory]) {
                    scrollView.activeCategory++
                }
            }

            function scrollToCategory(category) {
                if (category === 0) {
                    return vScrollBar.setPosition(0)
                }
                vScrollBar.setPosition(categrorySectionHeightRatios[category - 1])
            }

            contentHeight: {
                var totalHeight = 0
                var categoryHeights = []
                for (let i = 0; i < emojiSectionsRepeater.count; i++) {
                    totalHeight += emojiSectionsRepeater.itemAt(i).height + Style.current.padding
                    categoryHeights.push(totalHeight)
                }
                var ratios = []
                categoryHeights.forEach(function (catHeight) {
                    ratios.push(catHeight / totalHeight)
                })

                categrorySectionHeightRatios = ratios
                return totalHeight + Style.current.padding
            }

            Repeater {
                id: emojiSectionsRepeater
                model: popup.categories

                StatusEmojiSection {
                    searchString: popup.searchString
                    addEmoji: popup.addEmoji
                }
            }
        }

        Row {
            Layout.fillWidth: true
            height: 40
            leftPadding: Style.current.smallPadding / 2
            rightPadding: Style.current.smallPadding / 2
            spacing: 0

            Repeater {
                model: EmojiJSON.emojiCategories

                StatusEmojiCategoryButton {
                    source: `../../app/img/emojiCategories/${modelData}.svg`
                    active: index === scrollView.activeCategory
                    changeCategory: function () {
                        scrollView.activeCategory = index
                        scrollView.scrollToCategory(index)
                    }
                }
            }
        }
    }
}
/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";height:440;width:360}
}
##^##*/
