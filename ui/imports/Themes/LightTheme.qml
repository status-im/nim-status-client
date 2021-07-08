import QtQuick 2.13
import "."

Theme {
    property string name: "light"

    property color white: "#FFFFFF"
    property color white2: "#FCFCFC"
    property color black: "#000000"
    property color grey: "#EEF2F5"
    property color grey1: "#F0F2F5"
    property color grey2: "#F6F8FA"
    property color grey3: "#E9EDF1"
    property color midGrey: "#7f8990"
    property color lightGrey: "#ccd0d4"
    property color lightBlue: "#ECEFFC"
    property color translucentBlue: "#1a4360df"
    property color cyan: "#00FFFF"
    property color blue: "#4360DF"
    property color darkAccentBlue: "#2946C4"
    property color transparent: "#00000000"
    property color darkGrey: "#939BA1"
    property color lighterDarkGrey: "#b3bec6"
    property color lightBlueText: "#8f9fec"
    property color darkBlue: "#3c55c9"
    property color darkBlueBtn: "#5a70dd"
    property color red: "#FF2D55"
    property color lightRed: "#FFEAEE"
    property color green: "#4EBC60"
    property color turquoise: "#007b7d"
    property color tenPercentBlack: Qt.rgba(0, 0, 0, 0.1)
    property color fivePercentBlack: "#E5E5E5"
    property color tenPercentBlue: Qt.rgba(67, 96, 223, 0.1)
    property color orange: "#FFA500"

    property color background: white
    property color appBarDividerColor: darkGrey
    property color border: grey
    property color borderSecondary: tenPercentBlack
    property color borderTertiary: blue
    property color separator: grey
    property color textColor: black
    property color textColorTertiary: blue
    property color linkColor: blue
    property color currentUserTextColor: white
    property color secondaryBackground: lightBlue
    property color inputBackground: grey
    property color secondaryInputBackground: fivePercentBlack
    property color secondaryInputText: textColor
    property color inputBorderFocus: blue
    property color secondaryMenuBorder: grey3
    property color inputColor: black
    property color modalBackground: white2
    property color backgroundHover: grey
    property color menuBackgroundActive: grey3
    property color menuBackgroundHover: grey1
    property color backgroundHoverLight: grey
    property color secondaryText: darkGrey
    property color secondaryHover: tenPercentBlack
    property color primary: blue
    property color danger: red
    property color success: green
    property color primaryMenuItemHover: blue
    property color primaryMenuItemTextHover: white
    property color backgroundTertiary: tenPercentBlue
    property color pillButtonTextColor: white
    property color chatReplyCurrentUser: darkGrey
    property color codeBackground: "#2E386B"
    property color primarySelectionColor: "#b4c8ff"
    property color emojiReactionBackground: "#e2e6e9"
    property color emojiReactionBackgroundHovered: "#d7dadd"
    property color emojiReactionActiveBackgroundHovered: "#cbd5f1"
    property color mentionColor: "#0DA4C9"
    property color mentionBgColor: "#1a07bce9"
    property color mentionBgHoverColor: "#4d07bce9"
    property color mentionMessageColor: "#1a07bce9"
    property color mentionMessageHoverColor: "#3307bce9"
    property color replyBackground: "#d7dadd"
    property color mainMenuBackground: grey1
    property color secondaryMenuBackground: grey2
    property color tabButtonBg: translucentBlue

    property color buttonForegroundColor: blue
    property color buttonBackgroundColor: translucentBlue
    property color buttonBackgroundColorHover: "#334360df"
    property color buttonSecondaryColor: darkGrey
    property color buttonDisabledForegroundColor: buttonSecondaryColor
    property color buttonDisabledBackgroundColor: grey
    property color buttonWarnBackgroundColor: "#1aff2d55"
    property color buttonOutlineHoveredWarnBackgroundColor: "#1affeaee"
    property color buttonHoveredWarnBackgroundColor: "#33ff2d55"
    property color buttonHoveredBackgroundColor: blue

    property color contextMenuButtonForegroundColor: black
    property color contextMenuButtonBackgroundHoverColor: Qt.hsla(black.hslHue, black.hslSaturation, black.hslLightness, 0.1)

    property color pinnedMessageBorder: "#FE8F59"
    property color pinnedMessageBackground: "#1aFF9F0F"
    property color pinnedMessageBackgroundHovered: "#33FF9F0F"
    property color pinnedRectangleBackground: "#1aFE8F59"

    property color roundedButtonForegroundColor: buttonForegroundColor
    property color roundedButtonBackgroundColor: secondaryBackground
    property color roundedButtonSecondaryForegroundColor: grey2
    property color roundedButtonSecondaryBackgroundColor: buttonForegroundColor
    property color roundedButtonSecondaryHoveredBackgroundColor: darkAccentBlue
    property color roundedButtonDisabledForegroundColor: buttonDisabledForegroundColor
    property color roundedButtonDisabledBackgroundColor: buttonDisabledBackgroundColor
    property color roundedButtonSecondaryDisabledForegroundColor: grey2
    property color roundedButtonSecondaryDisabledBackgroundColor: buttonDisabledForegroundColor
    property color tooltipBackgroundColor: black
    property color tooltipForegroundColor: white
    property color chatInfoButtonBackgroundHoverColor: grey1

    property var accountColors: [
        blue,
        "#9B832F",
        "#D37EF4",
        "#1D806F",
        "#FA6565",
        "#7CDA00",
        "#887Af9",
        "#8B3131"
    ]
}
