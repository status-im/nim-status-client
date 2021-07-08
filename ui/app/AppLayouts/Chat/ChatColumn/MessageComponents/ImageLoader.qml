import QtQuick 2.3
import QtGraphicalEffects 1.13
import "../../../../../shared"
import "../../../../../imports"

Item {
    property int verticalPadding: 0
    property int imageWidth: 350
    property bool isCurrentUser: false
    property url source
    property bool playing: true
    property bool isAnimated: !!source && source.toString().endsWith('.gif')
    signal clicked(var image)
    property var container
    property alias imageAlias: imageMessage
    property bool allCornersRounded: false

    id: imageContainer
    width: loadingImage.visible ? loadingImage.width : imageMessage.width
    height: loadingImage.visible ? loadingImage.height : imageMessage.paintedHeight

    Rectangle {
        id: loadingImage
        property bool hasError: false
        width: hasError ? 200 : imageContainer.imageWidth
        height: hasError ? 75 : imageContainer.imageWidth
        border.width: 1
        border.color: Style.current.border
        radius: Style.current.radius

        StyledText {
            //% "Error loading the image"
            text: loadingImage.hasError ? qsTrId("error-loading-the-image") :
                //% "Loading image..."
                qsTrId("loading-image---")
            color: loadingImage.hasError ? Style.current.red : Style.current.textColor
            font.pixelSize: 15
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Connections {
        target: applicationWindow
        function onActiveChanged() {
            if (applicationWindow.active === false) {
                imageMessage.playing = false
            } else {
                imageMessage.playing = Qt.binding(function () {return imageContainer.playing})
            }
        }
    }

    AnimatedImage {
        id: imageMessage
        width: sourceSize.width > imageWidth ? imageWidth : sourceSize.width
        fillMode: Image.PreserveAspectFit
        source: imageContainer.source
        playing: imageContainer.playing
        onStatusChanged: {
            if (imageMessage.status === Image.Error) {
                loadingImage.hasError = true
                imageMessage.height = 0
                imageMessage.source = ""
                imageMessage.visible = false
            } else if (imageMessage.status === Image.Ready) {
                loadingImage.visible = false
                scrollToBottom(true, imageContainer.container)
            }
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Item {
                width: imageMessage.width
                height: imageMessage.height

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    width: imageMessage.width
                    height: imageMessage.height
                    radius: 16
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: 32
                    height: 32
                    radius: 4
                    visible: !imageContainer.isCurrentUser && !allCornersRounded
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 32
                    height: 32
                    radius: 4
                    visible: imageContainer.isCurrentUser && !allCornersRounded
                }
            }
        }

        MouseArea {
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            onClicked: {
                if (imageContainer.isAnimated) {
                    // FIXME the ListView completely removes Items that scroll out of view
                    // so when we scroll backto the image, it gets reloaded and playing is reset
                    imageContainer.playing = !imageContainer.playing
                    return
                }
                imageContainer.clicked(imageMessage)
            }
        }
    }
}
