import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.notification

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
    property int refreshRateOverride: 0 // 0 means profile-controlled automatic mode, never persisted
    property bool applying: false
    property bool persistenceConfirmed: false
    property int reconcileFailureCount: 0
    property string lastFailedDesired: ""
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
    property bool previewManageIdleTimeouts: false
    property int previewScreenOffTimeoutMin: -1
    property int previewSuspendTimeoutMin: -1
    property string idleTimeoutState: ""
    property bool previewManageRefreshRate: false
    property int previewDischargeRefreshRate: 60
    property int previewChargeRefreshRate: 120
    property var kscreenOutputs: []
    property string pendingPowerProfileNotify: ""
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
            || previewHdmiPowerProfile !== effectiveProfile.hdmiPowerProfile
            || previewManageIdleTimeouts !== effectiveProfile.manageIdleTimeouts
            || previewScreenOffTimeoutMin !== effectiveProfile.screenOffTimeoutMin
            || previewSuspendTimeoutMin !== effectiveProfile.suspendTimeoutMin
            || previewManageRefreshRate !== effectiveProfile.manageRefreshRate
            || previewDischargeRefreshRate !== effectiveProfile.dischargeRefreshRate
            || previewChargeRefreshRate !== effectiveProfile.chargeRefreshRate)
    readonly property int desiredEnd: temporaryMode === "FULL" ? 100
        : temporaryMode === "SAFE_FULL" ? 80
        : (effectiveProfile ? effectiveProfile.upperThreshold : 80)
    readonly property int desiredGap: temporaryMode.length > 0 ? 5
        : (effectiveProfile ? effectiveProfile.gap : 5)
    readonly property int desiredStart: Math.max(0, desiredEnd - desiredGap)
    property string readCommand: shellQuote(Qt.resolvedUrl("../code/read-battery-thresholds"))
    // Only this root-owned copy may safely receive passwordless authorization.
    property string helperPath: "/usr/local/libexec/battery-threshold-helper"
    readonly property url thinkChargeIcon: Qt.resolvedUrl("../images/thinkcharge.svg")

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

    Plasmoid.icon: thinkChargeIcon
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
    property var pendingNotificationLines: []
    function notifyChange(text) {
        pendingNotificationLines.push(text)
        notificationBatchTimer.restart()
    }
    function flushNotifications() {
        if (!pendingNotificationLines.length) return
        changeNotification.text = pendingNotificationLines.join("\n")
        changeNotification.sendEvent()
        pendingNotificationLines = []
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
                dischargePowerProfile: "power-saver", chargePowerProfile: "balanced", hdmiPowerProfile: "performance",
                manageIdleTimeouts: false, screenOffTimeoutMin: -1, suspendTimeoutMin: -1,
                manageRefreshRate: false, dischargeRefreshRate: 60, chargeRefreshRate: 120 },
            { id: "docked", name: i18n("Docked"), upperThreshold: 50, gap: 5, builtin: true,
                dischargePowerProfile: "power-saver", chargePowerProfile: "balanced", hdmiPowerProfile: "performance",
                manageIdleTimeouts: false, screenOffTimeoutMin: -1, suspendTimeoutMin: -1,
                manageRefreshRate: false, dischargeRefreshRate: 60, chargeRefreshRate: 120 }
        ]
    }
    function validPowerProfile(value, fallback) {
        return ["power-saver", "balanced", "performance"].indexOf(value) >= 0 ? value : fallback
    }
    function validRefreshRate(value, fallback) {
        var n = Math.round(Number(value))
        return (isFinite(n) && n >= 30 && n <= 300) ? n : fallback
    }
    // -1 = leave the system default alone, 0 = never, otherwise minutes.
    function clampTimeoutMin(value) {
        var n = Math.round(Number(value))
        if (isNaN(n) || n < -1) return -1
        return Math.min(n, 24 * 60)
    }
    function normalizedProfile(p) {
        return { id: p.id, name: p.name,
            upperThreshold: Math.max(50, Math.min(100, Math.round(Number(p.upperThreshold) || 80))),
            gap: Math.max(1, Math.min(20, Math.round(Number(p.gap) || 5))),
            builtin: !!p.builtin,
            dischargePowerProfile: validPowerProfile(p.dischargePowerProfile, "power-saver"),
            chargePowerProfile: validPowerProfile(p.chargePowerProfile, "balanced"),
            hdmiPowerProfile: validPowerProfile(p.hdmiPowerProfile, "performance"),
            manageIdleTimeouts: !!p.manageIdleTimeouts,
            screenOffTimeoutMin: clampTimeoutMin(p.screenOffTimeoutMin === undefined ? -1 : p.screenOffTimeoutMin),
            suspendTimeoutMin: clampTimeoutMin(p.suspendTimeoutMin === undefined ? -1 : p.suspendTimeoutMin),
            manageRefreshRate: !!p.manageRefreshRate,
            dischargeRefreshRate: validRefreshRate(p.dischargeRefreshRate, 60),
            chargeRefreshRate: validRefreshRate(p.chargeRefreshRate, 120) }
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
        var previousId = Plasmoid.configuration.selectedProfileId
        Plasmoid.configuration.selectedProfileId = p.id
        if (!dockingDetected)
            Plasmoid.configuration.normalProfileId = p.id
        previewEnd = p.upperThreshold
        previewGap = p.gap
        previewDischargePowerProfile = p.dischargePowerProfile
        previewChargePowerProfile = p.chargePowerProfile
        previewHdmiPowerProfile = p.hdmiPowerProfile
        previewManageIdleTimeouts = p.manageIdleTimeouts
        previewScreenOffTimeoutMin = p.screenOffTimeoutMin
        previewSuspendTimeoutMin = p.suspendTimeoutMin
        previewManageRefreshRate = p.manageRefreshRate
        previewDischargeRefreshRate = p.dischargeRefreshRate
        previewChargeRefreshRate = p.chargeRefreshRate
        if (apply !== false) {
            reconcile()
            automaticPowerState = ""
            applyAutomaticPowerProfile(false)
            applyIdleTimeouts()
            applyAutomaticRefreshRate(false)
            if (p.id !== previousId) notifyChange(i18n("Switched to profile “%1”.", p.name))
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
            hdmiPowerProfile: previewHdmiPowerProfile,
            manageIdleTimeouts: previewManageIdleTimeouts,
            screenOffTimeoutMin: clampTimeoutMin(previewScreenOffTimeoutMin),
            suspendTimeoutMin: clampTimeoutMin(previewSuspendTimeoutMin),
            manageRefreshRate: previewManageRefreshRate,
            dischargeRefreshRate: validRefreshRate(previewDischargeRefreshRate, 60),
            chargeRefreshRate: validRefreshRate(previewChargeRefreshRate, 120) }
        profiles = copy
        saveProfiles()
        reconcile()
        automaticPowerState = ""
        applyAutomaticPowerProfile(false)
        applyIdleTimeouts()
        applyAutomaticRefreshRate(false)
        notifyChange(i18n("Profile “%1” saved.", copy[index].name))
    }
    function revertSelectedProfile() {
        var p = effectiveProfile
        if (!p) return
        previewEnd = p.upperThreshold
        previewGap = p.gap
        previewDischargePowerProfile = p.dischargePowerProfile
        previewChargePowerProfile = p.chargePowerProfile
        previewHdmiPowerProfile = p.hdmiPowerProfile
        previewManageIdleTimeouts = p.manageIdleTimeouts
        previewScreenOffTimeoutMin = p.screenOffTimeoutMin
        previewSuspendTimeoutMin = p.suspendTimeoutMin
        previewManageRefreshRate = p.manageRefreshRate
        previewDischargeRefreshRate = p.dischargeRefreshRate
        previewChargeRefreshRate = p.chargeRefreshRate
    }
    function createProfile(name, upper, gap) {
        name = name.trim()
        if (!name.length) return false
        var id = "profile-" + Date.now()
        profiles = profiles.concat([{ id: id, name: name,
            upperThreshold: Math.max(50, Math.min(100, Math.round(upper))),
            gap: Math.max(1, Math.min(20, Math.round(gap))), builtin: false,
            dischargePowerProfile: "power-saver", chargePowerProfile: "balanced",
            hdmiPowerProfile: "performance",
            manageIdleTimeouts: false, screenOffTimeoutMin: -1, suspendTimeoutMin: -1,
            manageRefreshRate: false, dischargeRefreshRate: 60, chargeRefreshRate: 120 }])
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
    function setManageIdleTimeouts(value) { previewManageIdleTimeouts = value }
    function setScreenOffTimeoutMin(value) { previewScreenOffTimeoutMin = value }
    function setSuspendTimeoutMin(value) { previewSuspendTimeoutMin = value }
    function setManageRefreshRate(value) { previewManageRefreshRate = value }
    function setDischargeRefreshRate(value) { previewDischargeRefreshRate = value }
    function setChargeRefreshRate(value) { previewChargeRefreshRate = value }
    function shellQuoteRaw(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'" }
    function internalKscreenOutput() {
        var internalId = Plasmoid.configuration.internalDisplayId === "auto" ? autoInternalDisplay : Plasmoid.configuration.internalDisplayId
        if (!internalId) return null
        for (var i = 0; i < kscreenOutputs.length; ++i) if (kscreenOutputs[i].name === internalId) return kscreenOutputs[i]
        return null
    }
    function currentKscreenMode(output) {
        if (!output || !output.modes) return null
        for (var i = 0; i < output.modes.length; ++i) if (output.modes[i].id === output.currentModeId) return output.modes[i]
        return null
    }
    // Only offers refresh rates that actually exist for the display's current
    // resolution, so profiles never target a mode the panel cannot show.
    function availableRefreshRates() {
        var output = internalKscreenOutput()
        var current = currentKscreenMode(output)
        var rates = []
        if (output && output.modes) {
            for (var i = 0; i < output.modes.length; ++i) {
                var m = output.modes[i]
                if (current && (m.size.width !== current.size.width || m.size.height !== current.size.height)) continue
                var r = Math.round(m.refreshRate)
                if (rates.indexOf(r) < 0) rates.push(r)
            }
        }
        if (!rates.length) rates = [60, 120]
        rates.sort(function(a, b) { return a - b })
        return rates
    }
    function desiredRefreshRate() {
        if (refreshRateOverride > 0) return refreshRateOverride
        var p = effectiveProfile
        if (!p || !p.manageRefreshRate) return 0
        return (discharging || !acOnline) ? p.dischargeRefreshRate : p.chargeRefreshRate
    }
    function currentRefreshRateHz() {
        var m = currentKscreenMode(internalKscreenOutput())
        return m ? Math.round(m.refreshRate) : -1
    }
    function maxRefreshRate() {
        var rates = availableRefreshRates()
        return rates.length ? rates[rates.length - 1] : 120
    }
    function toggleMaxRefreshRate() {
        refreshRateOverride = refreshRateOverride > 0 ? 0 : maxRefreshRate()
        applyAutomaticRefreshRate(false)
        notifyChange(refreshRateOverride > 0
            ? i18n("Maximum refresh rate forced (%1 Hz).", refreshRateOverride)
            : i18n("Refresh rate back to automatic."))
    }
    function refreshDisplayModes() { command.connectSource("kscreen-doctor -j") }
    // notify defaults to true (background/automatic transitions announce
    // themselves); pass false when the caller already shows its own message.
    // kscreen-doctor's own completion signal for a mode-set command has proven
    // unreliable — the real mode change still takes effect (the screen blanks
    // briefly), but our executable DataSource does not reliably see it finish.
    // Waiting for that confirmation left the widget stuck forever believing a
    // change was still in flight. So this applies optimistically: dispatch,
    // reflect the new mode in our own cache, and notify immediately, instead
    // of waiting on a signal that may never arrive.
    function applyAutomaticRefreshRate(notify) {
        var output = internalKscreenOutput()
        var current = currentKscreenMode(output)
        if (!output || !current) return
        var target = desiredRefreshRate()
        if (!target) return
        var best = current, bestDiff = Math.abs(current.refreshRate - target)
        for (var i = 0; i < output.modes.length; ++i) {
            var m = output.modes[i]
            if (m.size.width !== current.size.width || m.size.height !== current.size.height) continue
            var diff = Math.abs(m.refreshRate - target)
            if (diff < bestDiff) { bestDiff = diff; best = m }
        }
        if (best.id === output.currentModeId) return
        command.connectSource("kscreen-doctor " + shellQuoteRaw("output." + output.name + ".mode." + best.id))
        var updated = []
        for (var i2 = 0; i2 < kscreenOutputs.length; ++i2) {
            var o = kscreenOutputs[i2]
            updated.push(o.name === output.name ? Object.assign({}, o, { currentModeId: best.id }) : o)
        }
        kscreenOutputs = updated
        if (notify !== false) notifyChange(i18n("Refresh rate switched to %1 Hz.", Math.round(best.refreshRate)))
    }
    function desiredPowerProfile() {
        var p = effectiveProfile
        if (!p) return ""
        if (powerProfileOverride.length) return powerProfileOverride
        // An external display counts even without AC (e.g. a dock/monitor that
        // supplies no power delivery) so it is checked before the AC/discharge
        // fallback rather than after.
        if (hdmiDisplayActive || externalDisplayActive) return p.hdmiPowerProfile
        if (discharging || !acOnline) return p.dischargePowerProfile
        return p.chargePowerProfile
    }
    function setPowerProfileOverride(value) {
        powerProfileOverride = value
        automaticPowerState = ""
        applyAutomaticPowerProfile(false)
        notifyChange(value.length ? i18n("Power profile override: %1.", powerProfileName(value)) : i18n("Power profile override cleared."))
    }
    // notify defaults to true (background/automatic transitions announce
    // themselves); pass false when the caller already shows its own message.
    function applyAutomaticPowerProfile(notify) {
        if (batteryCount < 1 || profiles.length === 0) return
        var wanted = desiredPowerProfile()
        if (!wanted.length) return
        // Applying only on a state transition keeps a subsequent manual choice
        // intact until AC, HDMI, the selected profile, or its setting changes.
        var state = selectedProfileId + "|" + (discharging ? "discharging" : (acOnline ? "ac" : "battery"))
            + "|" + (hdmiDisplayActive ? "hdmi" : "no-hdmi") + "|" + wanted
        if (state === automaticPowerState) return
        automaticPowerState = state
        pendingPowerProfileNotify = notify === false ? "" : wanted
        command.connectSource("busctl set-property org.freedesktop.UPower.PowerProfiles "
            + "/org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles "
            + "ActiveProfile s " + shellQuote(wanted))
    }
    // Screen-off/sleep idle timeouts live entirely in PowerDevil's own
    // per-user config (~/.config/powerdevilrc) — no pkexec/root involved.
    function idleTimeoutCommands(group, screenOffMin, suspendMin) {
        var acGroup = "--group " + shellQuote(group)
        var cmds = []
        function write(group2, key, value, typeArgs) {
            cmds.push("kwriteconfig6 --file " + shellQuote("powerdevilrc") + " " + acGroup
                + " --group " + shellQuote(group2) + " --key " + shellQuote(key)
                + (typeArgs || "") + " --notify " + shellQuote(String(value)))
        }
        function del(group2, key) {
            cmds.push("kwriteconfig6 --file " + shellQuote("powerdevilrc") + " " + acGroup
                + " --group " + shellQuote(group2) + " --key " + shellQuote(key) + " --delete --notify")
        }
        if (screenOffMin < 0) {
            del("Display", "TurnOffDisplayWhenIdle")
            del("Display", "TurnOffDisplayIdleTimeoutSec")
        } else if (screenOffMin === 0) {
            write("Display", "TurnOffDisplayWhenIdle", "false", " --type bool")
        } else {
            write("Display", "TurnOffDisplayWhenIdle", "true", " --type bool")
            write("Display", "TurnOffDisplayIdleTimeoutSec", screenOffMin * 60)
        }
        if (suspendMin < 0) del("SuspendAndShutdown", "AutoSuspendIdleTimeoutSec")
        else write("SuspendAndShutdown", "AutoSuspendIdleTimeoutSec", suspendMin * 60)
        return cmds
    }
    function applyIdleTimeouts() {
        var p = effectiveProfile
        if (!p) return
        var group = acOnline ? "AC" : "Battery"
        var screenOffMin = p.manageIdleTimeouts ? p.screenOffTimeoutMin : -1
        var suspendMin = p.manageIdleTimeouts ? p.suspendTimeoutMin : -1
        var state = group + "|" + screenOffMin + "|" + suspendMin
        if (state === idleTimeoutState) return
        idleTimeoutState = state
        command.connectSource(idleTimeoutCommands(group, screenOffMin, suspendMin).join(" && "))
    }
    function determineDisplays() {
        hdmiDisplayActive = displays.some(function(d) {
            return d.name.indexOf("HDMI-") === 0 && d.connection === "connected" && d.enabled === "enabled"
        })
        // HDMI power-profile selection is independent from automatic docking.
        // Do not evaluate or debounce a docking state while the option is off.
        if (!Plasmoid.configuration.dockingEnabled) {
            externalDisplayActive = false
            applyAutomaticPowerProfile()
            applyIdleTimeouts()
            applyAutomaticRefreshRate()
            return
        }
        var hints = displays.filter(function(d) { return d.kind === "internal-hint" })
        autoInternalDisplay = hints.length === 1 ? hints[0].name : ""
        var internalId = Plasmoid.configuration.internalDisplayId === "auto"
            ? autoInternalDisplay : Plasmoid.configuration.internalDisplayId
        // Only physical presence matters for docking; a DPMS-blanked external
        // monitor still reports "connected" even though "enabled" goes false.
        externalDisplayActive = displays.some(function(d) {
            return d.name !== internalId && d.connection === "connected"
        })
        var candidate = acOnline && externalDisplayActive && batteryStatus !== "Discharging"
        if (candidate !== dockingCandidate) {
            dockingCandidate = candidate
            dockingDebounce.restart()
        }
        applyAutomaticPowerProfile()
        applyIdleTimeouts()
        applyAutomaticRefreshRate()
    }
    function setDockingEnabled(enabled) {
        Plasmoid.configuration.dockingEnabled = enabled
        dockingDebounce.stop()
        dockingCandidate = false
        if (!enabled) {
            if (dockingDetected) {
                dockingDetected = false
                selectProfile(Plasmoid.configuration.normalProfileId, false)
                reconcile()
                automaticPowerState = ""
                applyAutomaticPowerProfile(false)
                applyIdleTimeouts()
                applyAutomaticRefreshRate(false)
                notifyChange(i18n("Docking disabled — switched to profile “%1”.", profileById(Plasmoid.configuration.normalProfileId).name))
            }
            return
        }
        determineDisplays()
    }
    function commitDockingState() {
        if (!Plasmoid.configuration.dockingEnabled)
            return
        if (dockingCandidate === dockingDetected)
            return
        if (dockingCandidate) {
            dockingDetected = true
            // Make the effective docking choice visible in the normal profile dropdown.
            selectProfile(Plasmoid.configuration.dockedProfileId, false)
            notifyChange(i18n("Docking detected — switched to profile “%1”.", profileById(Plasmoid.configuration.dockedProfileId).name))
        } else {
            dockingDetected = false
            selectProfile(Plasmoid.configuration.normalProfileId, false)
            notifyChange(i18n("Docking ended — switched to profile “%1”.", profileById(Plasmoid.configuration.normalProfileId).name))
        }
        reconcile()
        automaticPowerState = ""
        applyAutomaticPowerProfile(false)
        applyIdleTimeouts()
        applyAutomaticRefreshRate(false)
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
                foundDisplays.push({ name: f[1], connection: f[2], enabled: f[3], kind: f[4] })
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
        if (currentStart === desiredStart && currentEnd === desiredEnd
                && (temporaryMode.length > 0 || persistenceConfirmed)) return
        var desiredKey = desiredStart + ":" + desiredEnd
        // Stop hammering pkexec every 10s for a pair the helper keeps rejecting;
        // retry only once the desired thresholds actually change.
        if (desiredKey === lastFailedDesired && reconcileFailureCount >= 3) return
        applying = true
        // Temporary full-charge modes must not become the next boot's limits.
        var action = temporaryMode.length > 0 ? "apply" : "set"
        var cmd = "pkexec " + shellQuote(helperPath) + " " + action + " " + shellQuote(batteryName)
            + " " + desiredStart + " " + desiredEnd
        command.connectSource(cmd)
    }
    function toggleTemporary(mode) {
        if (temporaryMode === mode) {
            temporaryMode = ""; reconcile()
            notifyChange(i18n("Temporary charge override cleared."))
            return
        }
        if (mode === "SAFE_FULL" && capacity >= 80) {
            statusMessage = i18n("Battery is already at or above 80%."); return
        }
        temporaryMode = mode; reconcile()
        notifyChange(mode === "FULL" ? i18n("Charging to 100% until turned off.") : i18n("Charging to 80% (safe full) until turned off."))
    }
    // Replicates KDE's own "block sleep and screen locking" toggle via the
    // standard freedesktop inhibition interfaces. Cookies are persisted so a
    // plasmashell-only restart (unlike KWin/PowerDevil) can still release the
    // real inhibition later instead of leaking it.
    function releaseKeepAwakeCookies(sleepCookie, screenCookie) {
        var cmds = []
        if (sleepCookie >= 0)
            cmds.push("busctl --user call org.kde.Solid.PowerManagement /org/freedesktop/PowerManagement/Inhibit "
                + "org.freedesktop.PowerManagement.Inhibit UnInhibit u " + sleepCookie)
        if (screenCookie >= 0)
            cmds.push("busctl --user call org.freedesktop.ScreenSaver /org/freedesktop/ScreenSaver "
                + "org.freedesktop.ScreenSaver UnInhibit u " + screenCookie)
        if (cmds.length) command.connectSource(cmds.join(" && "))
    }
    function setKeepAwake(enabled) {
        if (enabled === Plasmoid.configuration.keepAwake) return
        if (!enabled) {
            releaseKeepAwakeCookies(Plasmoid.configuration.keepAwakeSleepCookie, Plasmoid.configuration.keepAwakeScreenCookie)
            Plasmoid.configuration.keepAwake = false
            Plasmoid.configuration.keepAwakeSleepCookie = -1
            Plasmoid.configuration.keepAwakeScreenCookie = -1
            notifyChange(i18n("Keep awake disabled."))
            return
        }
        var appName = shellQuote("ThinkCharge")
        var reason = shellQuote("Manually kept awake")
        command.connectSource("busctl --user call org.kde.Solid.PowerManagement /org/freedesktop/PowerManagement/Inhibit "
            + "org.freedesktop.PowerManagement.Inhibit Inhibit ss " + appName + " " + reason
            + " && busctl --user call org.freedesktop.ScreenSaver /org/freedesktop/ScreenSaver "
            + "org.freedesktop.ScreenSaver Inhibit ss " + appName + " " + reason)
        notifyChange(i18n("Keep awake enabled — sleep and screen locking are blocked."))
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
        mainText: i18n("ThinkCharge")
        subText: i18n("Charge: %1% / %2% · %3 · Remaining: %4",
                      root.capacity, root.currentEnd, root.formatPower(), root.formatDuration(root.hoursToTarget))
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: root.expanded = !root.expanded }
        RowLayout {
            id: row
            anchors.left: parent.left
            anchors.leftMargin: parent.horizontalPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Kirigami.Units.smallSpacing
          //  Text { text: root.formatPower(); color: Kirigami.Theme.disabledTextColor }
          //  Text { text: root.formatDuration(root.hoursToTarget); color: Kirigami.Theme.disabledTextColor }
         //   Text { text: root.capacity >= 0 && root.currentEnd >= 0 ? root.currentStart + "/" + root.currentEnd + " " : "—"; font.pointSize: 8; color: Kirigami.Theme.textColor }
            Text { text: root.capacity >= 0 && root.currentEnd >= 0 ? root.currentStart + "%\n" + root.currentEnd + "%" : "—"; font.pointSize: 7; color: Kirigami.Theme.textColor }
            //  Text { text: root.capacity >= 0 && root.currentEnd >= 0 ? root.capacity + "% / " + root.currentEnd + "%" : "—"; color: Kirigami.Theme.textColor }
            BatteryGlyph {
                visible: Plasmoid.configuration.showBattery
                Layout.preferredWidth: 22; Layout.preferredHeight: 10
                glyphColor: Kirigami.Theme.textColor
                targetFillLevel: root.currentEnd / 100
                actualFillLevel: root.capacity / 100
                charging: root.charging
            }
            PlasmaCore.ToolTipArea {
                // visible: root.currentPowerProfile !== "unknown"
                visible: Plasmoid.configuration.showPowerMode
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

    Notification {
        id: changeNotification
        componentName: "plasma_workspace"
        eventId: "notification"
        iconName: decodeURIComponent(root.thinkChargeIcon.toString().replace(/^file:\/\//, ""))
        title: i18n("ThinkCharge")
    }
    // Coalesces notifications that land within the same short burst (e.g. a
    // single AC plug/unplug can change both power profile and refresh rate)
    // into a single popup instead of spamming one per change.
    // 1.2s: long enough to still catch the refresh-rate change, which involves
    // an actual monitor mode switch and so completes noticeably slower than
    // the near-instant power-profile DBus call from the same AC transition.
    Timer { id: notificationBatchTimer; interval: 1200; repeat: false; onTriggered: root.flushNotifications() }

    Plasma5Support.DataSource {
        id: command; engine: "executable"; connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            var output = data["stdout"] || ""
            if (source === root.readCommand) { root.parseStatus(output); return }
            if (source === "kscreen-doctor -j") {
                try { root.kscreenOutputs = (JSON.parse(output) || {}).outputs || [] }
                catch (e) { root.kscreenOutputs = [] }
                root.applyAutomaticRefreshRate()
                return
            }
            if (source.indexOf("kscreen-doctor output.") === 0) {
                // The change was already applied optimistically when dispatched
                // (see applyAutomaticRefreshRate) since this completion signal
                // is unreliable; only surface a genuine failure here.
                if (data["exit code"] !== 0) {
                    var rateError = (data["stderr"] || "").trim().split("\n").pop()
                    root.statusMessage = rateError || i18n("Could not change the refresh rate.")
                }
                return
            }
            if (source.indexOf("busctl set-property org.freedesktop.UPower.PowerProfiles ") === 0) {
                if (data["exit code"] !== 0) {
                    root.automaticPowerState = ""
                    root.pendingPowerProfileNotify = ""
                    var powerError = (data["stderr"] || "").trim().split("\n").pop()
                    root.statusMessage = powerError || i18n("Could not change the power profile.")
                }// else if (root.pendingPowerProfileNotify.length) {
                  //  root.notifyChange(i18n("Power profile switched to %1.", root.powerProfileName(root.pendingPowerProfileNotify)))
                 //   root.pendingPowerProfileNotify = ""
               // }
                return
            }
            if (source.indexOf("kwriteconfig6 ") === 0) {
                if (data["exit code"] !== 0) {
                    root.idleTimeoutState = ""
                    var idleError = (data["stderr"] || "").trim().split("\n").pop()
                    root.statusMessage = idleError || i18n("Could not update screen/sleep timeouts.")
                }
                return
            }
            if (source.indexOf("busctl --user call ") === 0) {
                if (source.indexOf(" Inhibit ss ") >= 0) {
                    var cookies = output.match(/\d+/g)
                    if (data["exit code"] === 0 && cookies && cookies.length >= 2) {
                        Plasmoid.configuration.keepAwake = true
                        Plasmoid.configuration.keepAwakeSleepCookie = parseInt(cookies[0])
                        Plasmoid.configuration.keepAwakeScreenCookie = parseInt(cookies[1])
                    } else {
                        // Partial success (e.g. only the sleep inhibition went through)
                        // must not leak — release whatever cookie we did get.
                        if (cookies && cookies.length >= 1) root.releaseKeepAwakeCookies(parseInt(cookies[0]), -1)
                        var awakeError = (data["stderr"] || "").trim().split("\n").pop()
                        root.statusMessage = awakeError || i18n("Could not enable keep-awake.")
                    }
                }
                return
            }
            root.applying = false
            if (data["exit code"] === 0 && output.indexOf("OK|") >= 0) {
                if (source.indexOf(" set ") >= 0) root.persistenceConfirmed = true
                root.reconcileFailureCount = 0
                root.lastFailedDesired = ""
                root.refresh()
            }
            else {
                var error = (data["stderr"] || "").trim().split("\n").pop()
                root.statusMessage = error ? error.replace(/^ERROR\|/, "") : i18n("Permission denied or helper failed.")
                var failedKey = root.desiredStart + ":" + root.desiredEnd
                if (failedKey === root.lastFailedDesired) root.reconcileFailureCount++
                else { root.lastFailedDesired = failedKey; root.reconcileFailureCount = 1 }
            }
        }
    }
    Timer { interval: 10000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer {
        id: dockingDebounce; interval: 4000
        onTriggered: root.commitDockingState()
    }
    Component.onCompleted: { loadProfiles(); refreshDisplayModes() }

}
