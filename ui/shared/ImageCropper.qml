import QtQuick 2.13
import "."
import "../imports"

Item {
    id: root
    property Image image
    property alias selectorRectangle: selectorRectangle
    property string ratio: ""
    property var splitRatio: !!ratio ? ratio.split(":") : null
    property int widthRatio: !!ratio ? parseInt(splitRatio[0]) : -1
    property int heightRatio: !!ratio ? parseInt(splitRatio[1]) : -1
    property bool settingCorners: false
    property int draggedCorner: 0
    property bool ready: false

    readonly property int topLeft: 0
    readonly property int topRight: 1
    readonly property int bottomLeft: 2
    readonly property int bottomRight: 3

    width: image.width
    height: image.height

    Rectangle {
        id: selectorRectangle
        visible: false
        x: 0
        y: 0
        border.width: 2
        border.color: Style.current.orange
        color: Style.current.transparent

        function fitRatio(makeBigger) {
            if (!!ratio) {
                if ((makeBigger && selectorRectangle.width < selectorRectangle.height) || (!makeBigger && selectorRectangle.width > selectorRectangle.height)) {
                    selectorRectangle.width = (selectorRectangle.height/heightRatio) * widthRatio
                } else {
                    selectorRectangle.height = (selectorRectangle.width/widthRatio) * heightRatio
                }
            }
        }

        function initialSetup() {
            selectorRectangle.width = image.width
            selectorRectangle.height =  image.height

            fitRatio()
            topLeftCorner.x = 0
            topLeftCorner.y = 0
            topRightCorner.x = selectorRectangle.width - topRightCorner.width
            topRightCorner.y = 0
            bottomLeftCorner.x = 0
            bottomLeftCorner.y = selectorRectangle.height - topRightCorner.height
            bottomRightCorner.x = selectorRectangle.width - topRightCorner.width
            bottomRightCorner.y = selectorRectangle.height - topRightCorner.height
        }


        function adjustRectangleSize() {
            if (!selectorRectangle.visible) {
                return
            }

            selectorRectangle.width = bottomRightCorner.x + bottomRightCorner.width - topLeftCorner.x
            selectorRectangle.height = bottomRightCorner.y + bottomRightCorner.height - topLeftCorner.y
            selectorRectangle.x = topLeftCorner.x
            selectorRectangle.y = topLeftCorner.y

            if (!!ratio) {
                // FIXME with a ratio that is not 1:1, the rectangle can go out of bounds
                fitRatio()

                switch(draggedCorner) {
                case topLeft:
                    selectorRectangle.x = topLeftCorner.x
                    selectorRectangle.y = topLeftCorner.y
                    break
                case topRight:
                    selectorRectangle.x = topRightCorner.x - selectorRectangle.width + topRightCorner.width
                    selectorRectangle.y = topRightCorner.y
                    break
                case bottomLeft:
                    selectorRectangle.x = bottomLeftCorner.x
                    selectorRectangle.y = bottomLeftCorner.y - selectorRectangle.height + bottomLeftCorner.height
                    break
                case bottomRight:
                    selectorRectangle.x = bottomRightCorner.x - selectorRectangle.width + bottomRightCorner.width
                    selectorRectangle.y = bottomRightCorner.y - selectorRectangle.height + bottomRightCorner.height
                    break
                }
            }
        }

        Connections {
            target: image
            function onStatusChanged() {
                if (image.status === Image.Ready) {
                    selectorRectangle.initialSetup()
                    selectorRectangle.visible = true
                    root.ready = true
                }
            }
        }
    }
    function putCorners() {
        settingCorners = true

        topLeftCorner.x = selectorRectangle.x
        topLeftCorner.y = selectorRectangle.y
        topRightCorner.x = selectorRectangle.x + selectorRectangle.width - topRightCorner.width
        topRightCorner.y = selectorRectangle.y
        bottomLeftCorner.x = selectorRectangle.x
        bottomLeftCorner.y = selectorRectangle.y + selectorRectangle.height - topRightCorner.height
        bottomRightCorner.x = selectorRectangle.x + selectorRectangle.width - topRightCorner.width
        bottomRightCorner.y = selectorRectangle.y + selectorRectangle.height - topRightCorner.height

        settingCorners = false
    }


    // Size calculations are only done on top-left and bottom-right, because the other two corners follow them
    CropCornerRectangle {
        id: topLeftCorner
        onXChanged: {
            if (settingCorners) return
            if (x < 0) x = 0
            if (x > topRightCorner.x - width) x = topRightCorner.x - width

            bottomLeftCorner.x = x
            selectorRectangle.adjustRectangleSize()
        }
        onYChanged: {
            if (settingCorners) return
            if (y < 0) y = 0
            if (y > bottomRightCorner.y - height) y = bottomRightCorner.y - height

            topRightCorner.y = y
            selectorRectangle.adjustRectangleSize()
        }
        onPressed: {
            draggedCorner = topLeft
        }

        onReleased: {
            putCorners()
        }
    }

    CropCornerRectangle {
        id: topRightCorner
        onXChanged: {
            if (settingCorners) return
            bottomRightCorner.x = x
        }
        onYChanged: {
            if (settingCorners) return
            topLeftCorner.y = y
        }
        onPressed: {
            draggedCorner = topRight
        }
        onReleased: {
            putCorners()
        }
    }

    CropCornerRectangle {
        id: bottomLeftCorner
        onXChanged: {
            if (settingCorners) return
            topLeftCorner.x = x
        }
        onYChanged: {
            if (settingCorners) return
            bottomRightCorner.y = y
        }
        onPressed: {
            draggedCorner = bottomLeft
        }
        onReleased: {
            putCorners()
        }
    }

    CropCornerRectangle {
        id: bottomRightCorner
        onXChanged: {
            if (settingCorners) return
            if (x < topLeftCorner.x + topLeftCorner.width) x = topLeftCorner.x + topLeftCorner.width
            if (x > image.width - width) x = image.width - width
            topRightCorner.x = x

            selectorRectangle.adjustRectangleSize()
        }
        onYChanged: {
            if (settingCorners) return
            if (y < topRightCorner.y + topRightCorner.height) y = topRightCorner.y + topRightCorner.height
            if (y > image.height - height) y = image.height - height
            bottomLeftCorner.y = y

            selectorRectangle.adjustRectangleSize()
        }
        onPressed: {
            draggedCorner = bottomRight
        }
        onReleased: {
            putCorners()
        }
    }
}
