import QtQuick 2.13

Item {
    id: component
    property alias model: filterModel

    property string formattedFilter
    property QtObject sourceModel: undefined
    property string filter: ""
    property int cursorPosition: 0
    property int lastAtPosition: 0
    property var property: ([])

    Connections {
        onFilterChanged: invalidateFilter()
        onPropertyChanged: invalidateFilter()
        onSourceModelChanged: invalidateFilter()
    }

    Component.onCompleted: invalidateFilter()

    ListModel {
        id: filterModel
    }

    function invalidateFilter() {
        if (sourceModel === undefined)
            return;

        filterModel.clear();

        if (!isFilteringPropertyOk())
            return

        var length = sourceModel.count
        for (var i = 0; i < length; ++i) {
            var item = sourceModel.get(i);
            if (isAcceptedItem(item)) {
                filterModel.append(item)
            }
        }
    }

    function isAcceptedItem(item) {
        let properties = this.property
            .filter(p => !!item[p])

        if (properties.length === 0 || this.filter.length === 0 || this.cursorPosition === 0) {
            return false
        }

        let filter = chatsModel.plainText(this.filter)
        // Prevents suggestions to show up at all
        if (filter.indexOf("@") === -1)  {
          return false
        }

        let cursorAtEnd = this.cursorPosition === filter.length;
        let hasAtBeforeCursor = filter.charAt(this.cursorPosition - 1) === "@" 
        let hasWhiteSpaceBeforeAt = filter.charAt(this.cursorPosition - 2) === " " || filter.charAt(this.cursorPosition - 2) === "\n"
        let hasWhiteSpaceAfterAt = filter.charAt(this.cursorPosition) === " "
        let hasWhiteSpaceBeforeCursor = filter.charAt(this.cursorPosition - 1) === " "

        if (filter.charAt(this.cursorPosition - 2) === "@" && hasWhiteSpaceBeforeCursor) {
            return false
        }

        if (filter === "@" ||
                (hasAtBeforeCursor && hasWhiteSpaceBeforeAt && hasWhiteSpaceAfterAt) ||
                (this.cursorPosition === 1 && hasAtBeforeCursor && hasWhiteSpaceAfterAt) ||
                (cursorAtEnd && filter.endsWith("@") && hasWhiteSpaceBeforeAt)) {
            this.lastAtPosition = this.cursorPosition - 1;
            return true
        }

        let filterWithoutAt = filter.substring(lastAtPosition + 1, this.cursorPosition)
        filterWithoutAt = filterWithoutAt.replace(/\*/g, "")
        component.formattedFilter = filterWithoutAt

        return !properties.every(p => item[p].toLowerCase().match(filterWithoutAt.toLowerCase()) === null)
    }

    function isFilteringPropertyOk() {
        if(this.property === undefined || this.property.length === 0) {
            return false
        }
        return true
    }
}
