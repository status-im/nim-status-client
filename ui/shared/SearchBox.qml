import QtQuick 2.13
import "../imports"

Input {
    id: searchBox
    //% "Search"
    placeholderText: qsTrId("search")
    icon: "../app/img/search.svg"
    iconWidth: 24
    iconHeight: 24
    customHeight: 36
    fontPixelSize: 15
}
