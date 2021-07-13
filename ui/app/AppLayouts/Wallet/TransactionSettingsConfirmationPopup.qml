import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.13
import "../../../imports"
import "../../../shared/status"
import "../../../shared"

ModalPopup {
    id: popup

    height: 450
    width: 400
    title: qsTr("Are you sure?")

    property var onConfirm: function(){}

    property double currentBaseFee: 0
    property double currentMinimumTip: 0
    property double currentAverageTip: 0
    property double tipLimit: 0
    property double suggestedTipLimit: 0
    property double priceLimit: 0
    property double suggestedPriceLimit: 0

    Column {
        id: content
        width: 450
        height: parent.height
        spacing: 10

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Style.current.smallPadding
            text: qsTr("Your priority fee is below our suggested parameters.")
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            color: Style.current.secondaryText
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.current.smallPadding
            height: 20

            StyledText {
                text: qsTr("Current base fee")
                font.pixelSize: 13
                width: 190
                anchors.left: parent.left
            }

            StyledText {
                text: qsTr("%1 Gwei").arg(currentBaseFee)
                font.pixelSize: 13
                width: 190
                anchors.right: parent.right
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.current.smallPadding
            height: 20

            StyledText {
                text: qsTr("Current minimum tip")
                font.pixelSize: 13
                width: 190
                anchors.left: parent.left
            }

            StyledText {
                text: qsTr("%1 Gwei").arg(currentMinimumTip)
                font.pixelSize: 13
                width: 190
                anchors.right: parent.right
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.current.smallPadding
            height: 20

            StyledText {
                text: qsTr("Current average tip")
                font.pixelSize: 13
                width: 190
                anchors.left: parent.left
            }

            StyledText {
                text: qsTr("%1 Gwei").arg(currentAverageTip)
                font.pixelSize: 13
                width: 190
                anchors.right: parent.right
            }
        }

        Rectangle {
            id: tipLimitRect
            width: 368
            height: 70
            radius: 8
            color: Style.current.backgroundHoverLight

            Column {
                anchors.top: parent.top
                anchors.topMargin: Style.current.smallPadding
                anchors.left: parent.left
                anchors.leftMargin: Style.current.smallPadding
                height: 100
                width: 450 - Style.current.smallPadding
                spacing: 10

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 20
                    StyledText {
                        text: qsTr("Your tip limit")
                        font.pixelSize: 13
                        width: 190
                        anchors.left: parent.left
                        color: Style.current.red
                    }

                    StyledText {
                        text: qsTr("%1 Gwei").arg(tipLimit)
                        font.pixelSize: 13
                        width: 190
                        anchors.right: parent.right
                        color: Style.current.red
                    }
                }

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 20

                    StyledText {
                        text: qsTr("Suggested minimum tip")
                        font.pixelSize: 13
                        width: 190
                        anchors.left: parent.left
                    }

                    StyledText {
                        text: qsTr("%1 Gwei").arg(suggestedTipLimit)
                        font.pixelSize: 13
                        width: 190
                        anchors.right: parent.right
                    }
                }
            }
            
        }

        Rectangle {
            id: minPriceLimitRect
            width: 368
            height: 70
            radius: 8
            color: Style.current.backgroundHoverLight

            Column {
                anchors.top: parent.top
                anchors.topMargin: Style.current.smallPadding
                anchors.left: parent.left
                anchors.leftMargin: Style.current.smallPadding
                height: 100
                width: 450 - Style.current.smallPadding
                spacing: 10

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 20
                    StyledText {
                        text: qsTr("Your price limit")
                        font.pixelSize: 13
                        width: 190
                        anchors.left: parent.left
                        color: Style.current.red
                    }

                    StyledText {
                        text: qsTr("%1 Gwei").arg(priceLimit)
                        font.pixelSize: 13
                        width: 190
                        anchors.right: parent.right
                        color: Style.current.red
                    }
                }

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 20

                    StyledText {
                        text: qsTr("Suggested minimum price limit")
                        font.pixelSize: 13
                        width: 190
                        anchors.left: parent.left
                    }

                    StyledText {
                        text: qsTr("%1 Gwei").arg(suggestedPriceLimit)
                        font.pixelSize: 13
                        width: 190
                        anchors.right: parent.right
                    }
                }
            }
        }

    }
    
    footer: Item {
        id: footerContainer
        width: parent.width
        height: popup.height

        StatusButton {
            id: cancelButton
            anchors.right: confirmButton.left
            anchors.rightMargin: Style.current.smallPadding
            text: qsTr("Change Limit")
            anchors.bottom: parent.bottom
            onClicked: popup.destroy()
        }

        StatusButton {
            id: confirmButton
            type: "warn"
            anchors.right: parent.right
            anchors.rightMargin: Style.current.smallPadding        
            text: qsTr("Continue anyway")
            anchors.bottom: parent.bottom
            onClicked: {
                popup.onConfirm();
                destroy();
            }
        }
    }
}



