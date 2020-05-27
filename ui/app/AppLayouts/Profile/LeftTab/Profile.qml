import QtGraphicalEffects 1.12
import QtQuick 2.0
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.3
import "../../../../imports"

RowLayout {
    id: profileHeader
    height: 240
    Layout.fillWidth: true
    width: profileInfoContainer.w

    Rectangle {
        id: profileHeaderContent
        height: parent.height
        Layout.fillWidth: true

        Item {
            id: profileImgNameContainer
            width: profileHeaderContent.width
            height: profileHeaderContent.height
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            Image {
                id: profileImg
                source: profileModel.profile.identicon
                width: 80
                height: 80
                fillMode: Image.PreserveAspectCrop
                anchors.horizontalCenter: parent.horizontalCenter

                property bool rounded: true
                property bool adapt: false
                y: 78

                layer.enabled: rounded
                layer.effect: OpacityMask {
                    maskSource: Item {
                        width: profileImg.width
                        height: profileImg.height
                        Rectangle {
                            anchors.centerIn: parent
                            width: profileImg.adapt ? profileImg.width : Math.min(profileImg.width, profileImg.height)
                            height: profileImg.adapt ? profileImg.height : width
                            radius: Math.min(width, height)
                        }
                    }
                }
            }

            Text {
                id: profileName
                text: profileModel.profile.username
                anchors.top: profileImg.bottom
                anchors.topMargin: 10
                anchors.horizontalCenterOffset: 0
                anchors.horizontalCenter: parent.horizontalCenter
                font.weight: Font.Medium
                font.pixelSize: 20
            }
        }
    }
}
