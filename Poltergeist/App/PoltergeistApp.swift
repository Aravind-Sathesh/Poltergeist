import SwiftUI

@main
struct PoltergeistApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    // Everything lives in the menu bar; SwiftUI just needs one scene.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let haunting = Haunting()
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit tests run inside this app. They must never start haunting.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let statusItem = StatusItemController(haunting: haunting)
        self.statusItem = statusItem
        if let folder = Snapshot.folder {
            haunting.haunt(with: Snapshot.whispers)
            statusItem.snapshot(to: folder)
        } else {
            haunting.start()
        }
    }
}
