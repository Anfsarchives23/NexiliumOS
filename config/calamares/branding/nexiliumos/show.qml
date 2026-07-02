import QtQuick 2.0
import calamares.slideshow 1.0

Presentation
{
    id: presentation

    Timer {
        id: advanceTimer
        interval: 20000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    // API 1 do Calamares: onActivate/onLeave controlam o timer quando a
    // página do slideshow entra/sai de foco.
    function onActivate() {
        advanceTimer.running = true
    }
    function onLeave() {
        advanceTimer.running = false
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1B1D23"

            Text {
                anchors.centerIn: parent
                text: "Bem-vindo ao NexiliumOS"
                color: "#FFFFFF"
                font.pixelSize: 42
                font.bold: true
            }
        }
    }
}
