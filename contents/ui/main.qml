import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property string batteryName: ""
    property int capacity: -1
    property string batteryStatus: "Unknown"
    property int currentStart: -1
    property int currentEnd: -1
    property bool supported: false
    property bool helperInstalled: false
    property bool helperChecked: false
    property bool acOnline: false
    property int batteryCount: 0
    property real powerWatts: -1
    property real energyNowWh: -1
    property real energyFullWh: -1
    property var displays: []
    property string autoInternalDisplay: ""
    property bool externalDisplayActive: false
    property bool hdmiDisplayActive: false
    property bool dockingDetected: false
    property bool dockingCandidate: false
    property string temporaryMode: "" // FULL or SAFE_FULL, never persisted
    property bool applying: false
    property bool editing: false
    property string automaticPowerState: ""
    property string powerProfileOverride: "" // Empty means profile-controlled automatic mode.
    property string currentPowerProfile: "unknown"
    property string statusMessage: i18n("Detecting hardware…")
    property var profiles: []
    property int previewEnd: 80
    property int previewGap: 5
    property string previewDischargePowerProfile: "power-saver"
    property string previewChargePowerProfile: "balanced"
    property string previewHdmiPowerProfile: "performance"
    readonly property int previewStart: Math.max(0, previewEnd - Math.max(1, previewGap))
    readonly property string selectedProfileId: Plasmoid.configuration.selectedProfileId
    readonly property string effectiveMode: temporaryMode.length > 0 ? temporaryMode
        : (dockingDetected ? "Docked" : "Normal")
    readonly property var effectiveProfile: profileById(selectedProfileId)
    readonly property bool profileSettingsDirty: effectiveProfile
        && (previewEnd !== effectiveProfile.upperThreshold
            || previewGap !== effectiveProfile.gap
            || previewDischargePowerProfile !== effectiveProfile.dischargePowerProfile
            || previewChargePowerProfile !== effectiveProfile.chargePowerProfile
            || previewHdmiPowerProfile !== effectiveProfile.hdmiPowerProfile)
    readonly property int desiredEnd: temporaryMode === "FULL" ? 100
        : temporaryMode === "SAFE_FULL" ? 80
        : (effectiveProfile ? effectiveProfile.upperThreshold : 80)
    readonly property int desiredGap: temporaryMode.length > 0 ? 5
        : (effectiveProfile ? effectiveProfile.gap : 5)
    readonly property int desiredStart: Math.max(0, desiredEnd - desiredGap)
    property string readCommand: shellQuote(Qt.resolvedUrl("../code/read-battery-thresholds"))
    // Only this root-owned copy may safely receive passwordless authorization.
    property string helperPath: "/usr/local/libexec/battery-threshold-helper"

    readonly property bool charging: batteryStatus === "Charging"
    readonly property bool discharging: batteryStatus === "Discharging"
    // While charging, estimate the time to the configured upper limit. While
    // discharging, show the familiar remaining runtime until the battery is empty.
    readonly property int timeTarget: charging ? currentEnd : (discharging ? 0 : -1)
    readonly property real hoursToTarget: {
        if (powerWatts <= 0 || energyNowWh < 0 || energyFullWh <= 0 || timeTarget < 0)
            return -1
        var targetEnergy = energyFullWh * timeTarget / 100
        var energyDelta = charging ? targetEnergy - energyNowWh : energyNowWh - targetEnergy
        return energyDelta > 0 ? energyDelta / powerWatts : 0
    }

    Plasmoid.icon: "battery"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    function shellQuote(value) {
        var path = decodeURIComponent(value.toString().replace(/^file:\/\//, ""))
        return "'" + path.replace(/'/g, "'\\''") + "'"
    }
    function formatPower() {
        if (powerWatts < 0 || (!charging && !discharging)) return "— W"
        return (discharging ? "−" : "+") + powerWatts.toFixed(1) + " W"
    }
    function formatDuration(hours) {
        if (hours < 0 || !isFinite(hours)) return "—"
        var minutes = Math.max(0, Math.round(hours * 60))
        if (minutes < 60) return i18np("%1 min", "%1 min", minutes)
        var wholeHours = Math.floor(minutes / 60)
        var remainder = minutes % 60
        return remainder ? i18n("%1 h %2 min", wholeHours, remainder) : i18np("%1 h", "%1 h", wholeHours)
    }
    function powerProfileName(profile) {
        if (profile === "power-saver") return i18n("Power Save")
        if (profile === "balanced") return i18n("Balanced")
        if (profile === "performance") return i18n("Performance")
        return i18n("Unknown")
    }
    function powerProfileIconName() {
        if (currentPowerProfile === "power-saver") return Qt.resolvedUrl("../images/power-profile-powersave.svg")
        if (currentPowerProfile === "balanced") return Qt.resolvedUrl("../images/power-profile-balanced.svg")
        if (currentPowerProfile === "performance") return Qt.resolvedUrl("../images/power-profile-performance.svg")
        return ""
    }
    function defaultProfiles() {
        return [
            { id: "default", name: i18n("Default"), upperThreshold: 80, gap: 5, builtin: true,
                dischargePowerProfile: "power-saver", chargePowerProfile: "balanced", hdmiPowerProfile: "performance" },
            { id: "docked", name: i18n("Docked"), upperThreshold: 50, gap: 5, builtin: true,
                dischargePowerProfile: "power-saver", chargePowerProfile: "balanced", hdmiPowerProfile: "performance" }
        ]
    }
    function normalizedProfile(p) {
        return { id: p.id, name: p.name, upperThreshold: p.upperThreshold, gap: p.gap,
            builtin: !!p.builtin,
            dischargePowerProfile: p.dischargePowerProfile || "power-saver",
            chargePowerProfile: p.chargePowerProfile || "balanced",
            hdmiPowerProfile: p.hdmiPowerProfile || "performance" }
    }
    function loadProfiles() {
        try { profiles = JSON.parse(Plasmoid.configuration.profilesJson || "") }
        catch (e) { profiles = defaultProfiles(); saveProfiles() }
        if (!profiles || profiles.length < 2) { profiles = defaultProfiles(); saveProfiles() }
        else {
            profiles = profiles.map(normalizedProfile)
            saveProfiles()
        }
        // Never resume a transient Docked selection after Plasma restarts.
        selectProfile(Plasmoid.configuration.normalProfileId || selectedProfileId, false)
    }
    function saveProfiles() { Plasmoid.configuration.profilesJson = JSON.stringify(profiles) }
    function profileById(id) {
        for (var i = 0; i < profiles.length; ++i) if (profiles[i].id === id) return profiles[i]
        return profiles.length ? profiles[0] : null
    }
    function profileIndex(id) {
        for (var i = 0; i < profiles.length; ++i) if (profiles[i].id === id) return i
        return 0
    }
    function selectProfile(id, apply) {
        var p = profileById(id)
        if (!p) return
        Plasmoid.configuration.selectedProfileId = p.id
        if (!dockingDetected)
            Plasmoid.configuration.normalProfileId = p.id
        previewEnd = p.upperThreshold
        previewGap = p.gap
        previewDischargePowerProfile = p.dischargePowerProfile
        previewChargePowerProfile = p.chargePowerProfile
        previewHdmiPowerProfile = p.hdmiPowerProfile
        if (apply !== false) {
            reconcile()
            automaticPowerState = ""
            applyAutomaticPowerProfile()
        }
    }
    function updateSelectedProfile() {
        var index = profileIndex(selectedProfileId)
        var copy = profiles.slice()
        copy[index] = { id: copy[index].id, name: copy[index].name,
            upperThreshold: Math.max(50, Math.min(100, Math.round(previewEnd))),
            gap: Math.max(1, Math.min(20, Math.round(previewGap))),
            builtin: !!copy[index].builtin,
            dischargePowerProfile: previewDischargePowerProfile,
            chargePowerProfile: previewChargePowerProfile,
            hdmiPowerProfile: previewHdmiPowerProfile }
        profiles = copy
        saveProfiles()
        reconcile()
        automaticPowerState = ""
        applyAutomaticPowerProfile()
    }
    function revertSelectedProfile() {
        var p = effectiveProfile
        if (!p) return
        previewEnd = p.upperThreshold
        previewGap = p.gap
        previewDischargePowerProfile = p.dischargePowerProfile
        previewChargePowerProfile = p.chargePowerProfile
        previewHdmiPowerProfile = p.hdmiPowerProfile
    }
    function createProfile(name, upper, gap) {
        name = name.trim()
        if (!name.length) return false
        var id = "profile-" + Date.now()
        profiles = profiles.concat([{ id: id, name: name,
            upperThreshold: Math.max(50, Math.min(100, Math.round(upper))),
            gap: Math.max(1, Math.min(20, Math.round(gap))), builtin: false,
            dischargePowerProfile: "power-saver", chargePowerProfile: "balanced",
            hdmiPowerProfile: "performance" }])
        saveProfiles(); selectProfile(id, true); return true
    }
    function deleteSelectedProfile() {
        var p = profileById(selectedProfileId)
        if (!p || p.builtin) return
        profiles = profiles.filter(function(x) { return x.id !== p.id })
        saveProfiles(); selectProfile("default", true)
    }
    function refresh() { if (!applying) command.connectSource(readCommand) }
    function setProfilePowerMode(field, value) {
        if (field === "dischargePowerProfile") previewDischargePowerProfile = value
        else if (field === "chargePowerProfile") previewChargePowerProfile = value
        else if (field === "hdmiPowerProfile") previewHdmiPowerProfile = value
    }
    function desiredPowerProfile() {
        var p = effectiveProfile
        if (!p) return ""
        if (powerProfileOverride.length) return powerProfileOverride
        if (discharging || !acOnline) return p.dischargePowerProfile
        if (hdmiDisplayActive) return p.hdmiPowerProfile
        return p.chargePowerProfile
    }
    function setPowerProfileOverride(value) {
        powerProfileOverride = value
        automaticPowerState = ""
        applyAutomaticPowerProfile()
    }
    function applyAutomaticPowerProfile() {
        if (batteryCount < 1 || profiles.length === 0) return
        var wanted = desiredPowerProfile()
        if (!wanted.length) return
        // Applying only on a state transition keeps a subsequent manual choice
        // intact until AC, HDMI, the selected profile, or its setting changes.
        var state = selectedProfileId + "|" + (discharging ? "discharging" : (acOnline ? "ac" : "battery"))
            + "|" + (hdmiDisplayActive ? "hdmi" : "no-hdmi") + "|" + wanted
        if (state === automaticPowerState) return
        automaticPowerState = state
        command.connectSource("busctl set-property org.freedesktop.UPower.PowerProfiles "
            + "/org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles "
            + "ActiveProfile s " + shellQuote(wanted))
    }
    function determineDisplays() {
        var hints = displays.filter(function(d) { return d.kind === "internal-hint" })
        autoInternalDisplay = hints.length === 1 ? hints[0].name : ""
        var internalId = Plasmoid.configuration.internalDisplayId === "auto"
            ? autoInternalDisplay : Plasmoid.configuration.internalDisplayId
        externalDisplayActive = displays.some(function(d) {
            return d.name !== internalId && d.connection === "connected" && d.enabled === "enabled"
        })
        hdmiDisplayActive = displays.some(function(d) {
            return d.name.indexOf("HDMI-") === 0 && d.connection === "connected" && d.enabled === "enabled"
        })
        var candidate = Plasmoid.configuration.dockingEnabled && acOnline && externalDisplayActive
            && batteryStatus !== "Discharging"
        if (candidate !== dockingCandidate) {
            dockingCandidate = candidate
            dockingDebounce.restart()
        }
        applyAutomaticPowerProfile()
    }
    function commitDockingState() {
        if (dockingCandidate === dockingDetected)
            return
        if (dockingCandidate) {
            dockingDetected = true
            // Make the effective docking choice visible in the normal profile dropdown.
            selectProfile(Plasmoid.configuration.dockedProfileId, false)
        } else {
            dockingDetected = false
            selectProfile(Plasmoid.configuration.normalProfileId, false)
        }
        reconcile()
        automaticPowerState = ""
        applyAutomaticPowerProfile()
    }
    function parseStatus(output) {
        var lines = output.trim().split("\n")
        var foundDisplays = []
        for (var i = 0; i < lines.length; ++i) {
            var f = lines[i].split("|")
            if (f[0] === "STATUS") {
                batteryName = f[1]; capacity = parseInt(f[2]); batteryStatus = f[3]
                currentStart = parseInt(f[4]); currentEnd = parseInt(f[5])
                supported = f[6] === "1"; acOnline = f[7] === "1"; batteryCount = parseInt(f[8])
                var rawPower = parseFloat(f[9]); var rawEnergyNow = parseFloat(f[10]); var rawEnergyFull = parseFloat(f[11])
                powerWatts = isNaN(rawPower) ? -1 : Math.abs(rawPower) / 1000000
                energyNowWh = isNaN(rawEnergyNow) ? -1 : rawEnergyNow / 1000000
                energyFullWh = isNaN(rawEnergyFull) ? -1 : rawEnergyFull / 1000000
            } else if (f[0] === "HELPER") {
                helperInstalled = f[1] === "1"
                helperChecked = true
            } else if (f[0] === "DISPLAY") {
                foundDisplays.push({ name: f[1], connection: f[2], enabled: f[3], kind: f[4], edid: f[5] })
            } else if (f[0] === "POWER_PROFILE") {
                currentPowerProfile = f[1] || "unknown"
            }
        }
        displays = foundDisplays
        statusMessage = batteryCount === 0 ? i18n("No battery detected.")
            : batteryCount > 1 ? i18n("Multiple batteries detected; using %1.", batteryName)
            : !supported ? i18n("Charge limits are not supported by this battery driver.") : ""
        determineDisplays()
        if (temporaryMode === "FULL" && capacity >= 100) temporaryMode = ""
        if (temporaryMode === "SAFE_FULL" && capacity >= 80) temporaryMode = ""
        reconcile()
    }
    function reconcile() {
        if (!supported || !helperInstalled || applying || editing) return
        if (currentStart === desiredStart && currentEnd === desiredEnd) return
        applying = true
        var cmd = "pkexec " + shellQuote(helperPath) + " set " + shellQuote(batteryName)
            + " " + desiredStart + " " + desiredEnd
        command.connectSource(cmd)
    }
    function toggleTemporary(mode) {
        if (temporaryMode === mode) { temporaryMode = ""; reconcile(); return }
        if (mode === "SAFE_FULL" && capacity >= 80) {
            statusMessage = i18n("Battery is already at or above 80%."); return
        }
        temporaryMode = mode; reconcile()
    }

    compactRepresentation: PlasmaCore.ToolTipArea {
        readonly property real horizontalPadding: Kirigami.Units.largeSpacing
        readonly property real requiredWidth: row.implicitWidth + horizontalPadding * 2
        implicitWidth: requiredWidth
        implicitHeight: Math.max(row.implicitHeight, Kirigami.Units.iconSizes.smallMedium)
        Layout.minimumWidth: requiredWidth
        Layout.preferredWidth: requiredWidth
        Layout.maximumWidth: requiredWidth
        Layout.minimumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight
        mainText: i18n("Battery Charge Limits")
        subText: i18n("Charge: %1% / %2% · %3 · Remaining: %4",
                      root.capacity, root.currentEnd, root.formatPower(), root.formatDuration(root.hoursToTarget))
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: root.expanded = !root.expanded }
        RowLayout {
            id: row
            anchors.left: parent.left
            anchors.leftMargin: parent.horizontalPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Kirigami.Units.smallSpacing
            Text { text: root.formatPower(); color: Kirigami.Theme.disabledTextColor }
            Text { text: root.formatDuration(root.hoursToTarget); color: Kirigami.Theme.disabledTextColor }
            Text { text: root.capacity >= 0 && root.currentEnd >= 0 ? root.capacity + "% / " + root.currentEnd + "%" : "—"; color: Kirigami.Theme.textColor }
            BatteryGlyph {
                Layout.preferredWidth: 24; Layout.preferredHeight: 14
                glyphColor: Kirigami.Theme.textColor
                targetFillLevel: root.currentEnd / 100
                actualFillLevel: root.capacity / 100
                charging: root.charging
            }
            PlasmaCore.ToolTipArea {
                visible: root.currentPowerProfile !== "unknown"
                Layout.preferredWidth: visible ? 16 : 0
                Layout.preferredHeight: 16
                mainText: root.powerProfileName(root.currentPowerProfile)
                Kirigami.Icon {
                    anchors.fill: parent
                    source: root.powerProfileIconName()
                    isMask: true
                    color: Kirigami.Theme.textColor
                }
            }
            Text { visible: root.effectiveMode !== "Normal"; text: root.effectiveMode.charAt(0); color: Kirigami.Theme.highlightColor }
        }
    }
    fullRepresentation: Popup {}

    Plasma5Support.DataSource {
        id: command; engine: "executable"; connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            var output = data["stdout"] || ""
            if (source === root.readCommand) { root.parseStatus(output); return }
            if (source.indexOf("busctl set-property org.freedesktop.UPower.PowerProfiles ") === 0) {
                if (data["exit code"] !== 0) {
                    root.automaticPowerState = ""
                    var powerError = (data["stderr"] || "").trim().split("\n").pop()
                    root.statusMessage = powerError || i18n("Could not change the power profile.")
                } else {
                    root.refresh()
                }
                return
            }
            root.applying = false
            if (data["exit code"] === 0 && output.indexOf("OK|") >= 0) root.refresh()
            else {
                var error = (data["stderr"] || "").trim().split("\n").pop()
                root.statusMessage = error ? error.replace(/^ERROR\|/, "") : i18n("Permission denied or helper failed.")
            }
        }
    }
    Timer { interval: 10000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer {
        id: dockingDebounce; interval: 4000
        onTriggered: root.commitDockingState()
    }
    Component.onCompleted: loadProfiles()
}
