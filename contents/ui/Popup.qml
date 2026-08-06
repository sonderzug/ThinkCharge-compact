import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    implicitWidth: Kirigami.Units.gridUnit * 28
    implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: implicitHeight
    ColumnLayout {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.helperChecked && !root.helperInstalled
            type: Kirigami.MessageType.Warning
            text: i18n("Setup required: installing the widget alone cannot change charge limits. Download the source package and run ./install.sh as your regular user.")
            actions: [
                Kirigami.Action {
                    text: i18n("Installation instructions")
                    icon.name: "internet-web-browser"
                    onTriggered: Qt.openUrlExternally("https://github.com/GregorBoxer-sudo/ThinkCharge#install-from-git")
                }
            ]
        }
        Kirigami.InlineMessage { Layout.fillWidth: true; visible: root.statusMessage.length > 0; text: root.statusMessage; type: root.supported ? Kirigami.MessageType.Information : Kirigami.MessageType.Warning }
        Controls.Label { text: i18n("Charge profile and automatic power profile"); font.bold: true }
        RowLayout {
            Layout.fillWidth: true
            Controls.Label { text: i18n("Profile") }
            NoWheelComboBox {
                Layout.fillWidth: true; model: root.profiles.map(function(p) { return p.name }).concat([i18n("Create new…")]); currentIndex: root.profileIndex(root.selectedProfileId)
                onActivated: function(index) { if (index === root.profiles.length) createArea.visible = true; else { createArea.visible = false; root.selectProfile(root.profiles[index].id, true) } }
            }
            Controls.ToolButton { icon.name: "edit-delete"; enabled: root.profileById(root.selectedProfileId) && !root.profileById(root.selectedProfileId).builtin; onClicked: deleteDialog.open() }
        }
        GridLayout {
            id: createArea; visible: false; Layout.fillWidth: true; columns: 2
            Controls.TextField { id: newName; Layout.fillWidth: true; placeholderText: i18n("Profile name") }
            Controls.Button { text: i18n("Create"); onClicked: if (root.createProfile(newName.text, newUpper.value, newGap.value)) { createArea.visible = false; newName.text = "" } }
            Controls.SpinBox { id: newUpper; from: 50; to: 100; value: 80; editable: true }
            Controls.SpinBox { id: newGap; from: 1; to: 20; value: 5; editable: true }
        }
        RowLayout {
            Layout.fillWidth: true
            Controls.Label { text: i18n("Upper threshold"); Layout.preferredWidth: Kirigami.Units.gridUnit * 6 }
            Controls.Slider { Layout.fillWidth: true; from: 50; to: 100; stepSize: 1; value: root.previewEnd; onMoved: root.previewEnd = Math.round(value); onPressedChanged: root.editing = pressed }
            Controls.Label { text: root.previewEnd + "%"; Layout.minimumWidth: Kirigami.Units.gridUnit * 2 }
        }
        RowLayout {
            Layout.fillWidth: true
            Controls.Label { text: i18n("Gap"); Layout.preferredWidth: Kirigami.Units.gridUnit * 6 }
            Controls.Slider { Layout.fillWidth: true; from: 1; to: 20; stepSize: 1; value: root.previewGap; onMoved: root.previewGap = Math.round(value); onPressedChanged: root.editing = pressed }
            Controls.Label { text: root.previewGap + "%"; Layout.minimumWidth: Kirigami.Units.gridUnit * 2 }
        }
        GridLayout {
            id: powerProfileGrid
            Layout.fillWidth: true
            columns: 2
            readonly property var modeNames: [i18n("Power Save"), i18n("Balanced"), i18n("Performance")]
            readonly property var modeIds: ["power-saver", "balanced", "performance"]
            function modeIndex(value) { return Math.max(0, modeIds.indexOf(value)) }

            Controls.Label { text: i18n("On battery") }
            NoWheelComboBox {
                Layout.fillWidth: true; model: powerProfileGrid.modeNames
                currentIndex: powerProfileGrid.modeIndex(root.previewDischargePowerProfile)
                onActivated: function(index) { root.setProfilePowerMode("dischargePowerProfile", powerProfileGrid.modeIds[index]) }
            }
            Controls.Label { text: i18n("Charging") }
            NoWheelComboBox {
                Layout.fillWidth: true; model: powerProfileGrid.modeNames
                currentIndex: powerProfileGrid.modeIndex(root.previewChargePowerProfile)
                onActivated: function(index) { root.setProfilePowerMode("chargePowerProfile", powerProfileGrid.modeIds[index]) }
            }
            Controls.Label { text: i18n("Charging with HDMI") }
            NoWheelComboBox {
                Layout.fillWidth: true; model: powerProfileGrid.modeNames
                currentIndex: powerProfileGrid.modeIndex(root.previewHdmiPowerProfile)
                onActivated: function(index) { root.setProfilePowerMode("hdmiPowerProfile", powerProfileGrid.modeIds[index]) }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Controls.BusyIndicator { visible: root.applying; running: visible; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: width }
            Controls.Button { text: i18n("Revert"); enabled: root.profileSettingsDirty && !root.applying; onClicked: root.revertSelectedProfile() }
            Controls.Button { text: i18n("Save"); enabled: root.profileSettingsDirty && !root.applying; highlighted: true; onClicked: root.updateSelectedProfile() }
        }
        Kirigami.Separator { Layout.fillWidth: true }
        Controls.Label { text: i18n("Temporary overrides"); font.bold: true }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            Controls.Label { text: i18n("Charge mode") }
            RowLayout {
                Layout.fillWidth: true
                Controls.Button {
                    text: i18n("Full")
                    enabled: root.helperInstalled
                    checkable: true
                    checked: root.temporaryMode === "FULL"
                    Layout.fillWidth: true
                    onClicked: root.toggleTemporary("FULL")
                }
                Controls.Button {
                    text: i18n("Safe full")
                    enabled: root.helperInstalled
                    checkable: true
                    checked: root.temporaryMode === "SAFE_FULL"
                    Layout.fillWidth: true
                    onClicked: root.toggleTemporary("SAFE_FULL")
                }
            }
            Controls.Label { text: i18n("Power profile") }
            NoWheelComboBox {
                id: powerOverride
                Layout.fillWidth: true
                model: [i18n("Automatic"), i18n("Power Save"), i18n("Balanced"), i18n("Performance")]
                readonly property var modeIds: ["", "power-saver", "balanced", "performance"]
                currentIndex: Math.max(0, modeIds.indexOf(root.powerProfileOverride))
                onActivated: function(index) { root.setPowerProfileOverride(modeIds[index]) }
                Controls.ToolTip.visible: hovered
                Controls.ToolTip.text: i18n("Power profile override")
            }
        }
        Kirigami.Separator { Layout.fillWidth: true }
        Controls.Label { text: i18n("Docking"); font.bold: true }
        RowLayout {
            Layout.fillWidth: true
            Controls.Label { text: i18n("Automatic mode switching"); Layout.fillWidth: true }
            Controls.Switch { checked: Plasmoid.configuration.dockingEnabled; onToggled: root.setDockingEnabled(checked) }
        }
        RowLayout {
            Layout.fillWidth: true; enabled: Plasmoid.configuration.dockingEnabled
            Controls.Label { text: i18n("Docking profile") }
            NoWheelComboBox { Layout.fillWidth: true; model: root.profiles.map(function(p) { return p.name }); currentIndex: root.profileIndex(Plasmoid.configuration.dockedProfileId); onActivated: function(index) { Plasmoid.configuration.dockedProfileId = root.profiles[index].id; if (root.dockingDetected) root.selectProfile(root.profiles[index].id, true) } }
        }
        RowLayout {
            Layout.fillWidth: true; enabled: Plasmoid.configuration.dockingEnabled
            Controls.Label { text: i18n("Internal display") }
            NoWheelComboBox {
                Layout.fillWidth: true; model: [root.autoInternalDisplay.length ? i18n("Auto: %1", root.autoInternalDisplay) : i18n("Auto detection failed")].concat(root.displays.map(function(d) { return d.name }))
                currentIndex: { if (Plasmoid.configuration.internalDisplayId === "auto") return 0; for (var i = 0; i < root.displays.length; ++i) if (root.displays[i].name === Plasmoid.configuration.internalDisplayId) return i + 1; return 0 }
                onActivated: function(index) { Plasmoid.configuration.internalDisplayId = index === 0 ? "auto" : root.displays[index - 1].name; root.determineDisplays() }
            }
        }
        Kirigami.Separator { Layout.fillWidth: true }
        Controls.Label { text: i18n("Status"); font.bold: true }
        Controls.Label { Layout.fillWidth: true; text: i18n("Charge: %1% / %2%   Power: %3   Remaining: %4\nRange: %5–%2%   Profile: %6   Mode: %7   Power mode: %8", root.capacity, root.currentEnd, root.formatPower(), root.formatDuration(root.hoursToTarget), root.currentStart, root.profileById(root.selectedProfileId).name, root.effectiveMode, root.powerProfileName(root.currentPowerProfile)); color: Kirigami.Theme.disabledTextColor; wrapMode: Text.Wrap }
    }
    Controls.Dialog { id: deleteDialog; modal: true; anchors.centerIn: parent; title: i18n("Delete profile?"); standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel; onAccepted: root.deleteSelectedProfile() }
}
