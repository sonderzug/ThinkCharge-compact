import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Controls.ComboBox {
    leftPadding: Kirigami.Units.largeSpacing

    // Do not change a closed dropdown while scrolling the surrounding popup.
    // Its opened menu remains normally scrollable.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) { wheel.accepted = true }
    }
}
