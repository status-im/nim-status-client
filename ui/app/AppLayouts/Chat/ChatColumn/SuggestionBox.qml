/*
    Copyright (C) 2011 Jocelyn Turcotte <turcotte.j@gmail.com>

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License
    along with this program; see the file COPYING.LIB.  If not, write to
    the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301, USA.
*/

import QtQuick 2.13
import QtQuick.Controls 2.13
import QtGraphicalEffects 1.13
import QtQml.Models 2.13
import "../../../../imports"
import "../../../../shared"
import "../../../../shared/status"

Rectangle {
    id: container

    property QtObject model: undefined
    property Item delegate
    property alias suggestionsModel: filterItem.model
    property alias filter: filterItem.filter
    property alias formattedPlainTextFilter: filterItem.formattedFilter
    property alias property: filterItem.property
    property int cursorPosition
    signal itemSelected(var item, int lastAtPosition, int lastCursorPosition)
    property alias listView: listView
    property bool shouldHide: false

    Timer {
        id: timer
    }

    onFormattedPlainTextFilterChanged: {
        // We need to callLater because the sort needs to happen before setting the index
        Qt.callLater(function () {
            listView.currentIndex = 0
        })
    }

    onCursorPositionChanged: {
        if (shouldHide) {
            shouldHide = false
        }
    }

    function hide() {
        shouldHide = true
    }

    function selectCurrentItem() {
        container.itemSelected(mentionsListDelegate.items.get(listView.currentIndex).model, filterItem.lastAtPosition, filterItem.cursorPosition)
    }

    onVisibleChanged: {
        if (visible && listView.currentIndex === -1) {
            // If the previous selection was made using the mouse, the currentIndex was changed to -1
            // We change it back to 0 so that it can be used to select using the keyboard
            listView.currentIndex = 0
        }
    }

    z: parent.z + 100
    visible: !shouldHide && filter.length > 0 && suggestionsModel.count > 0
    height: Math.min(400, listView.contentHeight + Style.current.padding)

    opacity: visible ? 1.0 : 0
    Behavior on opacity {
        NumberAnimation { }
    }

    color: Style.current.background
    radius: Style.current.radius
    border.width: 0
    layer.enabled: true
    layer.effect: DropShadow{
        width: container.width
        height: container.height
        x: container.x
        y: container.y + 10
        visible: container.visible
        source: container
        horizontalOffset: 0
        verticalOffset: 2
        radius: 10
        samples: 15
        color: "#22000000"
    }

    SuggestionFilter {
        id: filterItem
        sourceModel: container.model
        cursorPosition: container.cursorPosition
    }


    ListView {
        id: listView
        model: mentionsListDelegate
        keyNavigationEnabled: true
        anchors.fill: parent
        anchors.topMargin: Style.current.halfPadding
        anchors.leftMargin: Style.current.halfPadding
        anchors.rightMargin: Style.current.halfPadding
        anchors.bottomMargin: Style.current.halfPadding
        clip: true

        property int selectedIndex
        property var selectedItem: selectedIndex == -1 ? null : model[selectedIndex]
        signal suggestionClicked(var item)

        DelegateModelGeneralized {
            id: mentionsListDelegate

            lessThan: [
                function(left, right) {
                    // Priorities:
                    // 1. Match at the start
                    // 2. Match in the start of one of the three words
                    // 3. Alphabetical order (also in case of multiple matches at the start of the name)

                    const leftProp = left[container.property.find(p => !!left[p])].toLowerCase()
                    const rightProp = right[container.property.find(p => !!right[p])].toLowerCase()

                    if (!formattedPlainTextFilter) {
                        return leftProp < rightProp
                    }

                    // check the start of the string
                    const leftMatches = leftProp.startsWith(formattedPlainTextFilter)

                    const rightMatches = rightProp.startsWith(formattedPlainTextFilter)

                    if (leftMatches === true && rightMatches === true) {
                        return leftProp < rightProp
                    }

                    if (leftMatches || rightMatches) {
                        return leftMatches && !rightMatches
                    }

                    // Check for the start of the 3 word names
                    let leftMatchesIndex = leftProp.indexOf(" " + formattedPlainTextFilter)
                    let rightMatchesIndex = rightProp.indexOf(" " + formattedPlainTextFilter)
                    if (leftMatchesIndex === rightMatchesIndex) {
                        return leftProp < rightProp
                    }

                    // Change index so that -1 is not the smallest
                    if (leftMatchesIndex === -1) {
                        leftMatchesIndex = 999
                    }
                    if (rightMatchesIndex === -1) {
                        rightMatchesIndex = 999
                    }

                    return leftMatchesIndex < rightMatchesIndex
                }
            ]

            model: container.suggestionsModel

            delegate: Rectangle {
                id: itemDelegate
                color: ListView.isCurrentItem ? Style.current.backgroundHover : Style.current.transparent
                border.width: 0
                width: parent.width
                height: 42
                radius: Style.current.radius

                StatusImageIdenticon {
                    id: accountImage
                    width: 32
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Style.current.smallPadding
                    source: model.identicon
                }

                StyledText {
                    text: model[container.property.find(p => !!model[p])]
                    color: Style.current.textColor
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: accountImage.right
                    anchors.leftMargin: Style.current.smallPadding
                    font.pixelSize: 15
                }

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        listView.currentIndex = itemDelegate.DelegateModel.itemsIndex
                    }
                    onClicked: {
                        container.itemSelected(model, filterItem.lastAtPosition, filterItem.cursorPosition)
                    }
                }
            }
        }
    }
}



