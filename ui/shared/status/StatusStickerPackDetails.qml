import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.3
import "../../imports"
import "../../shared"

Item {
    id: root
    default property alias content: rest.children
    property string packThumb: "QmfZrHmLR5VvkXSDbArDR3TX6j4FgpDcrvNz2fHSJk1VvG"
    property string packName: "Status Cat"
    property string packAuthor: "cryptoworld1373"
    property int packNameFontSize: 15
    property int spacing: Style.current.padding

    RoundedImage {
        id: imgThumb
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        source: "image://ipfs-cache/" + packThumb
    }
    Column {
        anchors.left: imgThumb.right
        anchors.leftMargin: root.spacing
        anchors.verticalCenter: parent.verticalCenter
        Text {
            id: txtPackName
            text: packName
            color: Style.current.textColor
            font.family: Style.current.fontBold.name
            font.weight: Font.Bold
            font.pixelSize: packNameFontSize
        }
        Text {
            color: Style.current.darkGrey
            text: packAuthor
            font.family: Style.current.fontRegular.name
            font.pixelSize: 15
        }
    }
    Item {
        anchors.right: parent.right
        id: rest
    }
}
