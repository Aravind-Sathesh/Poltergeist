import AppKit
import IOKit.ps

/// Everything the ghost can perceive on this Mac. Each sense reports omens through `onOmen`; nothing leaves the machine.
@MainActor
final class Senses {
    var onOmen: (Omen) -> Void = { _ in }

    private var timer: Timer?
    private var ticks = 0

    // Shell: we read only what zsh appends after launch, so old history is never haunted.
    private let historyURL = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".zsh_history")
    private var historyOffset: UInt64 = 0
    private var lastCommand: String?

    private var frontApp: (name: String, since: Date)?
    private var announcedHours = 0
    private var sleptAt: Date?
    private var wasIdle = false
    private var downloadsBand = 0
    private var batteryWarnedAt: Int?
    private var nightHourSeen: Int?

    /// Seconds since the last key press, click or mouse move anywhere.
    var idleSeconds: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// Nobody to whisper to.
    var isIdle: Bool { idleSeconds > 5 * 60 }

    func start() {
        historyOffset = historySize() ?? 0
        if let app = NSWorkspace.shared.frontmostApplication?.localizedName { frontApp = (app, Date()) }
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let name = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.localizedName
            MainActor.assumeIsolated { self?.activated(name) }
        }
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleptAt = Date() }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.woke() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        ticks += 1
        readShell()
        noticeReturn()
        watchFrontApp()
        watchBattery()
        watchNight()
        if ticks % 360 == 24 { countDownloads() } // two minutes after launch, then every half hour
    }

    // MARK: Shell

    private func historySize() -> UInt64? {
        (try? FileManager.default.attributesOfItem(atPath: historyURL.path)[.size] as? NSNumber)?.uint64Value
    }

    private func readShell() {
        guard let size = historySize() else { return }
        if size < historyOffset { historyOffset = size } // zsh rewrote and trimmed the file
        guard size > historyOffset, let handle = try? FileHandle(forReadingFrom: historyURL) else { return }
        defer { try? handle.close() }
        try? handle.seek(toOffset: historyOffset)
        guard let data = try? handle.readToEnd(), let lastNewline = data.lastIndex(of: 0x0A) else { return }
        let complete = data[data.startIndex...lastNewline] // leave a half-written line for next time
        historyOffset += UInt64(complete.count)
        let commands = ShellHistory.commands(in: Data(complete))
        ShellHistory.omens(for: commands, after: lastCommand).forEach(onOmen)
        lastCommand = commands.last.map(ShellHistory.redact) ?? lastCommand
    }

    // MARK: Apps, sleep and absence

    private func activated(_ name: String?) {
        guard let name, name != frontApp?.name else { return }
        frontApp = (name, Date())
        announcedHours = 0
    }

    private func watchFrontApp() {
        guard let app = frontApp, !isIdle else { return }
        let elapsed = Date().timeIntervalSince(app.since)
        let hours = Int(elapsed / 3600)
        guard hours >= 1, hours > announcedHours else { return }
        announcedHours = hours
        onOmen(Omen(detail: "\(app.name) has been the frontmost app for \(spoken(elapsed)).", weight: .curious))
    }

    private func noticeReturn() {
        let idle = idleSeconds
        if idle > 20 * 60 { wasIdle = true; return }
        guard wasIdle, idle < 10 else { return }
        wasIdle = false
        frontApp = frontApp.map { ($0.name, Date()) } // hours in an app only count while someone is there
        onOmen(Omen(detail: "They just came back to the computer after being away.", weight: .curious))
    }

    private func woke() {
        guard let slept = sleptAt else { return }
        sleptAt = nil
        let away = Date().timeIntervalSince(slept)
        guard away > 10 * 60 else { return }
        onOmen(Omen(detail: "Their Mac just woke up after sleeping for \(spoken(away)).", weight: .curious))
    }

    // MARK: Battery, clock, Downloads

    private func watchBattery() {
        guard let (percent, discharging) = Self.battery() else { return }
        guard discharging else { batteryWarnedAt = nil; return }
        guard let threshold = [5, 10, 20].first(where: { percent <= $0 }), threshold < (batteryWarnedAt ?? 100) else { return }
        batteryWarnedAt = threshold
        onOmen(Omen(detail: "Battery is at \(percent)% and not charging.", weight: threshold <= 10 ? .startling : .curious))
    }

    private static func battery() -> (Int, Bool)? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let now = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            return (now * 100 / max, d[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue)
        }
        return nil
    }

    private func watchNight() {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour < 5, hour != nightHourSeen, !isIdle else { return }
        nightHourSeen = hour
        onOmen(Omen(detail: "It is \(Date().formatted(date: .omitted, time: .shortened)) and they are still at the computer.", weight: .curious))
    }

    private func countDownloads() {
        guard let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first,
              let count = try? FileManager.default.contentsOfDirectory(atPath: downloads.path).filter({ !$0.hasPrefix(".") }).count else { return }
        let band = count / 100
        guard band >= 1, band > downloadsBand else { return }
        downloadsBand = band
        onOmen(Omen(detail: "Their Downloads folder holds \(count) files.", weight: .curious))
    }
}
