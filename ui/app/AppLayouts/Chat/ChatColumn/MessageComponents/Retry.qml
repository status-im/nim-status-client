
import QtQuick 2.3
import "../../../../../shared"
import "../../../../../imports"

StyledText {
    id: retryLbl
    color: Style.current.red
    //% "Resend"
    text: qsTrId("resend-message")
    font.pixelSize: Style.current.tertiaryTextFontSize
    visible: isCurrentUser && (timeout || isExpired)
    MouseArea {
        cursorShape: Qt.PointingHandCursor
        anchors.fill: parent
        onClicked: {
            chatsModel.messageView.resendMessage(chatId, messageId)
        }
    }
}
