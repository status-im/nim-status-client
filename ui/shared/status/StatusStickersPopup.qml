import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0
import "../../imports"
import "../../shared"
import "../../shared/status/core"
import "../../shared/status"
import "../../app/AppLayouts/Chat/ChatColumn/samples"

Popup {
    id: root
    property var recentStickers: StickerData {}
    property var stickerPackList: StickerPackData {}
    signal stickerSelected(string hashId, string packId)
    property int installedPacksCount: chatsModel.stickers.numInstalledStickerPacks
    property bool stickerPacksLoaded: false
    width: 360
    height: 440
    modal: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    background: Rectangle {
        radius: Style.current.radius
        color: Style.current.background
        border.color: Style.current.border
        layer.enabled: true
        layer.effect: DropShadow {
            verticalOffset: 3
            radius: 8
            samples: 15
            fast: true
            cached: true
            color: "#22000000"
        }
    }
    onClosed: {
        stickerMarket.visible = false
        footerContent.visible = true
        stickersContainer.visible = true
    }
    Connections {
        target: chatsModel
        function onOnlineStatusChanged(connected) {
            root.close()
        }
    }
    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StatusStickerMarket {
            id: stickerMarket
            visible: false
            Layout.fillWidth: true
            Layout.fillHeight: true
            stickerPacks: stickerPackList
            onInstallClicked: {
                chatsModel.stickers.install(packId)
                stickerGrid.model = stickers
                stickerPackListView.itemAt(index).clicked()
            }
            onUninstallClicked: {
                chatsModel.stickers.uninstall(packId)
                stickerGrid.model = recentStickers
                btnHistory.clicked()
            }
            onBackClicked: {
                stickerMarket.visible = false
                footerContent.visible = true
                stickersContainer.visible = true
            }
        }

        Item {
            id: stickersContainer
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            Layout.topMargin: 4
            Layout.bottomMargin: 0
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            Layout.preferredHeight: 400 - 4

            Item {
                id: noStickerPacks
                anchors.fill: parent
                visible: false

                Image {
                    id: imgNoStickers
                    visible: lblNoStickersYet.visible || lblNoRecentStickers.visible
                    width: 56
                    height: 56
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 134
                    source: "../../app/img/stickers_sad_icon.svg"
                }

                Item {
                    id: noStickersContainer
                    width: parent.width
                    height: 22
                    anchors.top: imgNoStickers.bottom
                    anchors.topMargin: 8

                    StyledText {
                        id: lblNoStickersYet
                        visible: root.installedPacksCount === 0
                        anchors.fill: parent
                        font.pixelSize: 15
                        //% "You don't have any stickers yet"
                        text: qsTrId("you-don't-have-any-stickers-yet")
                        lineHeight: 22
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        id: lblNoRecentStickers
                        visible: stickerPackListView.selectedPackId === -1 && chatsModel.stickers.recent.rowCount() === 0 && !lblNoStickersYet.visible
                        anchors.fill: parent
                        font.pixelSize: 15
                        //% "Recently used stickers will appear here"
                        text: qsTrId("recently-used-stickers")
                        lineHeight: 22
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                StatusButton {
                    visible: lblNoStickersYet.visible
                    //% "Get Stickers"
                    text: qsTrId("get-stickers")
                    anchors.top: noStickersContainer.bottom
                    anchors.topMargin: Style.current.padding
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: {
                        stickersContainer.visible = false
                        stickerMarket.visible = true
                        footerContent.visible = false
                    }
                }
            }
            StatusStickerList {
                id: stickerGrid
                model: recentStickers
                onStickerClicked: {
                    root.stickerSelected(hash, packId)
                    root.close()
                }
            }


            Component {
                id: loadingImageComponent
                StatusLoadingIndicator {
                    width: 50
                    height: 50
                }
            }

            Loader {
                id: loadingGrid
                active: chatsModel.stickers.recent.rowCount() === 0
                sourceComponent: loadingImageComponent
                anchors.centerIn: parent
            }
        }

        Item {
            id: footerContent
            Layout.leftMargin: 8
            Layout.fillWidth: true
            Layout.preferredHeight: 40 - 8 * 2
            Layout.topMargin: 8
            Layout.rightMargin: 8
            Layout.bottomMargin: 8
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft

            StatusRoundButton {
                id: btnAddStickerPack
                size: "medium"
                type: "secondary"
                icon.name: "plusSign"
                implicitWidth: 24
                implicitHeight: 24
                state: root.stickerPacksLoaded ? "default" : "pending"
                onClicked: {
                    stickersContainer.visible = false
                    stickerMarket.visible = true
                    footerContent.visible = false
                }
            }
            StatusStickerPackIconWithIndicator {
                id: btnHistory
                width: 24
                height: 24
                selected: true
                useIconInsteadOfImage: true
                source: "../../app/img/history_icon.svg"
                anchors.left: btnAddStickerPack.right
                anchors.leftMargin: Style.current.padding
                onClicked: {
                    btnHistory.selected = true
                    stickerPackListView.selectedPackId = -1
                    stickerGrid.model = recentStickers
                }
            }


            ScrollView {
                anchors.top: parent.top
                anchors.left: btnHistory.right
                anchors.leftMargin: Style.current.padding
                anchors.right: parent.right
                height: 32
                clip: true
                id: installedStickersSV
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                RowLayout {
                    id: stickersRowLayout
                    spacing: Style.current.padding
                    Repeater {
                        id: stickerPackListView
                        property int selectedPackId: -1
                        model: stickerPackList

                        delegate: StatusStickerPackIconWithIndicator {
                            id: packIconWithIndicator
                            visible: installed
                            width: 24
                            height: 24
                            selected: stickerPackListView.selectedPackId === packId
                            source: "https://ipfs.infura.io/ipfs/" + thumbnail
                            Layout.preferredHeight: height
                            Layout.preferredWidth: width
                            onClicked: {
                                btnHistory.selected = false
                                stickerPackListView.selectedPackId = packId
                                stickerGrid.model = stickers
                            }
                        }
                    }
                    Repeater {
                        id: loadingStickerPackListView
                        model: new Array(7)

                        delegate: Rectangle {
                            width: 24
                            height: 24
                            Layout.preferredHeight: height
                            Layout.preferredWidth: width
                            radius: width / 2
                            color: Style.current.backgroundHover
                        }
                    }
                }
            }
        }
    }
    Connections {
        target: chatsModel.stickers
        function onStickerPacksLoaded() {
            root.stickerPacksLoaded = true
            stickerPackListView.visible = true
            loadingGrid.active = false
            loadingStickerPackListView.model = []
            noStickerPacks.visible = installedPacksCount === 0 || chatsModel.stickers.recent.rowCount() === 0
        }
    }
}

