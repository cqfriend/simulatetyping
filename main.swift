import Cocoa
import Carbon
import Dispatch
import Foundation
import QuartzCore

// 移除OSLog改用基础打印语句以便调试
func logDebug(_ message: String) {
    // 移除所有debug输出
}

// 检查辅助功能权限
func checkAccessibilityPermission() -> Bool {
    // 使用系统自动权限请求
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    if !isTrusted {
        return false
    } else {
        return true
    }
}

// 检查并恢复权限状态
func checkAndRestorePermissions() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
    let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    if !isTrusted {
        if let eventTap = globalEventTap, CFMachPortIsValid(eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        } else {
            DispatchQueue.main.async {
                requestAccessibilityPermission()
            }
        }
    }
}

// 检查互斥锁 - 确保只有一个进程实例
func checkMutex() -> Bool {
    let tempDir = FileManager.default.temporaryDirectory
    let mutexPath = tempDir.appendingPathComponent("paste2typing.lock")
    
    do {
        // 尝试创建锁文件
        try "".write(to: mutexPath, atomically: true, encoding: .utf8)
        mutexFile = try FileHandle(forWritingTo: mutexPath)
        isFirstInstance = true
        return true
    } catch {
        // 锁文件已存在，说明另一个实例正在运行
        let alert = NSAlert()
        alert.messageText = "应用程序已在运行"
        alert.informativeText = "Paste2Typing 已经在运行中，请关闭现有实例后再启动。"
        alert.addButton(withTitle: "确定")
        alert.runModal()
        return false
    }
}

// 释放互斥锁
func releaseMutex() {
    if let file = mutexFile {
        try? file.close()
        mutexFile = nil
    }
    
    let tempDir = FileManager.default.temporaryDirectory
    let mutexPath = tempDir.appendingPathComponent("paste2typing.lock")
    try? FileManager.default.removeItem(at: mutexPath)
}

// 检测按键绑定冲突
func checkKeyBindingConflicts() -> [String] {
    var conflicts: [String] = []
    
    // 检查F10和F12是否被系统或其他应用占用
    let _ = getKeyName(for: customPasteKeyCode)
    let _ = getKeyName(for: customStopKeyCode)
    
    // 这里可以添加更复杂的冲突检测逻辑
    // 目前只是简单的提示
    if customPasteKeyCode == customStopKeyCode {
        conflicts.append("开始和停止按键不能相同")
    }
    
    return conflicts
}

// 获取按键名称
func getKeyName(for keyCode: CGKeyCode) -> String {
    switch keyCode {
    case CGKeyCode(kVK_F1): return "F1"
    case CGKeyCode(kVK_F2): return "F2"
    case CGKeyCode(kVK_F3): return "F3"
    case CGKeyCode(kVK_F4): return "F4"
    case CGKeyCode(kVK_F5): return "F5"
    case CGKeyCode(kVK_F6): return "F6"
    case CGKeyCode(kVK_F7): return "F7"
    case CGKeyCode(kVK_F8): return "F8"
    case CGKeyCode(kVK_F9): return "F9"
    case CGKeyCode(kVK_F10): return "F10"
    case CGKeyCode(kVK_F11): return "F11"
    case CGKeyCode(kVK_F12): return "F12"
    default: return "未知按键"
    }
}

// 请求辅助功能权限
func requestAccessibilityPermission() {
    // 直接打开系统偏好设置的辅助功能页面
    let script = """
    tell application "System Preferences"
        activate
        set current pane to pane id "com.apple.preference.security"
    end tell
    tell application "System Events"
        tell process "System Preferences"
            click button "Privacy" of tab group 1 of window 1
            click button "Accessibility" of row 1 of table 1 of scroll area 1 of tab group 1 of window 1
        end tell
    end tell
    """
    
    if let scriptObject = NSAppleScript(source: script) {
        scriptObject.executeAndReturnError(nil)
    }
}

// 全局变量
var shouldStopCurrentInput = false
var isTyping = false

// 互斥锁 - 确保只有一个进程实例
var mutexFile: FileHandle?
var isFirstInstance = false

// 可自定义的按键设置
var customPasteKeyCode: CGKeyCode = CGKeyCode(kVK_F10)
var customStopKeyCode: CGKeyCode = CGKeyCode(kVK_F12)
// 按键间隔时间设置（微秒）
var keyInterval: useconds_t = 100000  // 增加到100ms，让输入更明显
// 历史记录最大保存条数
var maxHistoryCount: Int = 100

// 键码映射表
let asciiToKeyCodeMap: [Character: UInt16] = [
    // Letters
    "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02,
    "e": 0x0E, "f": 0x03, "g": 0x05, "h": 0x04,
    "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25,
    "m": 0x2E, "n": 0x2D, "o": 0x1F, "p": 0x23,
    "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
    "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07,
    "y": 0x10, "z": 0x06,
    
    // Numbers
    "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
    "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C,
    "9": 0x19, "0": 0x1D,
    
    // Special Characters
    " ": 0x31, "-": 0x1B, "=": 0x18,
    "[": 0x21, "]": 0x1E, "\\": 0x2A,
    ";": 0x29, "'": 0x27, ",": 0x2B,
    ".": 0x2F, "/": 0x2C, "`": 0x32,
    
    // Tab and Enter
    "\t": 0x30, // Tab
    "\n": 0x24  // Enter (Return)
]

// 需要shift的特殊字符映射
let shiftedSpecialChars: [Character: UInt16] = [
    "!": 0x12, "@": 0x13, "#": 0x14, "$": 0x15,
    "%": 0x17, "^": 0x16, "&": 0x1A, "*": 0x1C,
    "(": 0x19, ")": 0x1D, "_": 0x1B, "+": 0x18,
    "{": 0x21, "}": 0x1E, "|": 0x2A, ":": 0x29,
    "\"": 0x27, "<": 0x2B, ">": 0x2F, "?": 0x2C,
    "~": 0x32
]

// 按键名称映射
let keyCodeToName: [UInt16: String] = [
    UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_D): "D", UInt16(kVK_ANSI_F): "F",
    UInt16(kVK_ANSI_H): "H", UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_Z): "Z", UInt16(kVK_ANSI_X): "X",
    UInt16(kVK_ANSI_C): "C", UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_B): "B", UInt16(kVK_ANSI_Q): "Q",
    UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_R): "R", UInt16(kVK_ANSI_Y): "Y",
    UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_1): "1", UInt16(kVK_ANSI_2): "2", UInt16(kVK_ANSI_3): "3",
    UInt16(kVK_ANSI_4): "4", UInt16(kVK_ANSI_6): "6", UInt16(kVK_ANSI_5): "5", UInt16(kVK_ANSI_Equal): "=",
    UInt16(kVK_ANSI_9): "9", UInt16(kVK_ANSI_7): "7", UInt16(kVK_ANSI_Minus): "-", UInt16(kVK_ANSI_8): "8",
    UInt16(kVK_ANSI_0): "0", UInt16(kVK_ANSI_RightBracket): "]", UInt16(kVK_ANSI_O): "O",
    UInt16(kVK_ANSI_U): "U", UInt16(kVK_ANSI_LeftBracket): "[", UInt16(kVK_ANSI_I): "I",
    UInt16(kVK_ANSI_P): "P", UInt16(kVK_Return): "Return", UInt16(kVK_ANSI_L): "L", UInt16(kVK_ANSI_J): "J",
    UInt16(kVK_ANSI_Quote): "'", UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_Semicolon): ";",
    UInt16(kVK_ANSI_Backslash): "\\", UInt16(kVK_ANSI_Comma): ",", UInt16(kVK_ANSI_Slash): "/",
    UInt16(kVK_ANSI_N): "N", UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_Period): ".", UInt16(kVK_Tab): "Tab",
    UInt16(kVK_Space): "Space", UInt16(kVK_ANSI_Grave): "`", UInt16(kVK_Delete): "Delete",
    UInt16(kVK_Escape): "Escape", UInt16(kVK_Command): "Command", UInt16(kVK_Shift): "Shift",
    UInt16(kVK_CapsLock): "CapsLock", UInt16(kVK_Option): "Option", UInt16(kVK_Control): "Control",
    UInt16(kVK_RightShift): "Right Shift", UInt16(kVK_RightOption): "Right Option",
    UInt16(kVK_RightControl): "Right Control", UInt16(kVK_Function): "Function",
    UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3", UInt16(kVK_F4): "F4",
    UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6", UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8",
    UInt16(kVK_F9): "F9", UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
    UInt16(kVK_F13): "F13", UInt16(kVK_F14): "F14", UInt16(kVK_F15): "F15", UInt16(kVK_F16): "F16",
    UInt16(kVK_F17): "F17", UInt16(kVK_F18): "F18", UInt16(kVK_F19): "F19", UInt16(kVK_F20): "F20",
    UInt16(kVK_Help): "Help", UInt16(kVK_Home): "Home", UInt16(kVK_PageUp): "Page Up",
    UInt16(kVK_PageDown): "Page Down", UInt16(kVK_End): "End",
    UInt16(kVK_ForwardDelete): "Forward Delete", UInt16(kVK_LeftArrow): "Left Arrow",
    UInt16(kVK_RightArrow): "Right Arrow", UInt16(kVK_DownArrow): "Down Arrow",
    UInt16(kVK_UpArrow): "Up Arrow",
    UInt16(kVK_ANSI_KeypadDecimal): "Keypad .", UInt16(kVK_ANSI_KeypadMultiply): "Keypad *",
    UInt16(kVK_ANSI_KeypadPlus): "Keypad +", UInt16(kVK_ANSI_KeypadClear): "Keypad Clear"
]

// 判断文本是否仅包含ASCII字符
func isAscii(text: String) -> Bool {
    return text.allSatisfy { $0.isASCII }
}

// 切换到英文输入法
func switchToEnglishInputSource() {
    // 添加超时机制，避免阻塞
    DispatchQueue.global().async {
        let englishSources = TISCreateInputSourceList([
            "TISPropertyInputSourceCategory" as CFString: "TISCategoryKeyboardInputSource" as CFString,
            "TISPropertyInputSourceType" as CFString: "TISTypeKeyboardLayout" as CFString
        ] as CFDictionary, false).takeRetainedValue() as! [TISInputSource]
        
        guard let abcKeyboard = englishSources.first(where: { source in
            guard let id = TISGetInputSourceProperty(source, "TISPropertyInputSourceID" as CFString) else { return false }
            let sourceID = Unmanaged<CFString>.fromOpaque(id).takeUnretainedValue() as String
            return sourceID == "com.apple.keylayout.ABC" || sourceID == "com.apple.inputmethod.SCIM.ITABC"
        }) else {
            return
        }
        
        TISSelectInputSource(abcKeyboard)
        usleep(100000)
    }
}

// 处理自定义停止按键事件
func handleCustomStopKeyPress() {
    if isTyping {
        shouldStopCurrentInput = true
        isTyping = false
    }
}

// 全局事件tap变量
var globalEventTap: CFMachPort?

// 改进的事件tap回调函数
let eventTapCallback: @convention(c) (CGEventTapProxy, CGEventType, CGEvent, UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? = { proxy, type, event, refcon in
    // 处理事件tap被禁用的情况
    if type == CGEventType.tapDisabledByTimeout || type == CGEventType.tapDisabledByUserInput {
        // 检查权限状态
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if isTrusted {
            // 权限已授予，重新启用事件tap
            if let eventTap = globalEventTap, CFMachPortIsValid(eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        } else {
            // 权限未授予，显示权限请求
            DispatchQueue.main.async {
                requestAccessibilityPermission()
            }
        }
        return nil
    }

    // 处理按键事件
    if type == CGEventType.keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == customPasteKeyCode {
            DispatchQueue.main.async {
                handleCustomPasteKeyPress()
            }
            return nil
        } else if keyCode == customStopKeyCode {
            handleCustomStopKeyPress()
            return nil
        }
    }

    return Unmanaged.passUnretained(event)
}

// 处理自定义按键事件
func handleCustomPasteKeyPress() {
    guard let clipboardContent = NSPasteboard.general.string(forType:.string) else {
        return
    }

    // 直接在主线程上执行，避免死锁
    DispatchQueue.main.async {
        // 延迟1秒给用户时间切换到目标应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let delegate = NSApplication.shared.delegate as? AppDelegate {
                delegate.simulateTyping(text: clipboardContent)
            }
        }
    }
}

// 监控自定义按键事件
func monitorKeyEvents() {
    // 检查权限状态
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    if !isTrusted {
        DispatchQueue.main.async {
            if let delegate = NSApplication.shared.delegate as? AppDelegate {
                delegate.statusLabel.stringValue = "需要辅助功能权限"
            }
        }
        return
    }

    // 创建事件tap
    globalEventTap = CGEvent.tapCreate(
        tap: CGEventTapLocation.cgSessionEventTap,
        place: CGEventTapPlacement.headInsertEventTap,
        options: CGEventTapOptions.defaultTap,
        eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
        callback: eventTapCallback,
        userInfo: nil
    )

    guard let unwrappedEventTap = globalEventTap else {
        DispatchQueue.main.async {
            if let delegate = NSApplication.shared.delegate as? AppDelegate {
                delegate.statusLabel.stringValue = "需要辅助功能权限"
            }
        }
        return
    }

    // 创建运行循环源
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, unwrappedEventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

    // 启用事件tap
    CGEvent.tapEnable(tap: unwrappedEventTap, enable: true)

    DispatchQueue.main.async {
        if let delegate = NSApplication.shared.delegate as? AppDelegate {
            delegate.updateStatusLabel()
        }
    }
    
    CFRunLoopRun()
}

// AppDelegate类定义
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var window: NSWindow!
    var textView: NSTextView!
    var statusLabel: NSTextField!
    var pasteButton: NSButton!
    var stopButton: NSButton!
    var pasteKeyPopUp: NSPopUpButton!
    var stopKeyPopUp: NSPopUpButton!
    var pasteKeyLabel: NSTextField!
    var stopKeyLabel: NSTextField!
    var scrollView: NSScrollView!
    var titleLabel: NSTextField!
    var subtitleLabel: NSTextField!
    var keyIntervalLabel: NSTextField!
    var keyIntervalSlider: NSSlider!
    var keyIntervalValueLabel: NSTextField!
    
    // 历史记录条数设置
    var historyCountLabel: NSTextField!
    var historyCountSlider: NSSlider!
    var historyCountValueLabel: NSTextField!
    var historyCountPopUp: NSPopUpButton!
    var helpScrollView: NSScrollView!
    var historyTitleLabel: NSTextField!
    var historyTableView: NSTableView!
    var historyScrollView: NSScrollView!
    var editButton: NSButton!
    var deleteButton: NSButton!
    var simulateInputButton: NSButton!
    var batchDeleteButton: NSButton!
    
    // 移除编辑对话框相关变量（不再需要）
    var clipboardHistory: [String] = []
    var maxHistoryCount = 100
    let clipboardHistoryKey = "ClipboardHistory"
    let maxHistoryCountKey = "MaxHistoryCount"
    var pasteboardMonitor: NSPasteboard?
    var clipboardTimer: Timer?
    var lastChangeCount: Int = 0
    var permissionCheckTimer: Timer?
    
    // 保存文本相关
    var savedTexts: [String] = []
    let savedTextsKey = "SavedTexts"
    
    // 文本操作按钮
    var saveTextButton: NSButton!
    var loadTextButton: NSButton!
    var clearTextButton: NSButton!
    
    // 新增属性用于布局约束
    var textInputLabel: NSTextField!
    // 移除 keySettingsLabel 声明
    var helpLabel: NSTextField!
    var mainContainer: NSView!
    var buttonContainer: NSView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 检查互斥锁
        if !checkMutex() {
            NSApp.terminate(nil)
            return
        }
        
        // 检查按键绑定冲突
        let conflicts = checkKeyBindingConflicts()
        if !conflicts.isEmpty {
            let alert = NSAlert()
            alert.messageText = "按键绑定冲突"
            alert.informativeText = "检测到以下冲突：\n" + conflicts.joined(separator: "\n")
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
        
        // 立即触发系统权限请求
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !isTrusted {
            requestAccessibilityPermission()
            // 延迟启动，给用户时间设置权限
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.continueInitialization()
            }
        } else {
            continueInitialization()
        }
    }
    
    @MainActor private func continueInitialization() {
        createWindow()
        createUIElements()
        setupLayout()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 延迟验证权限，给系统时间识别权限状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.verifyAndStartFeatures()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 释放互斥锁
        releaseMutex()
    }
    
    // 处理窗口关闭事件
    func windowWillClose(_ notification: Notification) {
        // 停止所有正在进行的操作
        shouldStopCurrentInput = true
        isTyping = false
        
        // 停止定时器
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        
        // 停止剪贴板监听
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        
        // 释放事件监听
        if let eventTap = globalEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            globalEventTap = nil
        }
        
        // 释放互斥锁
        releaseMutex()
        
        // 强制退出应用程序
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }
    
    // 处理应用程序终止
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    @MainActor private func verifyAndStartFeatures() {
        // 加载保存的设置
        loadKeyIntervalSettings()
        loadShortcutSettings()
        loadHistorySettings()
        loadClipboardHistory()
        
        // 更新UI显示
        updateKeyIntervalUI()
        
        // 再次检查权限，允许提示用户
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if isTrusted {
            // 启动剪贴板监听
            startClipboardMonitoring()
            
            // 启动按键监控
            DispatchQueue.global().async {
                monitorKeyEvents()
            }
            
            // 启动定期权限检查
            startPermissionCheckTimer()
        } else {
            statusLabel.stringValue = "需要辅助功能权限才能正常工作"
            
            let alert = NSAlert()
            alert.messageText = "权限未授予"
            alert.informativeText = "应用程序需要辅助功能权限才能正常工作。\n\n请重启应用程序并授予权限。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "知道了")
            alert.runModal()
        }
    }

    @MainActor private func createWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 900, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Paste2Typing - 智能粘贴输入工具(作者:无名氏)"
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        
        // 设置窗口最小尺寸
        window.minSize = NSSize(width: 800, height: 650)
        
        // 移除窗口背景效果，保持简洁
    }
    
    @MainActor private func createUIElements() {
        // 创建主容器视图 - 美化版本
        mainContainer = NSView()
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.wantsLayer = true
        
        // 创建渐变背景
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            NSColor.windowBackgroundColor.cgColor,
            NSColor.controlBackgroundColor.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        mainContainer.layer?.addSublayer(gradientLayer)
        
        // 设置圆角
        mainContainer.layer?.cornerRadius = 12
        mainContainer.layer?.masksToBounds = true
        
        window.contentView?.addSubview(mainContainer)
        
        // 标题区域 - 美化版本
        titleLabel = NSTextField()
        titleLabel.stringValue = "Paste2Typing"
        titleLabel.font = NSFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        
        // 创建标题渐变文字效果
        let titleGradient = CAGradientLayer()
        titleGradient.colors = [
            NSColor.systemBlue.cgColor,
            NSColor.systemPurple.cgColor
        ]
        titleGradient.startPoint = CGPoint(x: 0, y: 0)
        titleGradient.endPoint = CGPoint(x: 1, y: 0)
        titleLabel.layer?.addSublayer(titleGradient)
        titleLabel.layer?.masksToBounds = true
        
        titleLabel.textColor = NSColor.systemBlue
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(titleLabel)
        
        subtitleLabel = NSTextField()
        subtitleLabel.stringValue = "智能剪贴板内容自动输入工具"
        subtitleLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.isEditable = false
        subtitleLabel.isBordered = false
        subtitleLabel.backgroundColor = .clear
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(subtitleLabel)
        
        // 移除文本输入区域
        
        // 移除控制按钮区域
        
        // 移除快捷键设置标签
        
        pasteKeyLabel = NSTextField()
        pasteKeyLabel.stringValue = "粘贴快捷键："
        pasteKeyLabel.font = NSFont.systemFont(ofSize: 11)
        pasteKeyLabel.isEditable = false
        pasteKeyLabel.isBordered = false
        pasteKeyLabel.backgroundColor = .clear
        pasteKeyLabel.textColor = .secondaryLabelColor
        pasteKeyLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(pasteKeyLabel)
        
        pasteKeyPopUp = NSPopUpButton()
        pasteKeyPopUp.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化弹出菜单 - 移除背景和边框
        pasteKeyPopUp.wantsLayer = true
        pasteKeyPopUp.layer?.cornerRadius = 6
        pasteKeyPopUp.layer?.masksToBounds = true
        pasteKeyPopUp.layer?.backgroundColor = NSColor.clear.cgColor
        pasteKeyPopUp.layer?.borderWidth = 0
        
        mainContainer.addSubview(pasteKeyPopUp)
        
        stopKeyLabel = NSTextField()
        stopKeyLabel.stringValue = "停止快捷键："
        stopKeyLabel.font = NSFont.systemFont(ofSize: 11)
        stopKeyLabel.isEditable = false
        stopKeyLabel.isBordered = false
        stopKeyLabel.backgroundColor = .clear
        stopKeyLabel.textColor = .secondaryLabelColor
        stopKeyLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(stopKeyLabel)
        
        stopKeyPopUp = NSPopUpButton()
        stopKeyPopUp.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化停止按键弹出菜单 - 移除背景和边框
        stopKeyPopUp.wantsLayer = true
        stopKeyPopUp.layer?.cornerRadius = 6
        stopKeyPopUp.layer?.masksToBounds = true
        stopKeyPopUp.layer?.backgroundColor = NSColor.clear.cgColor
        stopKeyPopUp.layer?.borderWidth = 0
        
        mainContainer.addSubview(stopKeyPopUp)
        
        // 输入间隔设置
        keyIntervalLabel = NSTextField()
        keyIntervalLabel.stringValue = "输入间隔 (毫秒)："
        keyIntervalLabel.font = NSFont.systemFont(ofSize: 11)
        keyIntervalLabel.isEditable = false
        keyIntervalLabel.isBordered = false
        keyIntervalLabel.backgroundColor = .clear
        keyIntervalLabel.textColor = .secondaryLabelColor
        keyIntervalLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(keyIntervalLabel)
        
        keyIntervalSlider = NSSlider()
        keyIntervalSlider.minValue = 10
        keyIntervalSlider.maxValue = 100
        keyIntervalSlider.doubleValue = Double(keyInterval)
        keyIntervalSlider.target = self
        keyIntervalSlider.action = #selector(keyIntervalChanged)
        keyIntervalSlider.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化滑块样式
        keyIntervalSlider.wantsLayer = true
        keyIntervalSlider.layer?.cornerRadius = 4
        keyIntervalSlider.layer?.masksToBounds = true
        
        mainContainer.addSubview(keyIntervalSlider)
        
        keyIntervalValueLabel = NSTextField()
        keyIntervalValueLabel.stringValue = "\(keyInterval) 毫秒"
        keyIntervalValueLabel.font = NSFont.systemFont(ofSize: 11)
        keyIntervalValueLabel.isEditable = false
        keyIntervalValueLabel.isBordered = false
        keyIntervalValueLabel.backgroundColor = .clear
        keyIntervalValueLabel.textColor = .secondaryLabelColor
        keyIntervalValueLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(keyIntervalValueLabel)
        
        // 历史记录条数设置
        historyCountLabel = NSTextField()
        historyCountLabel.stringValue = "历史记录条数："
        historyCountLabel.font = NSFont.systemFont(ofSize: 11)
        historyCountLabel.isEditable = false
        historyCountLabel.isBordered = false
        historyCountLabel.backgroundColor = .clear
        historyCountLabel.textColor = .secondaryLabelColor
        historyCountLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(historyCountLabel)
        
        historyCountSlider = NSSlider()
        historyCountSlider.minValue = 1
        historyCountSlider.maxValue = 1000
        historyCountSlider.doubleValue = Double(maxHistoryCount)
        historyCountSlider.target = self
        historyCountSlider.action = #selector(historyCountChanged)
        historyCountSlider.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化滑块样式
        historyCountSlider.wantsLayer = true
        historyCountSlider.layer?.cornerRadius = 4
        historyCountSlider.layer?.masksToBounds = true
        
        mainContainer.addSubview(historyCountSlider)
        
        historyCountValueLabel = NSTextField()
        historyCountValueLabel.stringValue = "\(maxHistoryCount)"
        historyCountValueLabel.font = NSFont.systemFont(ofSize: 11)
        historyCountValueLabel.isEditable = false
        historyCountValueLabel.isBordered = false
        historyCountValueLabel.backgroundColor = .clear
        historyCountValueLabel.textColor = .secondaryLabelColor
        historyCountValueLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(historyCountValueLabel)
        
        // 历史记录条数PopUp设置
        historyCountPopUp = NSPopUpButton()
        historyCountPopUp.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化PopUp样式
        historyCountPopUp.wantsLayer = true
        historyCountPopUp.layer?.cornerRadius = 6
        historyCountPopUp.layer?.masksToBounds = true
        historyCountPopUp.layer?.backgroundColor = NSColor.clear.cgColor
        historyCountPopUp.layer?.borderWidth = 0
        
        // 添加常用条数选项
        let commonCounts = [10, 20, 50, 100, 200, 500, 1000]
        for count in commonCounts {
            historyCountPopUp.addItem(withTitle: "\(count)")
        }
        historyCountPopUp.selectItem(withTitle: "\(maxHistoryCount)")
        
        historyCountPopUp.target = self
        historyCountPopUp.action = #selector(historyCountPopUpChanged)
        
        mainContainer.addSubview(historyCountPopUp)
        
        // 状态显示 - 美化版本
        statusLabel = NSTextField()
        statusLabel.stringValue = "就绪：按下F10开始输入，F12停止"
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化状态标签
        statusLabel.wantsLayer = true
        statusLabel.layer?.cornerRadius = 4
        statusLabel.layer?.masksToBounds = true
        statusLabel.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.1).cgColor
        statusLabel.layer?.borderWidth = 1
        statusLabel.layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.3).cgColor
        
        mainContainer.addSubview(statusLabel)
        
        // 剪贴板历史区域 - 美化版本
        historyTitleLabel = NSTextField()
        historyTitleLabel.stringValue = "📋 剪贴板历史记录"
        historyTitleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        historyTitleLabel.isEditable = false
        historyTitleLabel.isBordered = false
        //historyTitleLabel.backgroundColor = .clear
        historyTitleLabel.textColor = NSColor.systemBlue
        historyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化历史标题标签
        historyTitleLabel.wantsLayer = true
        historyTitleLabel.layer?.cornerRadius = 4
        historyTitleLabel.layer?.masksToBounds = true
        //historyTitleLabel.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        //historyTitleLabel.layer?.borderWidth = 1
        //historyTitleLabel.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        
        mainContainer.addSubview(historyTitleLabel)
        
        historyTableView = NSTableView()
        historyTableView.headerView = nil
        historyTableView.rowHeight = 30
        historyTableView.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化表格视图
        historyTableView.wantsLayer = true
        historyTableView.layer?.cornerRadius = 8
        historyTableView.layer?.masksToBounds = true
        //historyTableView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        //historyTableView.layer?.borderWidth = 1
        //historyTableView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("HistoryColumn"))
        column.title = "历史记录"
        column.width = 300
        historyTableView.addTableColumn(column)
        historyTableView.dataSource = self
        historyTableView.delegate = self
        
        // 完全禁止右键菜单
        historyTableView.menu = nil
        historyTableView.allowsMultipleSelection = true  // 启用多选
        historyTableView.selectionHighlightStyle = .regular
        
        // 设置代理来拦截右键事件
        historyTableView.delegate = self
        
        // 禁用右键菜单的更强力方法
        historyTableView.target = self
        historyTableView.action = #selector(tableViewClicked)
        historyTableView.doubleAction = #selector(tableViewDoubleClicked)
        
        // 移除右键菜单，改用按钮
        
        historyScrollView = NSScrollView()
        historyScrollView.documentView = historyTableView
        historyScrollView.hasVerticalScroller = true
        historyScrollView.autohidesScrollers = true
        historyScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化滚动视图
        historyScrollView.wantsLayer = true
        historyScrollView.layer?.cornerRadius = 8
        historyScrollView.layer?.masksToBounds = true
        historyScrollView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        historyScrollView.layer?.borderWidth = 1
        historyScrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        mainContainer.addSubview(historyScrollView)
        
        // 添加编辑和删除按钮 - 美化版本
        editButton = NSButton()
        editButton.title = "✏️ 编辑"
        editButton.bezelStyle = .rounded
        editButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        editButton.target = self
        editButton.action = #selector(editSelectedHistoryItem)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化按钮样式
        editButton.wantsLayer = true
        editButton.layer?.cornerRadius = 6
        editButton.layer?.masksToBounds = true
        //editButton.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        //editButton.layer?.borderWidth = 1
        //editButton.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        
        mainContainer.addSubview(editButton)
        
        deleteButton = NSButton()
        deleteButton.title = "🗑️ 删除"
        deleteButton.bezelStyle = .rounded
        deleteButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        deleteButton.target = self
        deleteButton.action = #selector(deleteSelectedHistoryItem)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化删除按钮样式
        deleteButton.wantsLayer = true
        deleteButton.layer?.cornerRadius = 6
        deleteButton.layer?.masksToBounds = true
        //deleteButton.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.1).cgColor
        //deleteButton.layer?.borderWidth = 1
        //deleteButton.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.3).cgColor
        
        mainContainer.addSubview(deleteButton)
        
        // 添加模拟输入按钮 - 美化版本
        simulateInputButton = NSButton()
        simulateInputButton.title = "⌨️ 模拟输入"
        simulateInputButton.bezelStyle = .rounded
        simulateInputButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        simulateInputButton.target = self
        simulateInputButton.action = #selector(simulateInputSelectedItem)
        simulateInputButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化模拟输入按钮样式
        simulateInputButton.wantsLayer = true
        simulateInputButton.layer?.cornerRadius = 6
        simulateInputButton.layer?.masksToBounds = true
        //simulateInputButton.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.1).cgColor
        //simulateInputButton.layer?.borderWidth = 1
        //simulateInputButton.layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.3).cgColor
        
        mainContainer.addSubview(simulateInputButton)
        
        // 添加批量删除按钮 - 美化版本
        batchDeleteButton = NSButton()
        batchDeleteButton.title = "🗑️ 批量删除"
        batchDeleteButton.bezelStyle = .rounded
        batchDeleteButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        batchDeleteButton.target = self
        batchDeleteButton.action = #selector(batchDeleteSelectedItems)
        batchDeleteButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 美化批量删除按钮样式
        batchDeleteButton.wantsLayer = true
        batchDeleteButton.layer?.cornerRadius = 6
        batchDeleteButton.layer?.masksToBounds = true
        //batchDeleteButton.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.1).cgColor
        //batchDeleteButton.layer?.borderWidth = 1
        //batchDeleteButton.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.3).cgColor
        
        mainContainer.addSubview(batchDeleteButton)
        
        // 移除使用说明区域
        
        // 设置双击事件监听
        setupDoubleClickHandler()
        
        // 设置布局约束
        setupLayoutConstraints()
        
        // 加载保存的剪贴板历史记录
        loadClipboardHistory()
        historyTableView.reloadData()
        
        // 加载保存的快捷键设置
        loadShortcutSettings()
        
        // 加载保存的历史记录设置
        loadHistorySettings()
        
        // 更新UI显示加载的设置
        historyCountSlider.doubleValue = Double(maxHistoryCount)
        historyCountValueLabel.stringValue = "\(maxHistoryCount)"
        historyCountPopUp.selectItem(withTitle: "\(maxHistoryCount)")
        
        // 设置按键选择器 - 在加载设置后调用
        setupKeyPopUpButtons()
        
        // 更新渐变背景尺寸
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateGradientBackground()
        }
        
        // 监听窗口大小变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: window
        )
    }
    
    @MainActor private func setupDoubleClickHandler() {
        // 双击事件现在通过doubleAction直接处理，无需通知监听
    }

    @MainActor private func setupLayoutConstraints() {
        guard let contentView = window.contentView else { return }
        
        // 主容器约束
        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        // 标题区域约束
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor)
        ])
        
        // 移除文本输入区域和按钮区域约束
        
        // 重新布局 - 历史记录占据更多空间，底部留出空间给设置
        NSLayoutConstraint.activate([
            // 剪贴板历史记录 - 占据更多空间
            historyTitleLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            historyTitleLabel.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            historyTitleLabel.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor, constant: -20),
            
            historyScrollView.topAnchor.constraint(equalTo: historyTitleLabel.bottomAnchor, constant: 5),
            historyScrollView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            historyScrollView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor, constant: -20),
            historyScrollView.bottomAnchor.constraint(equalTo: editButton.topAnchor, constant: -10),
            
            // 编辑和删除按钮布局
            editButton.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            editButton.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor, constant: -120),
            editButton.widthAnchor.constraint(equalToConstant: 130),
            
            deleteButton.leadingAnchor.constraint(equalTo: editButton.trailingAnchor, constant: 10),
            deleteButton.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor, constant: -120),
            deleteButton.widthAnchor.constraint(equalToConstant: 130),
            
            // 模拟输入按钮布局
            simulateInputButton.leadingAnchor.constraint(equalTo: deleteButton.trailingAnchor, constant: 10),
            simulateInputButton.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor, constant: -120),
            simulateInputButton.widthAnchor.constraint(equalToConstant: 150),
            
            // 批量删除按钮布局
            batchDeleteButton.leadingAnchor.constraint(equalTo: simulateInputButton.trailingAnchor, constant: 10),
            batchDeleteButton.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor, constant: -120),
            batchDeleteButton.widthAnchor.constraint(equalToConstant: 130),
            
            // 历史记录条数设置 - 最底部
            historyCountLabel.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor, constant: -15),
            historyCountLabel.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: 20),
            historyCountLabel.widthAnchor.constraint(equalToConstant: 120),
            
            historyCountSlider.bottomAnchor.constraint(equalTo: historyCountLabel.bottomAnchor),
            historyCountSlider.leadingAnchor.constraint(equalTo: historyCountLabel.trailingAnchor, constant: 10),
            historyCountSlider.widthAnchor.constraint(equalToConstant: 150),
            
            historyCountValueLabel.bottomAnchor.constraint(equalTo: historyCountLabel.bottomAnchor),
            historyCountValueLabel.leadingAnchor.constraint(equalTo: historyCountSlider.trailingAnchor, constant: 10),
            historyCountValueLabel.widthAnchor.constraint(equalToConstant: 50),
            
            // 历史记录条数PopUp布局
            historyCountPopUp.bottomAnchor.constraint(equalTo: historyCountLabel.bottomAnchor),
            historyCountPopUp.leadingAnchor.constraint(equalTo: historyCountValueLabel.trailingAnchor, constant: 10),
            historyCountPopUp.widthAnchor.constraint(equalToConstant: 80),
            
            // 输入间隔设置 - 在历史记录条数设置上方
            keyIntervalLabel.bottomAnchor.constraint(equalTo: historyCountLabel.topAnchor, constant: -20),
            keyIntervalLabel.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: 20),
            keyIntervalLabel.widthAnchor.constraint(equalToConstant: 120),
            
            keyIntervalSlider.bottomAnchor.constraint(equalTo: keyIntervalLabel.bottomAnchor),
            keyIntervalSlider.leadingAnchor.constraint(equalTo: keyIntervalLabel.trailingAnchor, constant: 10),
            keyIntervalSlider.widthAnchor.constraint(equalToConstant: 150),
            
            keyIntervalValueLabel.bottomAnchor.constraint(equalTo: keyIntervalLabel.bottomAnchor),
            keyIntervalValueLabel.leadingAnchor.constraint(equalTo: keyIntervalSlider.trailingAnchor, constant: 10),
            keyIntervalValueLabel.widthAnchor.constraint(equalToConstant: 50),
            
            // 粘贴快捷键设置 - 左侧，与输入间隔对齐
            pasteKeyLabel.bottomAnchor.constraint(equalTo: keyIntervalLabel.topAnchor, constant: -20),
            pasteKeyLabel.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: 20),
            pasteKeyLabel.widthAnchor.constraint(equalToConstant: 120),
            
            pasteKeyPopUp.bottomAnchor.constraint(equalTo: pasteKeyLabel.bottomAnchor),
            pasteKeyPopUp.leadingAnchor.constraint(equalTo: pasteKeyLabel.trailingAnchor, constant: 10),
            pasteKeyPopUp.widthAnchor.constraint(equalToConstant: 100),
            
            // 停止快捷键设置 - 右侧，与左侧对齐
            stopKeyLabel.bottomAnchor.constraint(equalTo: keyIntervalLabel.topAnchor, constant: -20),
            stopKeyLabel.leadingAnchor.constraint(equalTo: pasteKeyPopUp.trailingAnchor, constant: 30),
            stopKeyLabel.widthAnchor.constraint(equalToConstant: 120),
            
            stopKeyPopUp.bottomAnchor.constraint(equalTo: stopKeyLabel.bottomAnchor),
            stopKeyPopUp.leadingAnchor.constraint(equalTo: stopKeyLabel.trailingAnchor, constant: 10),
            stopKeyPopUp.widthAnchor.constraint(equalToConstant: 100),
            
            // 状态显示 - 靠右下方，避免与快捷键设置重叠
            statusLabel.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor, constant: -10),
            statusLabel.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor, constant: -20),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: stopKeyPopUp.trailingAnchor, constant: 20)
        ])
    }

    @MainActor private func setupLayout() {
        // 布局已经在setupLayoutConstraints中设置
    }
    
    @MainActor private func setupKeyPopUpButtons() {
        let functionKeys = [
            (CGKeyCode(kVK_F1), "F1"), (CGKeyCode(kVK_F2), "F2"), (CGKeyCode(kVK_F3), "F3"), (CGKeyCode(kVK_F4), "F4"),
            (CGKeyCode(kVK_F5), "F5"), (CGKeyCode(kVK_F6), "F6"), (CGKeyCode(kVK_F7), "F7"), (CGKeyCode(kVK_F8), "F8"),
            (CGKeyCode(kVK_F9), "F9"), (CGKeyCode(kVK_F10), "F10"), (CGKeyCode(kVK_F11), "F11"), (CGKeyCode(kVK_F12), "F12"),
            (CGKeyCode(kVK_F13), "F13"), (CGKeyCode(kVK_F14), "F14"), (CGKeyCode(kVK_F15), "F15"), (CGKeyCode(kVK_F16), "F16"),
            (CGKeyCode(kVK_F17), "F17"), (CGKeyCode(kVK_F18), "F18"), (CGKeyCode(kVK_F19), "F19"), (CGKeyCode(kVK_F20), "F20")
        ]
        
        pasteKeyPopUp.removeAllItems()
        stopKeyPopUp.removeAllItems()
        
        for (keyCode, name) in functionKeys {
            pasteKeyPopUp.addItem(withTitle: name)
            stopKeyPopUp.addItem(withTitle: name)
            
            if keyCode == customPasteKeyCode {
                pasteKeyPopUp.selectItem(withTitle: name)
            }
            if keyCode == customStopKeyCode {
                stopKeyPopUp.selectItem(withTitle: name)
            }
        }
        
        pasteKeyPopUp.target = self
        pasteKeyPopUp.action = #selector(pasteKeyChanged)
        stopKeyPopUp.target = self
        stopKeyPopUp.action = #selector(stopKeyChanged)
    }
    
    @MainActor @objc private func pasteKeyChanged(_ sender: NSPopUpButton) {
        if let selectedTitle = sender.selectedItem?.title {
            for (keyCode, name) in [
                (CGKeyCode(kVK_F1), "F1"), (CGKeyCode(kVK_F2), "F2"), (CGKeyCode(kVK_F3), "F3"), (CGKeyCode(kVK_F4), "F4"),
                (CGKeyCode(kVK_F5), "F5"), (CGKeyCode(kVK_F6), "F6"), (CGKeyCode(kVK_F7), "F7"), (CGKeyCode(kVK_F8), "F8"),
                (CGKeyCode(kVK_F9), "F9"), (CGKeyCode(kVK_F10), "F10"), (CGKeyCode(kVK_F11), "F11"), (CGKeyCode(kVK_F12), "F12"),
                (CGKeyCode(kVK_F13), "F13"), (CGKeyCode(kVK_F14), "F14"), (CGKeyCode(kVK_F15), "F15"), (CGKeyCode(kVK_F16), "F16"),
                (CGKeyCode(kVK_F17), "F17"), (CGKeyCode(kVK_F18), "F18"), (CGKeyCode(kVK_F19), "F19"), (CGKeyCode(kVK_F20), "F20")
            ] {
                if name == selectedTitle {
                    customPasteKeyCode = keyCode
                    updateStatusLabel()
                    saveShortcutSettings() // 保存设置
                    break
                }
            }
        }
    }
    
    @MainActor @objc private func stopKeyChanged(_ sender: NSPopUpButton) {
        if let selectedTitle = sender.selectedItem?.title {
            for (keyCode, name) in [
                (CGKeyCode(kVK_F1), "F1"), (CGKeyCode(kVK_F2), "F2"), (CGKeyCode(kVK_F3), "F3"), (CGKeyCode(kVK_F4), "F4"),
                (CGKeyCode(kVK_F5), "F5"), (CGKeyCode(kVK_F6), "F6"), (CGKeyCode(kVK_F7), "F7"), (CGKeyCode(kVK_F8), "F8"),
                (CGKeyCode(kVK_F9), "F9"), (CGKeyCode(kVK_F10), "F10"), (CGKeyCode(kVK_F11), "F11"), (CGKeyCode(kVK_F12), "F12"),
                (CGKeyCode(kVK_F13), "F13"), (CGKeyCode(kVK_F14), "F14"), (CGKeyCode(kVK_F15), "F15"), (CGKeyCode(kVK_F16), "F16"),
                (CGKeyCode(kVK_F17), "F17"), (CGKeyCode(kVK_F18), "F18"), (CGKeyCode(kVK_F19), "F19"), (CGKeyCode(kVK_F20), "F20")
            ] {
                if name == selectedTitle {
                    customStopKeyCode = keyCode
                    updateStatusLabel()
                    saveShortcutSettings() // 保存设置
                    break
                }
            }
        }
    }
    
    @MainActor @objc private func keyIntervalChanged(_ sender: NSSlider) {
        keyInterval = useconds_t(sender.integerValue)
        keyIntervalValueLabel.stringValue = "\(keyInterval) 毫秒"
        saveKeyIntervalSettings()
    }
    
    // 保存输入间隔设置
    private func saveKeyIntervalSettings() {
        UserDefaults.standard.set(Int(keyInterval), forKey: "keyInterval")
        UserDefaults.standard.synchronize()
    }
    
    // 加载输入间隔设置
    private func loadKeyIntervalSettings() {
        let savedInterval = UserDefaults.standard.integer(forKey: "keyInterval")
        if savedInterval > 0 {
            keyInterval = useconds_t(savedInterval)
        }
    }
    
    // 更新输入间隔UI显示
    private func updateKeyIntervalUI() {
        keyIntervalSlider.doubleValue = Double(keyInterval)
        keyIntervalValueLabel.stringValue = "\(keyInterval) 毫秒"
    }
    
    @MainActor @objc private func historyCountChanged(_ sender: NSSlider) {
        maxHistoryCount = sender.integerValue
        historyCountValueLabel.stringValue = "\(maxHistoryCount)"
        
        // 同步PopUp选择
        historyCountPopUp.selectItem(withTitle: "\(maxHistoryCount)")
        
        // 如果当前历史记录超过新的限制，截取到限制数量
        if clipboardHistory.count > maxHistoryCount {
            clipboardHistory = Array(clipboardHistory.prefix(maxHistoryCount))
            saveClipboardHistory()
            historyTableView.reloadData()
        }
        
        // 保存设置
        saveHistorySettings()
    }
    
    @MainActor @objc private func historyCountPopUpChanged(_ sender: NSPopUpButton) {
        if let selectedTitle = sender.selectedItem?.title,
           let count = Int(selectedTitle) {
            maxHistoryCount = count
            historyCountSlider.doubleValue = Double(maxHistoryCount)
            historyCountValueLabel.stringValue = "\(maxHistoryCount)"
            
            // 如果当前历史记录超过新的限制，截取到限制数量
            if clipboardHistory.count > maxHistoryCount {
                clipboardHistory = Array(clipboardHistory.prefix(maxHistoryCount))
                saveClipboardHistory()
                historyTableView.reloadData()
            }
            
            // 保存设置
            saveHistorySettings()
        }
    }

    @MainActor func updateStatusLabel() {
        let pasteKeyName = keyCodeToName[customPasteKeyCode] ?? "F10"
        let stopKeyName = keyCodeToName[customStopKeyCode] ?? "F12"
        statusLabel.stringValue = "就绪: 按下\(pasteKeyName)粘贴，\(stopKeyName)停止，或使用按钮"
    }

    @MainActor @objc private func pasteButtonClicked(_ sender: Any) {
        logDebug("开始输入按钮被点击")
         usleep(1000000)

        let textToPaste = textView.string.isEmpty ? 
            (NSPasteboard.general.string(forType: .string) ?? "") : 
            textView.string
            
        logDebug("要输入的文本: \(textToPaste)")
        
        if textToPaste.isEmpty {
            logDebug("错误: 没有可输入的文本")
            statusLabel.stringValue = "错误: 没有可输入的文本"
            return
        }
        
        logDebug("开始输入过程")
        statusLabel.stringValue = "正在输入..."
        pasteButton.isEnabled = false
        stopButton.isEnabled = true

        DispatchQueue.main.async {
            let isAsciiText = isAscii(text: textToPaste)
            logDebug("文本类型: \(isAsciiText ? "ASCII" : "Unicode")")
            
            DispatchQueue.global().async {
                logDebug("在后台线程开始输入")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { 
                        logDebug("self已释放，停止输入")
                        return 
                    }
                    
                    logDebug("开始模拟输入")
                    usleep(1000000)
                    logDebug("调用simulateTyping")
                    self.simulateTyping(text: textToPaste)
                    logDebug("输入完成")
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.statusLabel.stringValue = "输入完成"
                    self.pasteButton.isEnabled = true
                    self.stopButton.isEnabled = false
                    logDebug("UI状态已更新")
                }
            }
        }
    }

    @MainActor @objc private func stopButtonClicked(_ sender: Any) {
        handleCustomStopKeyPress()
        statusLabel.stringValue = "输入已停止"
        pasteButton.isEnabled = true
        stopButton.isEnabled = false
    }
    
    @MainActor @objc private func saveTextButtonClicked(_ sender: Any) {
        saveTexts()
        statusLabel.stringValue = "文本已保存"
    }
    
    @MainActor @objc private func loadTextButtonClicked(_ sender: Any) {
        loadTexts()
        statusLabel.stringValue = "文本已加载"
    }
    
    @MainActor @objc private func clearTextButtonClicked(_ sender: Any) {
        textView.string = ""
        statusLabel.stringValue = "文本已清空"
    }
    
    @MainActor @objc private func textDidChange(_ notification: Notification) {
        // 自动保存文本变化
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.saveTexts()
        }
    }

    // 剪贴板监听
    private func startClipboardMonitoring() {
        pasteboardMonitor = NSPasteboard.general
        lastChangeCount = pasteboardMonitor?.changeCount ?? 0

        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let pasteboard = NSPasteboard.general
                if pasteboard.changeCount != self.lastChangeCount {
                    self.lastChangeCount = pasteboard.changeCount
                    self.updateClipboardHistory()
                }
            }
        }
    }
    
    // 启动定期权限检查
    private func startPermissionCheckTimer() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            DispatchQueue.global().async {
                checkAndRestorePermissions()
            }
        }
    }
    
    // 保存文本到UserDefaults
    private func saveTexts() {
        let texts = textView.string.components(separatedBy: "\n---\n")
        UserDefaults.standard.set(texts, forKey: savedTextsKey)
    }
    
    // 从UserDefaults加载文本
    private func loadTexts() {
        let defaultText = "在此输入要自动输入的内容...\n\n支持多行文本，使用 '---' 分隔不同内容"
        
        if let texts = UserDefaults.standard.stringArray(forKey: savedTextsKey) {
            savedTexts = texts
            if !texts.isEmpty {
                textView.string = texts.joined(separator: "\n---\n")
            } else {
                textView.string = defaultText
            }
        } else {
            textView.string = defaultText
        }
    }
    
    // 添加新文本
    private func addNewText() {
        let currentText = textView.string
        if !currentText.isEmpty {
            let newText = currentText + "\n---\n"
            textView.string = newText
            saveTexts()
        }
    }

    // 更新历史记录
    @MainActor private func updateClipboardHistory() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string),
              !clipboardText.isEmpty,
              !clipboardHistory.contains(clipboardText) else { return }

        clipboardHistory.insert(clipboardText, at: 0)
        if clipboardHistory.count > maxHistoryCount {
            clipboardHistory.removeLast()
        }
        
        // 保存历史记录
        saveClipboardHistory()
        
        historyTableView.reloadData()
    }

    // 实现NSTableViewDataSource协议方法
    func numberOfRows(in tableView: NSTableView) -> Int {
        return clipboardHistory.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("HistoryCell")
        if let cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            // 显示截断的文字 - 使用动态长度
            let originalText = clipboardHistory[row]
            let truncatedText = truncateText(originalText, maxLength: 100) // 增加默认最大长度
            cellView.textField?.stringValue = truncatedText
            return cellView
        }

        let cellView = NSTableCellView()
        cellView.identifier = cellIdentifier
        let originalText = clipboardHistory[row]
        let truncatedText = truncateText(originalText, maxLength: 100) // 增加默认最大长度
        let textField = NSTextField(string: truncatedText)
        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.lineBreakMode = .byTruncatingMiddle
        textField.preferredMaxLayoutWidth = 300
        textField.translatesAutoresizingMaskIntoConstraints = false
        cellView.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        cellView.textField = textField
        return cellView
    }

    // 双击事件处理 - 直接模拟输入
    @MainActor @objc func tableViewDoubleClicked(_ sender: Any) {
        let selectedRow = historyTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < clipboardHistory.count else { 
            let alert = NSAlert()
            alert.messageText = "提示"
            alert.informativeText = "请先选择一个历史记录项"
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return 
        }
        
        let selectedText = clipboardHistory[selectedRow]
        simulateTyping(text: selectedText)
    }
    
    // 编辑选中项按钮
    @MainActor @objc func editSelectedHistoryItem(_ sender: Any) {
        let selectedRow = historyTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < clipboardHistory.count else { 
            let alert = NSAlert()
            alert.messageText = "提示"
            alert.informativeText = "请先选择一个历史记录项"
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return 
        }
        
        // 使用简单的输入对话框
        let inputDialog = NSAlert()
        inputDialog.messageText = "编辑历史记录"
        inputDialog.informativeText = "请输入新的内容："
        inputDialog.addButton(withTitle: "确定")
        inputDialog.addButton(withTitle: "取消")
        
        // 创建文本框 - 显示完整内容
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 500, height: 100))
        textField.stringValue = clipboardHistory[selectedRow]  // 显示完整内容
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBordered = true
        textField.backgroundColor = NSColor.textBackgroundColor
        textField.textColor = NSColor.textColor
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.maximumNumberOfLines = 0  // 允许多行显示
        textField.lineBreakMode = .byWordWrapping  // 自动换行
        
        // 设置为accessoryView
        inputDialog.accessoryView = textField
        
        // 显示对话框
        let response = inputDialog.runModal()
        
        // 处理结果
        if response == .alertFirstButtonReturn {
            let newValue = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newValue.isEmpty {
                clipboardHistory[selectedRow] = newValue
                saveClipboardHistory()
                historyTableView.reloadData()
            }
        }
    }
    
    // 删除选中项按钮
    @MainActor @objc func deleteSelectedHistoryItem(_ sender: Any) {
        let selectedRow = historyTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < clipboardHistory.count else { 
            let alert = NSAlert()
            alert.messageText = "提示"
            alert.informativeText = "请先选择一个历史记录项"
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return 
        }
        
        let alert = NSAlert()
        alert.messageText = "确认删除"
        alert.informativeText = "确定要删除选中的历史记录项吗？"
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            clipboardHistory.remove(at: selectedRow)
            saveClipboardHistory()
            historyTableView.reloadData()
        }
    }
    
    // 批量删除选中项按钮
    @MainActor @objc func batchDeleteSelectedItems(_ sender: Any) {
        let selectedRows = historyTableView.selectedRowIndexes
        guard !selectedRows.isEmpty else { 
            let alert = NSAlert()
            alert.messageText = "提示"
            alert.informativeText = "请先选择要删除的历史记录项"
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return 
        }
        
        let alert = NSAlert()
        alert.messageText = "确认批量删除"
        alert.informativeText = "确定要删除选中的 \(selectedRows.count) 个历史记录项吗？"
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 按索引从大到小删除，避免索引变化
            let sortedRows = selectedRows.sorted(by: >)
            for row in sortedRows {
                if row < clipboardHistory.count {
                    clipboardHistory.remove(at: row)
                }
            }
            saveClipboardHistory()
            historyTableView.reloadData()
        }
    }
    
    // 拦截右键事件，防止显示系统菜单
    func tableView(_ tableView: NSTableView, shouldShowMenuForRow row: Int) -> Bool {
        return false
    }
    
    // 处理表格点击事件，防止右键菜单
    @objc func tableViewClicked(_ sender: Any) {
        // 空方法，仅用于拦截右键事件
    }
    
    // 更新渐变背景尺寸
    @MainActor private func updateGradientBackground() {
        if let gradientLayer = mainContainer.layer?.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = mainContainer.bounds
        }
    }
    
    // 窗口大小变化处理
    @MainActor @objc func windowDidResize(_ notification: Notification) {
        // 更新渐变背景
        updateGradientBackground()
        
        // 重新加载表格数据以更新文字截断
        historyTableView.reloadData()
    }
    
    // 文字截断函数 - 根据窗口大小动态调整
    private func truncateText(_ text: String, maxLength: Int) -> String {
        // 根据窗口宽度动态计算最大长度
        let windowWidth = window.frame.width
        let dynamicMaxLength = Int(windowWidth / 8) // 每8像素显示一个字符
        
        let effectiveMaxLength = min(maxLength, dynamicMaxLength)
        
        if text.count <= effectiveMaxLength {
            return text
        }
        
        // 如果包含换行符，只显示第一行
        if text.contains("\n") {
            let firstLine = text.components(separatedBy: "\n").first ?? ""
            if firstLine.count <= effectiveMaxLength {
                return firstLine + "..."
            } else {
                return String(firstLine.prefix(effectiveMaxLength - 3)) + "..."
            }
        }
        
        // 普通文本截断
        return String(text.prefix(effectiveMaxLength - 3)) + "..."
    }
    
    // 保存剪贴板历史记录
    private func saveClipboardHistory() {
        UserDefaults.standard.set(clipboardHistory, forKey: clipboardHistoryKey)
    }
    
    // 加载剪贴板历史记录
    private func loadClipboardHistory() {
        if let savedHistory = UserDefaults.standard.stringArray(forKey: clipboardHistoryKey) {
            clipboardHistory = savedHistory
        }
    }
    
    // 保存快捷键设置
    private func saveShortcutSettings() {
        UserDefaults.standard.set(Int(customPasteKeyCode), forKey: "PasteKeyCode")
        UserDefaults.standard.set(Int(customStopKeyCode), forKey: "StopKeyCode")
    }
    
    // 加载快捷键设置
    private func loadShortcutSettings() {
        let savedPasteKeyCode = UserDefaults.standard.integer(forKey: "PasteKeyCode")
        let savedStopKeyCode = UserDefaults.standard.integer(forKey: "StopKeyCode")
        
        // 如果保存的值有效，则使用保存的值
        if savedPasteKeyCode > 0 {
            customPasteKeyCode = CGKeyCode(savedPasteKeyCode)
        }
        if savedStopKeyCode > 0 {
            customStopKeyCode = CGKeyCode(savedStopKeyCode)
        }
    }
    
    // 保存历史记录设置
    private func saveHistorySettings() {
        UserDefaults.standard.set(maxHistoryCount, forKey: maxHistoryCountKey)
    }
    
    // 加载历史记录设置
    private func loadHistorySettings() {
        let savedMaxCount = UserDefaults.standard.integer(forKey: maxHistoryCountKey)
        if savedMaxCount > 0 {
            maxHistoryCount = savedMaxCount
        }
    }
    
    // 移除编辑对话框方法（不再需要）
    
    // 模拟输入选中项按钮
    @MainActor @objc func simulateInputSelectedItem(_ sender: Any) {
        usleep(1000000)
        let selectedRow = historyTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < clipboardHistory.count else { 
            let alert = NSAlert()
            alert.messageText = "提示"
            alert.informativeText = "请先选择一个历史记录项"
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return 
        }
        
        let selectedText = clipboardHistory[selectedRow]
        simulateTyping(text: selectedText)
    }

    // 模拟输入 - 遍历每个字符，智能选择输入方法
    func simulateTyping(text: String) {
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                // 将文本中的所有换行符统一为\n
                let normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
                
                // 初始化输入状态
                shouldStopCurrentInput = false
                isTyping = true
                
                // 确保目标应用获得焦点
                usleep(100000) // 短暂等待
                
                // 遍历每个字符，根据字符类型选择输入方法
                for character in normalizedText {
                    if shouldStopCurrentInput {
                        break
                    }
                    
                    if character.isASCII {
                        // ASCII字符使用ASCII方法输入
                        self.simulateAsciiCharacter(character)
                    } else {
                        // Unicode字符使用Unicode方法输入
                        self.simulateUnicodeCharacter(character)
                    }
                    
                    usleep(keyInterval)
                }
                
                isTyping = false
            }
        }
    }

    // ASCII字符输入函数 - 处理单个ASCII字符
    @MainActor func simulateAsciiCharacter(_ character: Character) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return
        }
        
        var keyCode: CGKeyCode?
        var needsShift = false
        
        // 特殊处理换行符
        if character == "\n" {
            keyCode = CGKeyCode(kVK_Return)
            needsShift = false
        } else if character.isUppercase {
            if let code = asciiToKeyCodeMap[Character(String(character).lowercased())] {
                keyCode = code
                needsShift = true
            }
        } else if let code = shiftedSpecialChars[character] {
            keyCode = code
            needsShift = true
        } else {
            keyCode = asciiToKeyCodeMap[character]
        }
        
        guard let finalKeyCode = keyCode else {
            return
        }
        
        let shiftKeyCode = CGKeyCode(kVK_Shift)
        if needsShift {
            let shiftSource = CGEventSource(stateID: .hidSystemState)
            let shiftDown = CGEvent(keyboardEventSource: shiftSource, virtualKey: shiftKeyCode, keyDown: true)!
            shiftDown.post(tap: CGEventTapLocation.cghidEventTap)
            usleep(50000)
        }
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: finalKeyCode, keyDown: true)!
        if needsShift {
            keyDown.flags = CGEventFlags.maskShift
        }
        keyDown.post(tap: CGEventTapLocation.cghidEventTap)
        usleep(50000) // 增加按键按下时间
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: finalKeyCode, keyDown: false)!
        keyUp.post(tap: CGEventTapLocation.cghidEventTap)
        usleep(50000) // 增加按键释放时间

        if needsShift {
            let shiftSource = CGEventSource(stateID: .hidSystemState)
            let shiftUp = CGEvent(keyboardEventSource: shiftSource, virtualKey: shiftKeyCode, keyDown: false)!
            shiftUp.post(tap: CGEventTapLocation.cghidEventTap)
            usleep(50000)
        }
    }

    // Unicode字符输入函数 - 处理单个Unicode字符
    @MainActor func simulateUnicodeCharacter(_ character: Character) {
        guard let source = CGEventSource(stateID:.combinedSessionState) else {
            return
        }

        // 特殊处理换行符
        if character == "\n" {
            let returnKeyCode = CGKeyCode(kVK_Return)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: true)!
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: false)!
            
            keyDown.post(tap: CGEventTapLocation.cghidEventTap)
            usleep(80000)
            keyUp.post(tap: CGEventTapLocation.cghidEventTap)
            return
        }
        
        guard let unicodeScalar = character.unicodeScalars.first else { 
            return 
        }
        let uniChar = UniChar(unicodeScalar.value & 0xFFFF)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            return
        }
        
        keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])
        keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])

        keyDown.post(tap: CGEventTapLocation.cghidEventTap)
        usleep(80000)
        keyUp.post(tap: CGEventTapLocation.cghidEventTap)
    }
}

// 主程序入口
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()








