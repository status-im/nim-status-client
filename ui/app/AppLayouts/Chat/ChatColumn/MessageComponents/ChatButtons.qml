import QtQuick 2.13
import QtGraphicalEffects 1.13
import "../../../../../shared"
import "../../../../../shared/status"
import "../../../../../imports"

Rectangle {
    property bool parentIsHovered: false
    property bool showEdit: true
    signal hoverChanged(bool hovered)
    property int containerMargin: 2
    property int contentType: 2

    id: buttonsContainer
    visible: !activityCenterMessage &&
             (buttonsContainer.parentIsHovered || isMessageActive)
             && contentType !== Constants.transactionType
    width: buttonRow.width + buttonsContainer.containerMargin * 2
    height: 36
    radius: Style.current.radius
    color: Style.current.modalBackground
    z: 52

    layer.enabled: true
    layer.effect: DropShadow {
        width: buttonsContainer.width
        height: buttonsContainer.height
        x: buttonsContainer.x
        y: buttonsContainer.y + 10
        visible: buttonsContainer.visible
        source: buttonsContainer
        horizontalOffset: 0
        verticalOffset: 2
        radius: 10
        samples: 15
        color: "#22000000"
    }

    MouseArea {
        anchors.fill: buttonsContainer
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onEntered: {
            buttonsContainer.hoverChanged(true)
        }
        onExited: {
            buttonsContainer.hoverChanged(false)
        }
    }

    Row {
        id: buttonRow
        spacing: buttonsContainer.containerMargin
        anchors.left: parent.left
        anchors.leftMargin: buttonsContainer.containerMargin
        anchors.verticalCenter: buttonsContainer.verticalCenter
        height: parent.height - 2 * buttonsContainer.containerMargin

        StatusIconButton {
            id: emojiBtn
            icon.name: "emoji"
            width: 32
            height: 32
            onClicked: {
                setMessageActive(messageId, true)
                clickMessage(false, false, false, null, true)
                if (!forceHoverHandler) {
                    messageContextMenu.x = buttonsContainer.x + buttonsContainer.width - messageContextMenu.width

                    // The Math.max is to make sure that the menu is rendered
                    messageContextMenu.y -= Math.max(messageContextMenu.emojiContainer.height, 56) + Style.current.padding
                }
            }
            onHoveredChanged: {
                buttonsContainer.hoverChanged(this.hovered)
            }

            StatusToolTip {
              visible: emojiBtn.hovered
              //% "Add reaction"
              text: qsTrId("add-reaction")
            }
        }

        StatusIconButton {
            id: replyBtn
            icon.name: "reply"
            width: 32
            height: 32
            onClicked: {
                SelectedMessage.set(messageId, fromAuthor);
                showReplyArea()
            }
            onHoveredChanged: {
                buttonsContainer.hoverChanged(this.hovered)
            }

            StatusToolTip {
              visible: replyBtn.hovered
              //% "Reply"
              text: qsTrId("message-reply")
            }
        }

        Loader {
            id: editBtn
            active: isText && !isEdit && isCurrentUser && showEdit
            sourceComponent: StatusIconButton {
                id: btn
                icon.name: "edit-message"
                width: 32
                height: 32
                onClicked: {
                    isEdit = true
                }
                onHoveredChanged: {
                    buttonsContainer.hoverChanged(btn.hovered)
                }

                StatusToolTip {
                    visible: btn.hovered
                    text: qsTr("Edit")
                }
            }
        }

        StatusIconButton {
            id: otherBtn
            icon.name: "dots-icon"
            width: 32
            height: 32
            onClicked: {
                if (typeof isMessageActive !== "undefined") {
                    setMessageActive(messageId, true)
                }
                clickMessage(false, isSticker, false, null, false, true)
            }
            onHoveredChanged: {
                buttonsContainer.hoverChanged(this.hovered)
            }

            StatusToolTip {
                visible: otherBtn.hovered
                text: qsTr("More")
            }
        }
    }
}
