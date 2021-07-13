import QtQuick 2.12
import QtQuick.Controls 2.3
import QtGraphicalEffects 1.13
import QtQuick.Dialogs 1.3
import "../../../../imports"
import "../components"
import "../../../../shared"
import "../../../../shared/status"

import StatusQ.Core 0.1
import StatusQ.Core.Theme 0.1
import StatusQ.Controls 0.1
import StatusQ.Components 0.1
import StatusQ.Popups 0.1

StatusModal {
    id: popup
    property string communityId
    property QtObject channel
    property bool isEdit: false
    property string categoryId: ""

    readonly property int maxChannelNameLength: 30
    readonly property var channelNameValidator: Utils.Validate.NoEmpty
                                                | Utils.Validate.TextLength
                                                | Utils.Validate.TextLowercaseLettersNumberAndDashes

    readonly property int maxChannelDescLength: 140
    readonly property var channelDescValidator: Utils.Validate.NoEmpty
                                                | Utils.Validate.TextLength
    
    property Component pinnedMessagesPopupComponent

    header.title: qsTrId("New channel")

    onOpened: {
        contentComponent.channelName.text = ""
        if (isEdit) {
            header.title = qsTr("Edit #%1").arg(channel.name);
        }
        contentComponent.channelName.forceActiveFocus(Qt.MouseFocusReason)
    }

    onClosed: destroy()

    function isFormValid() {
        return Utils.validateAndReturnError(contentComponent.channelName.text,
                                            channelNameValidator,
                                            qsTr("channel name"),
                                            maxChannelNameLength) === ""
               && Utils.validateAndReturnError(contentComponent.channelDescription.text,
                                               channelDescValidator,
                                               qsTr("channel decription"),
                                               maxChannelDescLength) === ""
    }

    content: ScrollView {

        id: scrollView

        property ScrollBar vScrollBar: ScrollBar.vertical

        property alias channelName: nameInput
        property alias channelDescription: descriptionTextArea

        contentHeight: content.height
        height: Math.min(content.height, 432)
        width: popup.width

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true

        function scrollBackUp() {
            vScrollBar.setPosition(0)
        }

        Column {
            id: content
            width: popup.width

            Item {
                width: parent.width
                height: 76

                Input {
                    id: nameInput
                    width: parent.width - 32
                    anchors.centerIn: parent
                    placeholderText: qsTr("Channel name")
                    maxLength: popup.maxChannelNameLength

                    onTextEdited: {
                        text = Utils.convertSpacesToDashesAndUpperToLowerCase(text);

                        validationError = Utils.validateAndReturnError(text,
                                                                        channelNameValidator,
                                                                        qsTr("channel name"),
                                                                        maxChannelNameLength)
                    }
                }
            }

            StatusModalDivider {
                topPadding: 8
                bottomPadding: 8
            }

            Item {
                height: descriptionTextArea.height + 26

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                StyledTextArea {
                    id: descriptionTextArea

                    anchors.top: parent.top
                    anchors.topMargin: 10

                    label: qsTr("Description")
                    placeholderText: qsTr("Describe the channel")

                    customHeight: 88

                    text: popup.isEdit ? popup.channel.description : ""

                    onTextChanged: {
                        if(text.length > maxChannelDescLength)
                        {
                            textField.remove(maxChannelDescLength, text.length)
                            return
                        }

                        validationError = Utils.validateAndReturnError(text,
                                                                        channelDescValidator,
                                                                        qsTr("channel description"),
                                                                        maxChannelDescLength)
                    }
                }

                StyledText {
                    id: charLimit
                    text: `${descriptionTextArea.text.length}/${maxChannelDescLength}`
                    anchors.top: descriptionTextArea.top
                    anchors.right: descriptionTextArea.right
                    font.pixelSize: 12
                    color: !descriptionTextArea.validationError ? Theme.palette.baseColor1 : Theme.palette.dangerColor1
                }
            }
      
            /* TODO: use the code below to enable private channels and message limit */
            /* StatusListItem { */
            /*     width: parent.width */
            /*     height: 56 */
            /*     sensor.enabled: false */
            /*     title: qsTr("Private channel") */
            /*     components: [ */
            /*         StatusSwitch { */
            /*             id: privateSwitch */
            /*         } */
            /*     ] */
            /* } */

            /* StatusBaseText { */
            /*     width: parent.width - 32 */
            /*     anchors.left: parent.left */
            /*     anchors.right: parent.right */
            /*     anchors.rightMargin: 121 */
            /*     anchors.leftMargin: 16 */
            /*     color: Theme.palette.baseColor1 */
            /*     wrapMode: Text.WordWrap */
            /*     text: qsTr("By making a channel private, only members with selected permission will be able to access it") */
            /* } */

            /* StatusModalDivider { */
            /*     topPadding: 8 */
            /*     bottomPadding: 8 */
            /* } */

            /* StatusListItem { */
            /*     width: parent.width */
            /*     height: 56 */
            /*     sensor.enabled: false */
            /*     title: qsTr("Message limit") */
            /*     components: [ */
            /*         StatusSwitch {} */
            /*     ] */
            /* } */

            /* StatusBaseText { */
            /*     width: parent.width - 32 */
            /*     anchors.left: parent.left */
            /*     anchors.right: parent.right */
            /*     anchors.rightMargin: 121 */
            /*     anchors.leftMargin: 16 */
            /*     color: Theme.palette.baseColor1 */
            /*     wrapMode: Text.WordWrap */
            /*     text: qsTr("Limit channel members to sending one message per chose time interval") */
            /* } */

            StatusListItem {
                anchors.horizontalCenter: parent.horizontalCenter
                title: qsTr("Pinned messages")
                icon.name: "pin"
                label: chatsModel.messageView.pinnedMessagesList.count
                components: [
                    StatusIcon {
                        icon: "chevron-down"
                        rotation: 270
                        color: Theme.palette.baseColor1
                    }
                ]

                sensor.onClicked: openPopup(pinnedMessagesPopupComponent)
            }

            StatusModalDivider {
                topPadding: 8
            }
        }
    }
 
    rightButtons: [
        StatusButton {
            enabled: isFormValid()
            text: isEdit ?
                  qsTr("Save") :
                  qsTr("Create")
            onClicked: {
                if (!isFormValid()) {
                    scrollView.scrollBackUp()
                    return
                }
                let error = "";
                if (!isEdit) {
                    error = chatsModel.createCommunityChannel(communityId,
                                                                Utils.filterXSS(popup.contentComponent.channelName.text),
                                                                Utils.filterXSS(popup.contentComponent.channelDescription.text),
                      categoryId)
                                                                // TODO: pass the private value when private channels
                                                                // are implemented
                                                                //privateSwitch.checked)
                } else {
                    error = chatsModel.editCommunityChannel(communityId,
                                                                channel.id,
                                                                Utils.filterXSS(popup.contentComponent.channelName.text),
                                                                Utils.filterXSS(popup.contentComponent.channelDescription.text),
                      categoryId)
                                                                // TODO: pass the private value when private channels
                                                                // are implemented
                                                                //privateSwitch.checked)
                }

                if (error) {
                    const errorJson = JSON.parse(error)
                    creatingError.text = errorJson.error
                    return creatingError.open()
                }

                // TODO Open the community once we have designs for it
                popup.close()
            }
        }
    ]

    MessageDialog {
        id: creatingError
        //% "Error creating the community"
        title: qsTrId("error-creating-the-community")
        icon: StandardIcon.Critical
        standardButtons: StandardButton.Ok
    }
}

