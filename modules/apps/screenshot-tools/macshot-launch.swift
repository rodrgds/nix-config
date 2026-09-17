import AppKit

private let appURL = URL(fileURLWithPath: "/Applications/macshot.app")
private let bundleID = "com.sw33tlie.macshot.macshot"
private let launchTimeout: TimeInterval = 15

private func fail(_ message: String) -> Never {
    fputs("macshot-launch: \(message)\n", stderr)
    exit(1)
}

guard CommandLine.arguments.count == 2,
      ["capture", "ocr"].contains(CommandLine.arguments[1]) else {
    fail("usage: macshot-launch capture|ocr")
}
private let actionURL = URL(string: "macshot://\(CommandLine.arguments[1])")!
private let deadline = Date().addingTimeInterval(launchTimeout)
private var application: NSRunningApplication?
private var requestSent = false

// Keep Launch Services as the single app owner. Reopening an already running
// Macshot would unnecessarily show its settings window.
if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
    application = running
} else {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
        DispatchQueue.main.async {
            if let error { fail(error.localizedDescription) }
            application = app
        }
    }
}

// In 4.2.1, sending a URL during launch lets overlay prewarming tear down the
// requested capture. Wait for AppKit's launch lifecycle, not a fixed delay.
let timer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { _ in
    if Date() >= deadline { fail("Macshot did not finish launching within 15 seconds") }
    guard !requestSent, let app = application else { return }
    if app.isTerminated { fail("Macshot exited before receiving the capture request") }
    guard app.isFinishedLaunching else { return }
    requestSent = true
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    NSWorkspace.shared.open([actionURL], withApplicationAt: appURL, configuration: configuration) { _, error in
        if let error { fail(error.localizedDescription) }
        exit(0)
    }
}
RunLoop.main.run()
