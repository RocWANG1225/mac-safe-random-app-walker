import AppKit
import CoreGraphics
import Foundation

let minDelaySeconds: UInt32 = 180
let maxDelaySeconds: UInt32 = 300

let browserNames: Set<String> = ["Safari", "Google Chrome", "Microsoft Edge", "Firefox", "Arc"]
let feishuNames: Set<String> = ["Feishu", "Lark", "飞书"]
let deniedNames: Set<String> = [
    "Finder",
    "System Settings",
    "System Preferences",
    "Terminal",
    "iTerm2",
    "Activity Monitor",
    "Keychain Access",
    "1Password"
]

struct WindowBounds {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

enum AppKind {
    case browser
    case feishu
    case generic
}

let runOnce = CommandLine.arguments.contains("--once")

repeat {
    doOneRound()
    if runOnce { break }
    sleep(UInt32.random(in: minDelaySeconds...maxDelaySeconds))
} while true

func doOneRound() {
    guard let app = chooseRunningApp(), let name = app.localizedName else { return }
    app.activate(options: [.activateAllWindows])
    randomPause(0.8, 1.6)

    guard let window = frontWindowBounds(for: app.processIdentifier) else { return }

    switch classify(name) {
    case .browser:
        browseBrowser(window)
    case .feishu:
        browseFeishu(window)
    case .generic:
        browseGenericApp(window)
    }
}

func chooseRunningApp() -> NSRunningApplication? {
    let apps = NSWorkspace.shared.runningApplications.filter { app in
        guard app.activationPolicy == .regular, let name = app.localizedName else { return false }
        return !deniedNames.contains(name) && !app.isHidden
    }

    return apps.randomElement()
}

func classify(_ appName: String) -> AppKind {
    if browserNames.contains(appName) { return .browser }
    if feishuNames.contains(appName) { return .feishu }
    return .generic
}

func frontWindowBounds(for pid: pid_t) -> WindowBounds? {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }

    for item in windowList {
        guard
            let ownerPid = item[kCGWindowOwnerPID as String] as? pid_t,
            ownerPid == pid,
            let layer = item[kCGWindowLayer as String] as? Int,
            layer == 0,
            let bounds = item[kCGWindowBounds as String] as? [String: Any],
            let x = bounds["X"] as? CGFloat,
            let y = bounds["Y"] as? CGFloat,
            let width = bounds["Width"] as? CGFloat,
            let height = bounds["Height"] as? CGFloat,
            width > 220,
            height > 180
        else {
            continue
        }

        return WindowBounds(x: Int(x), y: Int(y), width: Int(width), height: Int(height))
    }

    return nil
}

func browseBrowser(_ window: WindowBounds) {
    let count = Int.random(in: 2...5)

    for _ in 0..<count {
        let x = window.x + Int.random(in: 90...max(110, window.width - 110))
        let y = window.y + Int.random(in: 14...58)
        safeClick(x: x, y: y)
        randomPause(0.4, 1.2)
        safeScroll(clicks: Int.random(in: -5...(-2)))
        randomPause(0.2, 0.8)
        safeScroll(clicks: Int.random(in: 2...5))
        randomPause(0.5, 1.3)
    }
}

func browseFeishu(_ window: WindowBounds) {
    let count = Int.random(in: 2...5)

    for _ in 0..<count {
        let x = window.x + Int.random(in: 18...72)
        let y = window.y + Int.random(in: 76...max(96, window.height - 96))
        safeClick(x: x, y: y)
        randomPause(0.8, 1.6)
        safeScroll(clicks: Int.random(in: -4...(-1)))
        randomPause(0.2, 0.7)
        safeScroll(clicks: Int.random(in: 1...4))
        randomPause(0.5, 1.2)
    }
}

func browseGenericApp(_ window: WindowBounds) {
    let count = Int.random(in: 2...4)

    for _ in 0..<count {
        let useLeftNav = Bool.random()
        let x: Int
        let y: Int

        if useLeftNav {
            x = window.x + Int.random(in: 18...min(160, max(19, window.width - 20)))
            y = window.y + Int.random(in: 78...max(96, window.height - 96))
        } else {
            x = window.x + Int.random(in: 90...max(110, window.width - 110))
            y = window.y + Int.random(in: 36...86)
        }

        safeClick(x: x, y: y)
        randomPause(0.6, 1.4)
        safeScroll(clicks: Int.random(in: -4...(-1)))
        randomPause(0.2, 0.7)
        safeScroll(clicks: Int.random(in: 1...4))
        randomPause(0.5, 1.2)
    }
}

func safeClick(x: Int, y: Int) {
    let point = CGPoint(x: x, y: y)
    guard
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    else {
        return
    }

    down.post(tap: .cghidEventTap)
    usleep(70_000)
    up.post(tap: .cghidEventTap)
}

func safeScroll(clicks: Int) {
    guard let event = CGEvent(
        scrollWheelEvent2Source: nil,
        units: .line,
        wheelCount: 1,
        wheel1: Int32(clicks),
        wheel2: 0,
        wheel3: 0
    ) else {
        return
    }

    event.post(tap: .cghidEventTap)
}

func randomPause(_ minSeconds: Double, _ maxSeconds: Double) {
    let seconds = Double.random(in: minSeconds...maxSeconds)
    usleep(useconds_t(seconds * 1_000_000))
}
