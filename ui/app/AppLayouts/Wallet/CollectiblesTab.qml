import QtQuick 2.13
import QtGraphicalEffects 1.13
import "../../../imports"
import "../../../shared"
import "./components/collectiblesComponents"
import "./components/collectiblesComponents/collectiblesData.js" as CollectiblesData

Item {
    id: root

    StyledText {
        id: noCollectiblesText
        color: Style.current.secondaryText
        //% "Collectibles will appear here"
        text: qsTrId("collectibles-will-appear-here")
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 15
    }

    CollectiblesModal {
        id: collectiblesModalComponent
    }

    function checkCollectiblesVisibility() {
        // Show the collectibles section only if at least one of the sub-items is visible
        // Sub-items are visible only if they are loading or have more than zero collectible
        let showCollectibles = false
        let currentItem
        for (let i = 0; i < collectiblesRepeater.count; i++) {
            currentItem = collectiblesRepeater.itemAt(i)
            if (currentItem && currentItem.active) {
                showCollectibles = true
                break
            }
        }
        noCollectiblesText.visible = !showCollectibles
        collectiblesSection.visible = showCollectibles
    }

    Column {
        id: collectiblesSection
        spacing: Style.current.halfPadding
        anchors.fill: parent

        Repeater {
            id: collectiblesRepeater
            model: walletModel.collectiblesView.collectiblesLists

            CollectiblesContainer {
                property var collectibleData: CollectiblesData.collectiblesData[model.collectibleType]

                collectibleName: collectibleData.collectibleName
                collectibleIconSource: "../../img/collectibles/" + collectibleData.collectibleIconSource
                collectiblesModal: collectiblesModalComponent
                buttonText: collectibleData.buttonText
                getLink: collectibleData.getLink
                onActiveChanged: {
                    checkCollectiblesVisibility()
                }
            }
        }
    }

    Connections {
        target: walletModel.collectiblesView.collectiblesLists
        function onDataChanged() {
            checkCollectiblesVisibility()
        }
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;formeditorColor:"#ffffff";height:480;width:640}
}
##^##*/
