import QtQuick 2.14
import "../../../../../shared"
import "../../../../../shared/status"
import "../../../../../imports"

StyledText {
    property bool formatDateTime: false
    id: chatTime
    visible: isMessage
    color: Style.current.secondaryText
    text: formatDateTime ? Utils.formatDateTime(timestamp, globalSettings.locale) : Utils.formatTime(timestamp, globalSettings.locale)
    font.pixelSize: Style.current.asideTextFontSize
    
    StatusToolTip {
        visible: hhandler.hovered
        text: new Date(parseInt(timestamp, 10)).toLocaleString(Qt.locale(globalSettings.locale))
        maxWidth: 350
    }

    HoverHandler {
        id: hhandler
    }
}
