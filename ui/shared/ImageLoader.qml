import QtQuick 2.3
import QtGraphicalEffects 1.13
import "../imports"
import "./status/core"
import "./status"

Rectangle {
    id: root
    property bool noHover: false
    property bool noMouseArea: false
    property alias source: image.source
    property alias fillMode: image.fillMode
    property bool showLoadingIndicator: true
    signal loaded
    signal clicked
    color: Style.current.backgroundHover
    state: showLoadingIndicator ? "loading" : "ready"
    radius: width / 2
    states: [
        State {
            name: "loading"
            when: image.status === Image.Loading
            PropertyChanges {
                target: loading
                active: true
            }
            PropertyChanges {
                target: reload
                visible: false
            }
            PropertyChanges {
                target: image
                visible: false
            }
        },
        State {
            name: "error"
            when: image.status === Image.Error
            PropertyChanges {
                target: loading
                active: false
            }
            PropertyChanges {
                target: reload
                visible: true
            }
            PropertyChanges {
                target: image
                visible: false
            }
        },
        State {
            name: "ready"
            when: image.status === Image.Ready
            PropertyChanges {
                target: root
                color: Style.current.transparent
            }
            PropertyChanges {
                target: loading
                active: false
            }
            PropertyChanges {
                target: reload
                visible: false
            }
            PropertyChanges {
                target: image
                visible: true
                height: root.height
                width: root.width
            }
        }
    ]

    Connections {
        target: chatsModel
        function onOnlineStatusChanged(connected) {
            if (connected && root.state !== "ready" &&
                root.visible &&
                root.source &&
                root.source.startsWith("http")) {
                root.reload()
            }
        }
    }

    function reload() {
        // From the documentation (https://doc.qt.io/qt-5/qml-qtquick-image.html#sourceSize-prop)
        // Note: Changing this property dynamically causes the image source to 
        // be reloaded, potentially even from the network, if it is not in the 
        // disk cache.
        const oldSource = image.source
        image.cache = false
        image.sourceSize.width += 1
        image.sourceSize.width -= 1
        image.cache = true

    }

    Component {
        id: loadingIndicator
        StatusLoadingIndicator {
            width: 23
            height: 23
            color: Style.current.secondaryText
        }
    }

    Loader {
        id: loading
        sourceComponent: loadingIndicator
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        active: false
    }

    SVGImage {
        id: reload
        source: "../app/img/reload.svg"
        width: 15.5
        height: 19.5
        fillMode: Image.PreserveAspectFit
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        ColorOverlay {
            anchors.fill: parent
            source: parent
            color: Style.current.textColor
            antialiasing: true
        }
        MouseArea {
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            onClicked: {
                root.reload()
            }
        }
    }

    Image {
        id: image
        width: 0
        height: 0
        sourceSize.width: root.width  * 2
        sourceSize.height: root.height * 2
        source: root.source
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        cache: true
        onStatusChanged: {
            if (image.status === Image.Ready) {
                loaded()
            }
        }
        MouseArea {
            enabled: !noMouseArea
            cursorShape: noHover ? Qt.ArrowCursor : Qt.PointingHandCursor
            anchors.fill: parent
            onClicked: {
                root.clicked()
            }
        }
    }
}
