import QtQuick 2.12
import QtGraphicalEffects 1.0

Rectangle {
    id: root
    signal clicked
    property bool noHover: false
    property alias showLoadingIndicator: imgStickerPackThumb.showLoadingIndicator
    property alias source: imgStickerPackThumb.source
    property alias fillMode: imgStickerPackThumb.fillMode

    radius: width / 2

    width: 24
    height: 24

    // apply rounded corners mask
    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            x: root.x; y: root.y
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    ImageLoader {
        id: imgStickerPackThumb
        noHover: root.noHover
        opacity: 1
        smooth: false
        radius: root.radius
        anchors.fill: parent
        source: "image://ipfs-cache/" + thumbnail
        onClicked: root.clicked()
    }
}
