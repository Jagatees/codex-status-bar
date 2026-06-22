import Foundation

enum IconStyle: String, CaseIterable {
    case system = "System monochrome"
    case green = "Codex green"
    case dots = "Minimal dots"
}

final class Preferences {
    private let defaults = UserDefaults.standard

    var showTimer: Bool {
        get { defaults.object(forKey: "showTimer") == nil ? true : defaults.bool(forKey: "showTimer") }
        set { defaults.set(newValue, forKey: "showTimer") }
    }

    var showLabel: Bool {
        get { defaults.object(forKey: "showLabel") == nil ? true : defaults.bool(forKey: "showLabel") }
        set { defaults.set(newValue, forKey: "showLabel") }
    }

    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: "notificationsEnabled") }
        set { defaults.set(newValue, forKey: "notificationsEnabled") }
    }

    var iconStyle: IconStyle {
        get { IconStyle(rawValue: defaults.string(forKey: "iconStyle") ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: "iconStyle") }
    }

    var autoIdleDelay: TimeInterval? {
        get {
            let value = defaults.object(forKey: "autoIdleDelay") == nil ? 5.0 : defaults.double(forKey: "autoIdleDelay")
            return value < 0 ? nil : value
        }
        set { defaults.set(newValue ?? -1, forKey: "autoIdleDelay") }
    }

    var pollInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: "pollInterval")
            return [0.25, 0.5, 1.0].contains(value) ? value : 0.5
        }
        set { defaults.set(newValue, forKey: "pollInterval") }
    }
}
