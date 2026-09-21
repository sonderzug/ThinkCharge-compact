import QtQuick.Controls as Controls

Controls.ToolButton {
    property bool expanded: false
    icon.name: expanded ? "arrow-down" : "arrow-right"
    flat: true
    onClicked: expanded = !expanded
}
