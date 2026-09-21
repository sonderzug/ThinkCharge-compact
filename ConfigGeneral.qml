import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    // property alias cfg_fanSensorId: fanSensor.text
    // property alias cfg_tempSensorId: tempSensor.text
    property alias cfg_showBattery: showBattery.checked
    property alias cfg_showPowerMode: showPowerMode.checked

    // QQC2.TextField {
    //     id: battext1
    //     Kirigami.FormData.label: i18n("Text:")
    //     Layout.fillWidth: true
    // }


    // QQC2.Label {
    //     Layout.fillWidth: true
    //     Layout.maximumWidth: Kirigami.Units.gridUnit * 22
    //     wrapMode: Text.WordWrap
    //     font: Kirigami.Theme.smallFont
    //     opacity: 0.7
    //     text: i18n("Sensor ids differ between models. List the available ones with:\nbusctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 org.kde.ksystemstats1 allSensors")
    // }

    Item { Kirigami.FormData.isSection: true }


    QQC2.CheckBox {
        id: showBattery
        Kirigami.FormData.label: i18n("Show in Widget:")
        text: i18n("Battery")
    }

    QQC2.CheckBox {
        id: showPowerMode
        text: i18n("Power Mode")
    }
}
