import AppKit

@main
struct CodexStatusBarApp {
    private static let appDelegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = appDelegate
        application.setActivationPolicy(.accessory)
        application.finishLaunching()
        appDelegate.startStatusBar()
        withExtendedLifetime(appDelegate) {
            application.run()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        startStatusBar()
    }

    func startStatusBar() {
        if controller == nil {
            controller = StatusBarController()
        }
    }
}
