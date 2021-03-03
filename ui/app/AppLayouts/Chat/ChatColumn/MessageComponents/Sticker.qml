import QtQuick 2.3
import "../../../../../shared" as Shared
import "../../../../../imports"

Loader {
    property color color
    property var container
    property int contentType: -1

    id: root
    active: contentType === Constants.stickerType

    sourceComponent: Component {
        Shared.ImageLoader {
            color: root.color
            onLoaded: scrollToBottom(true, root.container)

            width: 140
            height: this.visible ? 140 : 0
            source: this.visible ? "image://ipfs-cache/" + sticker) : ""
        }
    }
}
