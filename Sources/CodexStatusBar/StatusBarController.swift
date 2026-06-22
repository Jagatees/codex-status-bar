import AppKit
import UserNotifications

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store = StateStore()
    private let preferences = Preferences()
    private var state = StatusState.idle
    private var pollTimer: Timer?
    private var animationFrame = 0
    private var previousStatus: CodexStatus = .idle
    private var completionObservedAt: Date?
    private var stateWasStale = false

    override init() {
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        restartPolling()
        updateDisplay()
        installHooksIfNeeded()
    }

    private func restartPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: preferences.pollInterval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        tick()
    }

    private func tick() {
        if let newState = store.readIfChanged() {
            previousStatus = state.status
            stateWasStale = newState.isStale
            state = stateWasStale ? .idle : newState
            if newState.status == .complete && previousStatus != .complete {
                completionObservedAt = Date()
                sendCompletionNotification()
            } else if newState.status != .complete {
                completionObservedAt = nil
            }
        }
        if state.status == .complete,
           let observed = completionObservedAt,
           let delay = preferences.autoIdleDelay,
           Date().timeIntervalSince(observed) >= delay {
            state = .idle
        }
        animationFrame += 1
        updateDisplay()
    }

    private func updateDisplay() {
        guard let button = statusItem.button else { return }
        button.image = IconRenderer.image(for: state.status, style: preferences.iconStyle, frame: animationFrame)
        var parts: [String] = []
        if preferences.showLabel && state.status != .idle { parts.append(state.displayLabel) }
        if preferences.showTimer, let started = state.startedAt, state.status.isActive {
            parts.append(Self.duration(Date().timeIntervalSince(started)))
        }
        // Keep an explicit idle label so macOS never collapses the status item if an
        // SF Symbol fails to render or menu-bar app controls suppress icon-only items.
        button.title = parts.isEmpty ? " Codex" : " " + parts.joined(separator: " ")
        button.toolTip = "Codex Status Bar: \(state.displayLabel)"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(disabledItem("Codex Status Bar"))
        menu.addItem(.separator())
        menu.addItem(disabledItem("Status: \(state.displayLabel)"))
        menu.addItem(disabledItem("Timer: \(elapsedText())"))
        if let cwd = state.cwd { menu.addItem(disabledItem("Project: \((cwd as NSString).abbreviatingWithTildeInPath)")) }
        if let tool = state.toolName { menu.addItem(disabledItem("Tool: \(tool)")) }
        if stateWasStale { menu.addItem(disabledItem("Warning: state is stale")) }
        if let error = state.error { menu.addItem(disabledItem("Error: \(error)")) }

        menu.addItem(.separator())
        menu.addItem(actionItem("Open Codex Config Folder", #selector(openConfigFolder)))
        menu.addItem(actionItem("Open State File", #selector(openStateFile)))

        let preferencesItem = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        preferencesItem.submenu = preferencesMenu()
        menu.addItem(preferencesItem)

        menu.addItem(.separator())
        menu.addItem(actionItem("Restart Status Bar", #selector(restart)))
        menu.addItem(actionItem("Quit", #selector(quit), key: "q"))
    }

    private func preferencesMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(toggleItem("Show timer", preferences.showTimer, #selector(toggleTimer)))
        menu.addItem(toggleItem("Show status label", preferences.showLabel, #selector(toggleLabel)))
        menu.addItem(toggleItem("Enable notifications", preferences.notificationsEnabled, #selector(toggleNotifications)))
        menu.addItem(toggleItem("Launch at login", launchAgentExists(), #selector(toggleLaunchAtLogin)))

        let icon = NSMenuItem(title: "Icon style", action: nil, keyEquivalent: "")
        icon.submenu = NSMenu()
        for style in IconStyle.allCases {
            let item = actionItem(style.rawValue, #selector(selectIconStyle(_:)))
            item.representedObject = style.rawValue
            item.state = preferences.iconStyle == style ? .on : .off
            icon.submenu?.addItem(item)
        }
        menu.addItem(icon)

        let idle = NSMenuItem(title: "Return to idle", action: nil, keyEquivalent: "")
        idle.submenu = NSMenu()
        for (title, value) in [("After 3 seconds", 3.0), ("After 5 seconds", 5.0), ("After 10 seconds", 10.0), ("Never", -1.0)] {
            let item = actionItem(title, #selector(selectIdleDelay(_:)))
            item.representedObject = value
            item.state = (preferences.autoIdleDelay ?? -1) == value ? .on : .off
            idle.submenu?.addItem(item)
        }
        menu.addItem(idle)

        let polling = NSMenuItem(title: "Poll interval", action: nil, keyEquivalent: "")
        polling.submenu = NSMenu()
        for value in [0.25, 0.5, 1.0] {
            let item = actionItem(value == 1 ? "1 second" : "\(Int(value * 1000)) ms", #selector(selectPollInterval(_:)))
            item.representedObject = value
            item.state = preferences.pollInterval == value ? .on : .off
            polling.submenu?.addItem(item)
        }
        menu.addItem(polling)
        return menu
    }

    private func actionItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func toggleItem(_ title: String, _ enabled: Bool, _ action: Selector) -> NSMenuItem {
        let item = actionItem(title, action)
        item.state = enabled ? .on : .off
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func elapsedText() -> String {
        guard let start = state.startedAt else { return "--" }
        let end = state.completedAt ?? Date()
        return Self.duration(end.timeIntervalSince(start))
    }

    static func duration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }

    private func installHooksIfNeeded() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let installedHook = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/statusbar/hooks/codex-status-hook.js")
        let needsInstall = UserDefaults.standard.string(forKey: "installedHookVersion") != version ||
            !FileManager.default.fileExists(atPath: installedHook.path)
        guard needsInstall,
              let script = Bundle.main.path(forResource: "install", ofType: "js") else { return }
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["node", script, "--from-app"]
            try? process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                UserDefaults.standard.set(version, forKey: "installedHookVersion")
            }
        }
    }

    private func sendCompletionNotification() {
        guard preferences.notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Codex turn complete"
            content.body = self.state.lastMessage ?? "Codex has finished working."
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    @objc private func toggleTimer() { preferences.showTimer.toggle(); updateDisplay() }
    @objc private func toggleLabel() { preferences.showLabel.toggle(); updateDisplay() }
    @objc private func toggleNotifications() { preferences.notificationsEnabled.toggle() }
    @objc private func toggleLaunchAtLogin() {
        let url = launchAgentURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let executable = Bundle.main.executableURL?.path ?? ""
        let plist: [String: Any] = [
            "Label": "com.jagatees.codexstatusbar",
            "ProgramArguments": [executable],
            "RunAtLoad": true,
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
    @objc private func selectIconStyle(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let style = IconStyle(rawValue: raw) { preferences.iconStyle = style; updateDisplay() }
    }
    @objc private func selectIdleDelay(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double { preferences.autoIdleDelay = value < 0 ? nil : value }
    }
    @objc private func selectPollInterval(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double { preferences.pollInterval = value; restartPolling() }
    }
    @objc private func openConfigFolder() { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")) }
    @objc private func openStateFile() {
        if FileManager.default.fileExists(atPath: store.stateURL.path) { NSWorkspace.shared.open(store.stateURL) }
        else { openConfigFolder() }
    }
    @objc private func restart() {
        let bundlePath = Bundle.main.bundlePath.replacingOccurrences(of: "'", with: "'\\''")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 0.5; /usr/bin/open -g '\(bundlePath)'"]
        try? process.run()
        NSApp.terminate(nil)
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func launchAgentURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.jagatees.codexstatusbar.plist")
    }

    private func launchAgentExists() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentURL().path)
    }
}
