import QtQuick 2.13
import QtMultimedia 5.13

Audio {
    id: errorSound
    source: "./error.mp3"
    audioRole: Audio.NotificationRole
    volume: 0.2
}

/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/
