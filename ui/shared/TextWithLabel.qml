import QtQuick 2.12
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.12
import "../imports"

Item {
    property string text: "My Text"
    property string label: "My Label"
    readonly property int labelMargin: 7

    id: inputBox
    height: textItem.height + inputLabel.height + labelMargin
    anchors.right: parent.right
    anchors.left: parent.left

    Text {
        id: inputLabel
        text: inputBox.label
        font.weight: Font.Medium
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.top: parent.top
        anchors.topMargin: 0
        font.pixelSize: 13
        color: Theme.darkGrey
    }

    TextEdit {
        id: textItem
        text: inputBox.text
        selectByMouse: true
        readOnly: true
        font.weight: Font.Medium
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.top: inputLabel.bottom
        anchors.topMargin: inputBox.labelMargin
        font.pixelSize: 15
        color: Theme.black
    }
}

/*##^##
Designer {
    D{i:0;formeditorColor:"#ffffff";formeditorZoom:1.25}
}
##^##*/

