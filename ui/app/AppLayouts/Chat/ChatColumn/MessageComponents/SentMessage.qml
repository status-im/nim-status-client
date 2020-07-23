import QtQuick 2.3
import "../../../../../shared"
import "../../../../../imports"

StyledText {
    id: sentMessage
    visible: isCurrentUser && !timeout && !isExpired && isMessage
    color: Style.current.darkGrey
    text: outgoingStatus === "sent" ?
    //% "Sent"
    qsTrId("status-sent") :
    //% "Sending..."
    qsTrId("sending")
    font.pixelSize: 10
}
