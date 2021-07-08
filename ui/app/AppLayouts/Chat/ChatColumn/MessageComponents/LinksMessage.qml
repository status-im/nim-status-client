import QtQuick 2.13
import QtGraphicalEffects 1.13
import QtQuick.Layouts 1.13
import "../../../../../imports"
import "../../../../../shared"
import "../../../../../shared/status"
import "./" as MessageComponents
import "../../../Profile/LeftTab/constants.js" as ProfileConstants

Column {
    id: root
    property string linkUrls: ""
    property var container
    property bool isCurrentUser: false
    readonly property string uuid: Utils.uuid()
    spacing: Style.current.halfPadding

    ListModel {
        id: linksModel
        Component.onCompleted: {
            if (!root.linkUrls) {
                return
            }
            root.linkUrls.split(" ").forEach(link => {
                linksModel.append({link})
            })
        }
    }

    Repeater {
        id: linksRepeater
        model: linksModel // doesn't work with a JSON object model!

        delegate: Loader {
            id: linkMessageLoader
            property bool fetched: false
            property var linkData
            property int linkWidth: linksRepeater.width

            active: true
            
            Connections {
                target: appSettings
                function onWhitelistedUnfurlingSitesChanged() {
                    fetched = false
                    linkMessageLoader.sourceComponent = undefined
                    linkMessageLoader.sourceComponent = linkMessageLoader.getSourceComponent()
                }
                function onNeverAskAboutUnfurlingAgainChanged() {
                    linkMessageLoader.sourceComponent = undefined
                    linkMessageLoader.sourceComponent = linkMessageLoader.getSourceComponent()
                }
                function onDisplayChatImagesChanged() {
                    linkMessageLoader.sourceComponent = undefined
                    linkMessageLoader.sourceComponent = linkMessageLoader.getSourceComponent()
                }
            }
            Connections {
                id: linkFetchConnections
                enabled: false
                target: chatsModel
                function onLinkPreviewDataWasReceived(previewData) {
                    let response
                    try {
                        response = JSON.parse(previewData)

                    } catch (e) {
                        console.error(previewData, e)
                        return
                    }


                    if (response.uuid !== root.uuid) return

                    linkFetchConnections.enabled = false

                    if (!response.success) {
                        console.error(response.result.error)
                        return undefined
                    }

                    linkData = response.result

                    if (linkData.contentType.startsWith("image/")) {
                        return linkMessageLoader.sourceComponent = unfurledImageComponent
                    }
                    if (linkData.site && linkData.title) {
                        linkData.address = link
                        return linkMessageLoader.sourceComponent = unfurledLinkComponent
                    }
                }
            }

            Connections {
                id: linkCommunityFetchConnections
                enabled: false
                target: chatsModel.communities
                function onCommunityAdded(communityId) {
                    if (communityId !== linkData.communityId) {
                        return
                    }
                    linkCommunityFetchConnections.enabled = false
                    const data = Utils.getLinkDataForStatusLinks(link)
                    if (data) {
                        linkData = data
                        if (!data.fetching && data.communityId) {
                            return linkMessageLoader.sourceComponent = invitationBubble
                        }

                        return linkMessageLoader.sourceComponent = unfurledLinkComponent
                    }
                }
            }

            function getSourceComponent() {
                // Reset the height in case we set it to 0 below. See note below
                // for more information
                this.height = undefined
                if (appSettings.displayChatImages && Utils.hasImageExtension(link)) {
                    linkData = {
                        thumbnailUrl: link
                    }
                    return unfurledImageComponent
                }
                let linkWhiteListed = false
                const linkHostname = Utils.getHostname(link)
                const linkExists = Object.keys(appSettings.whitelistedUnfurlingSites).some(function(whitelistedHostname) {
                    const exists = linkHostname.endsWith(whitelistedHostname)
                    if (exists) {
                        linkWhiteListed = appSettings.whitelistedUnfurlingSites[whitelistedHostname] === true
                    }
                    return exists
                })
                if (!linkWhiteListed && linkExists && !appSettings.neverAskAboutUnfurlingAgain) {
                    return enableLinkComponent
                }
                if (linkWhiteListed) {
                    if (fetched) {
                        return
                    }
                    fetched = true

                    const data = Utils.getLinkDataForStatusLinks(link)
                    if (data) {
                        linkData = data
                        if (data.fetching && data.communityId) {
                            linkCommunityFetchConnections.enabled = true
                            return
                        }
                        if (data.communityId) {
                            return invitationBubble
                        }

                        return unfurledLinkComponent
                    }

                    linkFetchConnections.enabled = true
                    return chatsModel.getLinkPreviewData(link, root.uuid)
                }
                // setting the height to 0 allows the "enable link" dialog to
                // disappear correctly when appSettings.neverAskAboutUnfurlingAgain
                // is true. The height is reset at the top of this method.
                this.height = 0
                return undefined
            }

            Component.onCompleted: {
                // putting this is onCompleted prevents automatic binding, where
                // QML warns of a binding loop detected
                this.sourceComponent = getSourceComponent()
            }
        }
    }

    Component {
        id: unfurledImageComponent

        MessageBorder {
            width: linkImage.width
            height: linkImage.height
            isCurrentUser: root.isCurrentUser
            MessageComponents.ImageLoader {
                id: linkImage
                anchors.centerIn: parent
                container: root.container
                source: linkData.thumbnailUrl
                imageWidth: 300
                isCurrentUser: root.isCurrentUser
                onClicked: {
                    clickMessage(false, false, true, linkImage.imageAlias)
                }
            }
        }
    }

    Component {
        id: invitationBubble
        InvitationBubble {
            communityId: linkData.communityId
            isLink: true
            anchors.left: parent.left
        }
    }

    Component {
        id: unfurledLinkComponent
        MessageBorder {
            width: linkImage.width + 2
            height: linkImage.height + (Style.current.smallPadding * 2) + linkTitle.height + 2 + linkSite.height
            isCurrentUser: root.isCurrentUser

            MessageComponents.ImageLoader {
                id: linkImage
                container: root.container
                source: linkData.thumbnailUrl
                imageWidth: 300
                isCurrentUser: root.isCurrentUser
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 1
            }
            StyledText {
                id: linkTitle
                text: linkData.title
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: linkImage.bottom
                anchors.rightMargin: Style.current.smallPadding
                anchors.leftMargin: Style.current.smallPadding
                anchors.topMargin: Style.current.smallPadding
            }

            StyledText {
                id: linkSite
                text: linkData.site
                font.pixelSize: 12
                font.weight: Font.Thin
                color: Style.current.secondaryText
                anchors.top: linkTitle.bottom
                anchors.topMargin: 2
                anchors.left: linkTitle.left
                anchors.bottomMargin: Style.current.smallPadding
            }

            MouseArea {
                anchors.top: linkImage.top
                anchors.left: linkImage.left
                anchors.right: linkImage.right
                anchors.bottom: linkSite.bottom
                cursorShape: Qt.PointingHandCursor
                onClicked:  {
                    if (!!linkData.callback) {
                        return linkData.callback()
                    }

                    appMain.openLink(linkData.address)
                }
            }
        }
    }

    Component {
        id: enableLinkComponent
        Rectangle {
            id: enableLinkRoot
            width: 300
            height: childrenRect.height + Style.current.smallPadding
            radius: 16
            border.width: 1
            border.color: Style.current.border
            color:Style.current.background

            StatusIconButton {
                icon.name: "close"
                icon.width: 20
                icon.height: 20
                anchors.top: parent.top
                anchors.topMargin: Style.current.smallPadding
                anchors.right: parent.right
                anchors.rightMargin: Style.current.smallPadding
                onClicked: {
                    enableLinkRoot.height = 0
                    enableLinkRoot.visible = false
                }
            }

            Image {
                id: unfurlingImage
                source: "../../../../img/unfurling-image.png"
                width: 132
                height: 94
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Style.current.smallPadding
            }

            StyledText {
                id: enableText
                //% "Enable link previews in chat?"
                text: qsTrId("enable-link-previews")
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                anchors.top: unfurlingImage.bottom
                anchors.topMargin: Style.current.halfPadding
                font.pixelSize: 15
            }

            StyledText {
                id: infoText
                //% "Once enabled, links posted in the chat may share your metadata with their owners"
                text: qsTrId("once-enabled--links-posted-in-the-chat-may-share-your-metadata-with-their-owners")
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                anchors.top: enableText.bottom
                font.pixelSize: 13
                color: Style.current.secondaryText
            }

            Separator {
                id: sep1
                anchors.top: infoText.bottom
                anchors.topMargin: Style.current.smallPadding
            }

            StatusButton {
                id: enableBtn
                //% "Enable in Settings"
                text: qsTrId("enable-in-settings")
                type: "secondary"
                onClicked: {
                    appMain.changeAppSection(Constants.profile)
                    profileLayoutContainer.changeProfileSection(ProfileConstants.PRIVACY_AND_SECURITY)
                }
                width: parent.width
                anchors.top: sep1.bottom
            }

            Separator {
                id: sep2
                anchors.top: enableBtn.bottom
                anchors.topMargin: 0
            }

            StatusButton {
                //% "Don't ask me again"
                text: qsTrId("dont-ask")
                type: "secondary"
                onClicked: {
                    appSettings.neverAskAboutUnfurlingAgain = true
                }
                width: parent.width
                anchors.top: sep2.bottom
            }
        }
    }
}
