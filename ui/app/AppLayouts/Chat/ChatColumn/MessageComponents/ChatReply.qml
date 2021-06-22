import QtQuick 2.14
import QtQuick.Shapes 1.13
import QtGraphicalEffects 1.13
import "../../../../../shared"
import "../../../../../imports"

Loader {
    property int textFieldWidth: item ? item.textField.width : 0
    property int textFieldImplicitWidth: 0
    property int authorWidth: item ? item.authorMetrics.width : 0

    property bool longReply: false
    property color elementsColor: isCurrentUser ? Style.current.chatReplyCurrentUser : Style.current.secondaryText
    property var container
    property int chatHorizontalPadding

    property int nameMargin: 6

    id: root
    active: responseTo !== "" && replyMessageIndex > -1 && !activityCenterMessage

    sourceComponent: Component {
        Item {
            property alias textField: lblReplyMessage
            property alias authorMetrics: txtAuthorMetrics

            id: chatReply
            // childrenRect.height shows a binding loop for some reason, so we use heights instead
            height: {
                const h = userImage.height + 2
                if (repliedMessageType === Constants.imageType) {
                    return h + imgReplyImage.height
                }
                if (repliedMessageType === Constants.stickerType) {
                    return h + stickerLoader.height
                }
                return h + lblReplyMessage.height
            }
            width: parent.width
            clip: true

            TextMetrics {
                id: txtAuthorMetrics
                font: lblReplyAuthor.font
                text: lblReplyAuthor.text
            }

            Shape {
                id: replyCorner
                anchors.left: parent.left
                anchors.leftMargin: 20 - 1
                anchors.top: parent.top
                anchors.topMargin: Style.current.smallPadding
                width: 20
                height: parent.height - anchors.topMargin
                asynchronous: true
                antialiasing: true

                ShapePath {
                    id: capTest

                    strokeColor: Utils.setColorAlpha(root.elementsColor, 0.4)
                    strokeWidth: 3
                    fillColor: "transparent"

                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    startX: 20
                    startY: 0
                    PathLine { x: 10; y: 0 }
                    PathArc {
                           x: 0; y: 10
                           radiusX: 13
                           radiusY: 13
                           direction: PathArc.Counterclockwise
                       }
                    PathLine { x: 0; y: chatReply.height - replyCorner.anchors.topMargin }
                }
            }

            UserImage {
                id: userImage
                imageHeight: 20
                imageWidth: 20
                active: true
                anchors.left: replyCorner.right
                anchors.leftMargin: Style.current.halfPadding
                identiconImageSource: repliedMessageUserIdenticon
                isReplyImage: true
                profileImage: repliedMessageUserImage
            }

            StyledTextEdit {
                id: lblReplyAuthor
                text: repliedMessageAuthor
                color: root.elementsColor
                readOnly: true
                font.pixelSize: Style.current.secondaryTextFontSize
                selectByMouse: true
                font.weight: Font.Medium
                anchors.verticalCenter: userImage.verticalCenter
                anchors.left: userImage.right
                anchors.leftMargin: 5
            }

            ChatImage {
                id: imgReplyImage
                visible: repliedMessageType === Constants.imageType
                imageWidth: 50
                imageSource: repliedMessageImage
                anchors.top: lblReplyAuthor.bottom
                anchors.topMargin: nameMargin
                anchors.left: userImage.left
                chatHorizontalPadding: 0
                container: root.container
                allCornersRounded: true
            }

            Loader {
                id: stickerLoader
                active: repliedMessageType === Constants.stickerType
                anchors.top: lblReplyAuthor.bottom
                anchors.topMargin: nameMargin
                anchors.left: userImage.left
                sourceComponent: Component {
                    Sticker {
                        id: stickerId
                        imageHeight: 56
                        imageWidth: 56
                        stickerData: chatsModel.messageView.messageList.getMessageData(replyMessageIndex, "sticker")
                        contentType: repliedMessageType
                        container: root.container
                    }
                }
            }

            StyledTextEdit {
                id: lblReplyMessage
                visible: repliedMessageType !== Constants.imageType && repliedMessageType !== Constants.stickerType
                Component.onCompleted: textFieldImplicitWidth = implicitWidth
                anchors.top: lblReplyAuthor.bottom
                anchors.topMargin: nameMargin
                text: Utils.getReplyMessageStyle(Emoji.parse(Utils.linkifyAndXSS(repliedMessageContent), Emoji.size.small), isCurrentUser, appSettings.useCompactMode)
                textFormat: Text.RichText
                color: root.elementsColor
                readOnly: true
                selectByMouse: true
                font.pixelSize: Style.current.secondaryTextFontSize
                anchors.left: userImage.left
                width: root.longReply ? parent.width : implicitWidth
                height: 18
                clip: true
                z: 51
            }
        }
    }
}

