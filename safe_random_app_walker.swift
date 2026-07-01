import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

let runIntervalMinSeconds: UInt32 = 180
let runIntervalMaxSeconds: UInt32 = 300
let pausedCheckIntervalSeconds: UInt32 = 7_200
let chinaHolidayRanges: [(String, String, String)] = [
    ("元旦", "2026-01-01", "2026-01-03"),
    ("春节", "2026-02-16", "2026-02-23"),
    ("清明节", "2026-04-04", "2026-04-06"),
    ("劳动节", "2026-05-01", "2026-05-05"),
    ("端午节", "2026-06-19", "2026-06-21"),
    ("中秋节", "2026-09-25", "2026-09-27"),
    ("国庆节", "2026-10-01", "2026-10-07")
]

let browserNames: Set<String> = [
    "Safari",
    "Google Chrome",
    "Google Chrome Canary",
    "Microsoft Edge",
    "Microsoft Edge Canary",
    "Firefox",
    "Firefox Developer Edition",
    "Arc",
    "Brave Browser",
    "Opera",
    "ChatGPT Atlas",
    "浏览器"
]
let feishuNames: Set<String> = ["Feishu", "Lark", "飞书"]
let excelNames: Set<String> = ["Microsoft Excel", "Excel"]
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
    case excel
    case feishu
    case generic
}

let runOnce = CommandLine.arguments.contains("--once")
let dryRun = CommandLine.arguments.contains("--dry-run")
let atlasOnly = CommandLine.arguments.contains("--atlas-only")
let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

if dryRun {
    for app in runningTargetApps().shuffled() {
        let name = app.localizedName ?? "(unknown)"
        print("\(name): \(classify(name))")
    }
    exit(0)
}

if atlasOnly {
    if let atlas = runningTargetApps().first(where: { ($0.localizedName ?? "").localizedCaseInsensitiveContains("Atlas") }) {
        operate(atlas)
    } else {
        logStatus("ChatGPT Atlas：没有发现已启动的 Atlas")
    }
    exit(0)
}

repeat {
    guard isAllowedWorkTime() else {
        logStatus("当前为暂停时间，下一次允许执行时间：\(formatter.string(from: nextAllowedStartDate()))；2小时后再次检查")
        if runOnce { break }
        sleep(pausedCheckIntervalSeconds)
        continue
    }

    logStatus("开始新一轮操作；正常运行间隔为 3-5 分钟")
    doOneRound()
    logStatus("本轮操作完成")
    if runOnce { break }
    sleep(UInt32.random(in: runIntervalMinSeconds...runIntervalMaxSeconds))
} while true

func doOneRound() {
    let apps = runningTargetApps().shuffled()
    logStatus("候选 App 数量：\(apps.count)")

    for app in apps {
        guard isAllowedWorkTime() else {
            logStatus("当前进入暂停时间，本轮提前停止；下一次允许执行时间：\(formatter.string(from: nextAllowedStartDate()))")
            return
        }

        operate(app)
        randomPause(0.8, 1.6)
    }
}

func isAllowedWorkTime(_ date: Date = Date()) -> Bool {
    if let holidayName = chinaHolidayName(on: date) {
        logStatus("当前为中国法定节假日/假期：\(holidayName)")
        return false
    }

    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date)
    if weekday == 1 || weekday == 7 {
        return false
    }

    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    let minutes = hour * 60 + minute

    return (minutes >= 9 * 60 && minutes < 12 * 60)
        || (minutes >= 14 * 60 && minutes < 19 * 60)
}

func nextAllowedStartDate(from date: Date = Date()) -> Date {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: date)
    let weekday = calendar.component(.weekday, from: date)
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    let minutes = hour * 60 + minute

    if weekday >= 2 && weekday <= 6 && chinaHolidayName(on: date) == nil {
        if minutes < 9 * 60 {
            return calendar.date(byAdding: .hour, value: 9, to: startOfToday) ?? date
        }

        if minutes >= 12 * 60 && minutes < 14 * 60 {
            return calendar.date(byAdding: .hour, value: 14, to: startOfToday) ?? date
        }
    }

    var candidate = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? date
    while true {
        let candidateWeekday = calendar.component(.weekday, from: candidate)
        if candidateWeekday >= 2 && candidateWeekday <= 6 && chinaHolidayName(on: candidate) == nil {
            return calendar.date(byAdding: .hour, value: 9, to: candidate) ?? candidate
        }
        candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
    }
}

func chinaHolidayName(on date: Date) -> String? {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: date)

    for holiday in chinaHolidayRanges {
        guard
            let start = localDate(holiday.1),
            let end = localDate(holiday.2),
            let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: end)
        else {
            continue
        }

        if day >= start && day < exclusiveEnd {
            return holiday.0
        }
    }

    return nil
}

func localDate(_ value: String) -> Date? {
    let parts = value.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }

    var components = DateComponents()
    components.calendar = Calendar.current
    components.timeZone = TimeZone.current
    components.year = parts[0]
    components.month = parts[1]
    components.day = parts[2]
    return components.date
}

func operate(_ app: NSRunningApplication) {
    guard let name = app.localizedName else { return }
    logStatus("切换到 \(name)，类型：\(classify(name))")
    app.activate(options: [.activateAllWindows])
    randomPause(0.8, 1.6)

    if classify(name) == .excel {
        browseExcel(name)
        return
    }

    let hadWindow = frontWindowBounds(for: app.processIdentifier) != nil
    guard let window = frontWindowBounds(for: app.processIdentifier) ?? openWindowAndRefetch(for: app) else {
        logStatus("跳过 \(name)：没有找到可操作窗口")
        return
    }

    switch classify(name) {
    case .browser:
        browseBrowser(name, app.processIdentifier, window)
    case .excel:
        browseExcel(name)
    case .feishu:
        browseFeishu(window)
    case .generic:
        browseGenericApp(window)
    }

    if !hadWindow {
        closeTransientWindow(appName: name)
    }
}

func runningTargetApps() -> [NSRunningApplication] {
    NSWorkspace.shared.runningApplications.filter { app in
        guard app.activationPolicy == .regular, let name = app.localizedName else { return false }
        return !deniedNames.contains(name) && !app.isHidden
    }
}

func classify(_ appName: String) -> AppKind {
    if appName.localizedCaseInsensitiveContains("Atlas") { return .browser }
    if browserNames.contains(appName) { return .browser }
    if excelNames.contains(appName) { return .excel }
    if feishuNames.contains(appName) { return .feishu }
    return .generic
}

func openWindowAndRefetch(for app: NSRunningApplication) -> WindowBounds? {
    guard let name = app.localizedName else { return nil }
    logStatus("\(name)：没有窗口，尝试打开一个新窗口")
    app.activate(options: [.activateAllWindows])
    randomPause(0.8, 1.4)
    pressKey(keyCode: 45, flags: [.maskCommand])
    randomPause(1.2, 2.0)
    return frontWindowBounds(for: app.processIdentifier)
}

func closeTransientWindow(appName: String) {
    logStatus("\(appName)：关闭本轮临时打开的窗口")
    pressKey(keyCode: 13, flags: [.maskCommand])
    randomPause(0.5, 1.0)
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

func browseBrowser(_ appName: String, _ pid: pid_t, _ window: WindowBounds) {
    logStatus("浏览器：开始遍历标签页并滚动")

    if appName.localizedCaseInsensitiveContains("Atlas"), browseAtlasTabsByKeyboard(appName, window: window) {
        return
    }

    if browseScriptableBrowserTabs(appName) {
        return
    }

    if appName.localizedCaseInsensitiveContains("Atlas") {
        logStatus("ChatGPT Atlas：无法可靠识别标签页，跳过 Atlas，避免在同一标签页重复滚动")
        return
    }

    logStatus("浏览器：当前浏览器不支持逐标签脚本接口，退回到可见标签和快捷键方式")

    let visibleTabSlots = max(4, min(16, window.width / 120))
    browseVisibleBrowserTabs(window, slotCount: visibleTabSlots)

    for tabNumber in 1...9 {
        logStatus("浏览器：使用快捷键切换到标签 \(tabNumber) 并滚动")
        switchToBrowserTab(tabNumber)
        randomPause(0.4, 1.0)
        scrollToEndAndBack()
        randomPause(0.4, 1.0)
    }

    let cycleCount = Int.random(in: 3...6)
    for index in 0..<cycleCount {
        logStatus("浏览器：继续切换下一个标签并滚动（\(index + 1)/\(cycleCount)）")
        pressKey(keyCode: 48, flags: [.maskControl])
        randomPause(0.4, 1.0)
        scrollToEndAndBack()
    }
}

func browseVisibleBrowserTabs(_ window: WindowBounds, slotCount: Int) {
    let count = max(1, slotCount)
    for index in 0..<count {
        let x = window.x + 90 + ((max(120, window.width - 180) * index) / max(1, count - 1))
        let y = window.y + Int.random(in: 14...58)
        logStatus("浏览器：点击第 \(index + 1) 个可见标签位置并滚动")
        safeClick(x: x, y: y)
        randomPause(0.4, 1.2)
        scrollToEndAndBack()
        randomPause(0.5, 1.3)
    }
}

func browseAtlasTabsByKeyboard(_ appName: String, window: WindowBounds) -> Bool {
    logStatus("ChatGPT Atlas：开始读取当前窗口实际标签页数量")
    let count = browserFrontWindowTabCount(appName)
    guard count > 0 else {
        logStatus("ChatGPT Atlas：无法读取当前窗口标签数量，无法安全遍历")
        return false
    }

    logStatus("ChatGPT Atlas：当前窗口读取到 \(count) 个标签页，使用键盘逐个切换并滚动")
    for index in 0..<count {
        logStatus("ChatGPT Atlas：滚动当前标签页 \(index + 1)/\(count)")
        moveMouseToScrollableContent(window)
        randomPause(0.2, 0.5)
        scrollToEndAndBack()
        randomPause(0.4, 0.9)

        if index < count - 1 {
            logStatus("ChatGPT Atlas：切换到下一个标签页")
            switchToNextBrowserTab()
            randomPause(0.8, 1.3)
        }
    }

    return true
}

func browseAtlasTabsByAccessibility(pid: pid_t, window: WindowBounds) -> Bool {
    guard AXIsProcessTrusted() else {
        logStatus("ChatGPT Atlas：缺少辅助功能权限，无法准确读取标签页控件")
        return false
    }

    let appElement = AXUIElementCreateApplication(pid)
    guard let appWindow = focusedAXWindow(appElement) else {
        logStatus("ChatGPT Atlas：辅助功能未找到当前窗口")
        return false
    }

    let candidates = atlasTabCandidates(in: appWindow, window: window)
    guard !candidates.isEmpty else {
        logStatus("ChatGPT Atlas：辅助功能未找到顶部标签页控件")
        return false
    }

    logStatus("ChatGPT Atlas：辅助功能发现 \(candidates.count) 个当前窗口标签页，逐个点击并滚动")
    for (index, candidate) in candidates.enumerated() {
        let title = candidate.title.isEmpty ? "未命名" : candidate.title
        logStatus("ChatGPT Atlas：进入标签页 \(index + 1)/\(candidates.count)：\(title)")

        let result = AXUIElementPerformAction(candidate.element, kAXPressAction as CFString)
        if result != .success {
            let x = Int(candidate.frame.midX)
            let y = Int(candidate.frame.midY)
            logStatus("ChatGPT Atlas：AXPress 失败，改用坐标点击标签页 \(index + 1)")
            safeClick(x: x, y: y)
        }

        randomPause(0.5, 1.2)
        scrollToEndAndBack()
        randomPause(0.4, 1.0)
    }

    return true
}

struct AtlasTabCandidate {
    let element: AXUIElement
    let frame: CGRect
    let title: String
}

func focusedAXWindow(_ appElement: AXUIElement) -> AXUIElement? {
    if let focused: AXUIElement = axValue(appElement, kAXFocusedWindowAttribute) {
        return focused
    }

    if let windows: [AXUIElement] = axValue(appElement, kAXWindowsAttribute) {
        return windows.first
    }

    return nil
}

func atlasTabCandidates(in root: AXUIElement, window: WindowBounds) -> [AtlasTabCandidate] {
    var results: [AtlasTabCandidate] = []
    collectAtlasTabCandidates(from: root, window: window, results: &results, depth: 0)

    var seen = Set<String>()
    return results
        .filter { candidate in
            let key = "\(Int(candidate.frame.minX)):\(Int(candidate.frame.minY)):\(Int(candidate.frame.width)):\(Int(candidate.frame.height))"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        .sorted { $0.frame.minX < $1.frame.minX }
}

func collectAtlasTabCandidates(from element: AXUIElement, window: WindowBounds, results: inout [AtlasTabCandidate], depth: Int) {
    if depth > 10 { return }

    if let frame = axFrame(element), isLikelyAtlasTabFrame(frame, window: window) {
        let role: String = axValue(element, kAXRoleAttribute) ?? ""
        let title: String = axValue(element, kAXTitleAttribute) ?? axValue(element, kAXDescriptionAttribute) ?? ""

        if isLikelyAtlasTabRole(role), !isAtlasChromeControl(title) {
            results.append(AtlasTabCandidate(element: element, frame: frame, title: title))
        }
    }

    guard let children: [AXUIElement] = axValue(element, kAXChildrenAttribute) else { return }
    for child in children {
        collectAtlasTabCandidates(from: child, window: window, results: &results, depth: depth + 1)
    }
}

func isLikelyAtlasTabFrame(_ frame: CGRect, window: WindowBounds) -> Bool {
    let top = CGFloat(window.y)
    let left = CGFloat(window.x)
    let right = CGFloat(window.x + window.width)
    let minY = frame.minY
    let midX = frame.midX

    return minY >= top
        && minY <= top + 80
        && midX >= left + 40
        && midX <= right - 25
        && frame.width >= 28
        && frame.width <= 260
        && frame.height >= 18
        && frame.height <= 55
}

func isLikelyAtlasTabRole(_ role: String) -> Bool {
    role == kAXButtonRole as String
        || role == kAXRadioButtonRole as String
        || role == kAXGroupRole as String
        || role == kAXStaticTextRole as String
}

func isAtlasChromeControl(_ title: String) -> Bool {
    let lower = title.lowercased()
    if lower.isEmpty { return false }
    return lower == "new tab"
        || lower == "close"
        || lower == "minimize"
        || lower == "zoom"
        || lower == "back"
        || lower == "forward"
        || lower == "reload"
        || lower == "search"
        || lower == "address and search bar"
        || lower.contains("关闭")
        || lower.contains("新标签")
}

func browseScriptableBrowserTabs(_ appName: String) -> Bool {
    logStatus("浏览器：开始读取当前窗口实际标签页数量")
    let tabRefs = browserTabRefs(appName)
    guard !tabRefs.isEmpty else { return false }

    logStatus("浏览器：当前窗口发现 \(tabRefs.count) 个真实标签页，逐个进入并滚动")
    for (index, tabRef) in tabRefs.enumerated() {
        logStatus("浏览器：进入真实标签页 \(index + 1)/\(tabRefs.count)")
        if activateBrowserTab(appName, windowIndex: tabRef.windowIndex, tabIndex: tabRef.tabIndex) {
            randomPause(0.5, 1.2)
            scrollToEndAndBack()
            randomPause(0.4, 1.0)
        } else {
            logStatus("浏览器：进入标签页失败，窗口 \(tabRef.windowIndex)，标签 \(tabRef.tabIndex)")
        }
    }

    return true
}

struct BrowserTabRef {
    let windowIndex: Int
    let tabIndex: Int
}

func browserTabRefs(_ appName: String) -> [BrowserTabRef] {
    let script = browserTabListScript(appName)
    let output = runAppleScript(script)
    return output
        .split(separator: "\n")
        .compactMap { line in
            let parts = line.split(separator: ":")
            guard parts.count == 2, let windowIndex = Int(parts[0]), let tabIndex = Int(parts[1]) else {
                return nil
            }
            return BrowserTabRef(windowIndex: windowIndex, tabIndex: tabIndex)
        }
}

func browserTabListScript(_ appName: String) -> String {
    let safeName = escapedAppleScriptString(appName)
    return """
    tell application "\(safeName)"
      set outputText to ""
      if (count of windows) is 0 then return outputText
      set index of window 1 to 1
      set tabCount to count of tabs of window 1
      repeat with ti from 1 to tabCount
        set outputText to outputText & 1 & ":" & ti & linefeed
      end repeat
      return outputText
    end tell
    """
}

func activateBrowserTab(_ appName: String, windowIndex: Int, tabIndex: Int) -> Bool {
    let safeName = escapedAppleScriptString(appName)
    let script: String

    if appName == "Safari" {
        script = """
        tell application "\(safeName)"
          activate
          set current tab of window \(windowIndex) to tab \(tabIndex) of window \(windowIndex)
          set index of window \(windowIndex) to 1
        end tell
        """
    } else {
        script = """
        tell application "\(safeName)"
          activate
          set active tab index of window \(windowIndex) to \(tabIndex)
          set index of window \(windowIndex) to 1
        end tell
        """
    }

    return !runAppleScript(script).hasPrefix("ERROR:")
}

func browseExcel(_ appName: String) {
    logStatus("Excel：准备访问所有 sheet")
    let workbookReadyScript = """
    tell application "\(escapedAppleScriptString(appName))"
      activate
      set createdWorkbook to false
      if (count of workbooks) is 0 then
        make new workbook
        set createdWorkbook to true
      end if
      return (count of worksheets of active workbook as text) & ":" & (createdWorkbook as text)
    end tell
    """

    let output = runAppleScript(workbookReadyScript).trimmingCharacters(in: .whitespacesAndNewlines)
    let outputParts = output.split(separator: ":")
    guard
        let firstPart = outputParts.first,
        let sheetCount = Int(firstPart),
        sheetCount > 0
    else {
        logStatus("Excel：没有找到可访问的 sheet，返回信息：\(output)")
        return
    }
    let createdWorkbook = outputParts.count > 1 && outputParts[1].lowercased() == "true"

    logStatus("Excel：发现 \(sheetCount) 个 sheet，逐个进入并滚动")
    for sheetIndex in 1...sheetCount {
        let switchScript = """
        tell application "\(escapedAppleScriptString(appName))"
          activate
          activate object worksheet \(sheetIndex) of active workbook
        end tell
        """
        logStatus("Excel：进入 sheet \(sheetIndex)/\(sheetCount)")
        _ = runAppleScript(switchScript)
        randomPause(0.5, 1.0)
        scrollToEndAndBack()
        randomPause(0.4, 0.9)
    }

    if createdWorkbook {
        logStatus("Excel：关闭本轮临时创建的 workbook，不保存")
        let closeScript = """
        tell application "\(escapedAppleScriptString(appName))"
          close active workbook saving no
        end tell
        """
        _ = runAppleScript(closeScript)
    }
}

func browseFeishu(_ window: WindowBounds) {
    logStatus("飞书：进入消息区域")
    let messageButtonX = window.x + Int.random(in: 18...72)
    let messageButtonY = window.y + Int.random(in: 76...130)
    safeClick(x: messageButtonX, y: messageButtonY)
    randomPause(1.0, 1.8)
    scrollToEndAndBack()

    let count = Int.random(in: 4...8)

    for _ in 0..<count {
        let useMessageList = Bool.random()
        let x: Int
        let y: Int

        if useMessageList {
            x = window.x + Int.random(in: 90...min(360, max(110, window.width - 120)))
            y = window.y + Int.random(in: 90...max(120, window.height - 180))
        } else {
            let contentStart = min(max(120, window.width / 3), max(121, window.width - 120))
            let contentEnd = max(contentStart, window.width - 90)
            x = window.x + Int.random(in: contentStart...contentEnd)
            y = window.y + Int.random(in: 120...max(150, window.height - 220))
        }

        logStatus("飞书：在消息区域点击并滚动")
        safeClick(x: x, y: y)
        randomPause(0.8, 1.6)
        scrollToEndAndBack()
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

        logStatus("通用 App：点击并滚动")
        safeClick(x: x, y: y)
        randomPause(0.6, 1.4)
        scrollToEndAndBack()
        randomPause(0.5, 1.2)
    }
}

func scrollToEndAndBack() {
    logStatus("滚动：向下长滚动后返回顶部")
    let downSteps = Int.random(in: 18...36)
    let upSteps = downSteps + Int.random(in: 6...18)

    repeatScroll(clicks: -8, times: downSteps)
    randomPause(0.4, 1.0)
    repeatScroll(clicks: 8, times: upSteps)
}

func repeatScroll(clicks: Int, times: Int) {
    for _ in 0..<times {
        safeScroll(clicks: clicks)
        usleep(35_000)
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

func moveMouseToScrollableContent(_ window: WindowBounds) {
    let x = window.x + window.width / 2
    let y = window.y + max(140, window.height / 2)
    let point = CGPoint(x: x, y: min(window.y + window.height - 80, y))

    guard let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else {
        return
    }

    logStatus("滚动：移动鼠标到网页内容区 \(Int(point.x)),\(Int(point.y))")
    move.post(tap: .cghidEventTap)
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

func switchToBrowserTab(_ tabNumber: Int) {
    let keyCodes: [Int: UInt16] = [
        1: 18,
        2: 19,
        3: 20,
        4: 21,
        5: 23,
        6: 22,
        7: 26,
        8: 28,
        9: 25
    ]

    guard let keyCode = keyCodes[tabNumber] else { return }
    pressKey(keyCode: keyCode, flags: [.maskCommand])
}

func switchToNextBrowserTab() {
    pressKey(keyCode: 48, flags: [.maskControl])
    randomPause(0.15, 0.3)
    pressKey(keyCode: 124, flags: [.maskCommand, .maskAlternate])
    randomPause(0.15, 0.3)
    pressKey(keyCode: 30, flags: [.maskCommand, .maskShift])
}

func pressKey(keyCode: UInt16, flags: CGEventFlags = []) {
    guard
        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    else {
        return
    }

    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    usleep(60_000)
    up.post(tap: .cghidEventTap)
}

func axValue<T>(_ element: AXUIElement, _ attribute: String) -> T? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success, let value else { return nil }
    return value as? T
}

func axFrame(_ element: AXUIElement) -> CGRect? {
    var positionValue: CFTypeRef?
    var sizeValue: CFTypeRef?

    guard
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
        let positionAXValue = positionValue,
        let sizeAXValue = sizeValue,
        CFGetTypeID(positionAXValue) == AXValueGetTypeID(),
        CFGetTypeID(sizeAXValue) == AXValueGetTypeID()
    else {
        return nil
    }

    var point = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(positionAXValue as! AXValue, .cgPoint, &point)
    AXValueGetValue(sizeAXValue as! AXValue, .cgSize, &size)

    return CGRect(origin: point, size: size)
}

func runAppleScript(_ script: String) -> String {
    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return "ERROR: \(error.localizedDescription)"
    }

    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    if process.terminationStatus != 0 {
        return "ERROR: \(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    return output
}

func browserFrontWindowTabCount(_ appName: String) -> Int {
    let safeName = escapedAppleScriptString(appName)
    let script = """
    tell application "\(safeName)"
      if (count of windows) is 0 then return "0"
      set index of window 1 to 1
      return count of tabs of window 1
    end tell
    """

    let output = runAppleScript(script).trimmingCharacters(in: .whitespacesAndNewlines)
    if output.hasPrefix("ERROR:") {
        logStatus("ChatGPT Atlas：读取标签数量失败：\(output)")
        return 0
    }

    return Int(output) ?? 0
}

func escapedAppleScriptString(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

func randomPause(_ minSeconds: Double, _ maxSeconds: Double) {
    let seconds = Double.random(in: minSeconds...maxSeconds)
    usleep(useconds_t(seconds * 1_000_000))
}

func logStatus(_ message: String) {
    print("[\(formatter.string(from: Date()))] \(message)")
    fflush(stdout)
}
