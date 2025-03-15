// Add this at the top with other imports
import CoreServices
import Cocoa
import Carbon
import Dispatch

var shouldStopCurrentInput = false
var isTyping = false

// Get current active window's AXUIElement
func getCurrentAXWindow() -> AXUIElement? {
    guard let activeApp = NSWorkspace.shared.frontmostApplication else {
        return nil
    }
    let appPID = activeApp.processIdentifier
    return AXUIElementCreateApplication(appPID)
}

// 键码映射表
let asciiToKeyCodeMap: [Character: CGKeyCode] = [
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
let shiftedSpecialChars: [Character: CGKeyCode] = [
    "!": 0x12, "@": 0x13, "#": 0x14, "$": 0x15,
    "%": 0x17, "^": 0x16, "&": 0x1A, "*": 0x1C,
    "(": 0x19, ")": 0x1D, "_": 0x1B, "+": 0x18,
    "{": 0x21, "}": 0x1E, "|": 0x2A, ":": 0x29,
    "\"": 0x27, "<": 0x2B, ">": 0x2F, "?": 0x2C,
    "~": 0x32
]

// 完全重写的ASCII typing函数
func simulateAsciiTyping(text: String) {
    guard let source = CGEventSource(stateID: .combinedSessionState) else {
        print("无法创建事件源")
        return
    }
    
    // 新增输入法切换功能
    switchToEnglishInputSource()
    
    usleep(800000)
    
    shouldStopCurrentInput = false
    isTyping = true
    
    for character in text {
        if shouldStopCurrentInput { break }
        
        var keyCode: CGKeyCode?
        var needsShift = false
        
        // 修复1：直接处理大写字母的shift状态
        if character.isUppercase {
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
        
        // 修复2：增加错误处理
        guard let finalKeyCode = keyCode else {
            print("不支持的字符: \(character) (Unicode: \(character.unicodeScalars.first!.value))")
            continue
        }
        
        // 修复3：优化shift键处理时序
        let shiftKeyCode = CGKeyCode(kVK_Shift)
        if needsShift {
            let shiftDown = CGEvent(keyboardEventSource: source, virtualKey: shiftKeyCode, keyDown: true)!
            shiftDown.flags.remove(.maskShift)
            shiftDown.post(tap: .cghidEventTap)
            usleep(50000) // 延长shift按下延迟
        }
        
        // 修复4：添加字符键的flags处理
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: finalKeyCode, keyDown: true)!
        if needsShift {
            keyDown.flags = .maskShift
        }
        keyDown.post(tap: .cghidEventTap)
        usleep(30000)
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: finalKeyCode, keyDown: false)!
        keyUp.post(tap: .cghidEventTap)
        usleep(30000)

        if needsShift {
            let shiftUp = CGEvent(keyboardEventSource: source, virtualKey: shiftKeyCode, keyDown: false)!
            shiftUp.post(tap: .cghidEventTap)
            usleep(50000)
        }
        
        usleep(25000) // 调整为25ms延迟
    }
    
    isTyping = false
    print("ASCII模拟输入完成")
}

// 处理F10按键事件
func handleF10KeyPress() {
    let semaphore = DispatchSemaphore(value: 0)
    
    guard let clipboardContent = NSPasteboard.general.string(forType:.string) else {
        print("剪贴板为空或非文本内容")
        return
    }
    
    print("检测到剪贴板内容: \(clipboardContent)")

    // 修复：修正ASCII判断后的代码路径
    if isAscii(text: clipboardContent) {
        DispatchQueue.global().async {
            print("准备ASCII模拟输入...")
            usleep(2000000)
            print("开始模拟输入...")
            simulateAsciiTyping(text: clipboardContent)
            semaphore.signal()
        }
    } else {
        // 新增Unicode处理分支
        DispatchQueue.global().async {
            print("准备Unicode模拟输入...")
            usleep(2000000)
            print("开始模拟输入...")
            simulateUnicodeTyping(text: clipboardContent)
            semaphore.signal()
        }
    }

    semaphore.wait()
}


func simulateUnicodeTyping(text: String) {
    guard let source = CGEventSource(stateID:.combinedSessionState) else {
        print("无法创建事件源")
        return
    }

    switchToEnglishInputSource()
    usleep(50000)
    
    shouldStopCurrentInput = false
    isTyping = true

    for character in text {
        if shouldStopCurrentInput {
            print("用户停止输入")
            break
        }
        
        guard let unicodeScalar = character.unicodeScalars.first else { continue }
        let uniChar = UniChar(unicodeScalar.value & 0xFFFF)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        
        keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])
        keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])

        keyDown?.post(tap:.cghidEventTap)
        usleep(80000)
        keyUp?.post(tap:.cghidEventTap)

        usleep(120000)
    }
    
    isTyping = false
    print("Unicode模拟输入完成")
}

// 处理F12按键事件 - 停止当前输入
func handleF12KeyPress() {
    if isTyping {
        shouldStopCurrentInput = true
        isTyping = false // 增加状态重置
        print("正在停止当前输入...")
    } else {
        print("当前无进行中的输入操作")
    }
}

// 判断文本是否仅包含ASCII字符
func isAscii(text: String) -> Bool {
    return text.allSatisfy { $0.isASCII }
}

// 事件回调函数
func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == CGEventType.tapDisabledByTimeout || type == CGEventType.tapDisabledByUserInput {
        print("正在重新获取辅助功能权限")
        if let machPortPointer = refcon?.assumingMemoryBound(to: CFMachPort.self).pointee {
            CGEvent.tapEnable(tap: machPortPointer, enable: true)
        }
        return nil
    }

    if type == CGEventType.keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == kVK_F10 {
            print("检测到F10按键")
            DispatchQueue.global().async {
                handleF10KeyPress()
            }
            // 返回nil以消耗这个事件
            return nil
        } else if keyCode == kVK_F12 {
            print("检测到F12按键")
            handleF12KeyPress()
            // 消耗F12事件
            return nil
        }
    }

    return Unmanaged.passUnretained(event)
}

// 监控F10键和F12键
func monitorKeyEvents() {
    // 声明事件tap变量
    var eventTap: CFMachPort?

    // 创建事件tap
    eventTap = CGEvent.tapCreate(
        tap:.cgSessionEventTap,
        place:.headInsertEventTap,
        options:.defaultTap,
        eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
        callback: eventTapCallback,
        userInfo: nil
    )

    guard let unwrappedEventTap = eventTap else {
        print("开启辅助功能权限.")
        exit(1)
    }

    // 创建运行循环源
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, unwrappedEventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

    // 启用事件tap
    CGEvent.tapEnable(tap: unwrappedEventTap, enable: true)

    print("Keyboard simulator started.")
    print("按下 F10 把剪切板转为按键输入")
    print("按下 F12 停止输入")
    CFRunLoopRun()
}

// 主函数
func main() {
    monitorKeyEvents()
}

main()

// 新增输入法切换函数
private func switchToEnglishInputSource() {
    let englishSources = TISCreateInputSourceList([
        "TISPropertyInputSourceCategory" as CFString: "TISCategoryKeyboardInputSource" as CFString,
        "TISPropertyInputSourceType" as CFString: "TISTypeKeyboardLayout" as CFString
    ] as CFDictionary, false).takeRetainedValue() as! [TISInputSource]
    
    guard let abcKeyboard = englishSources.first(where: { source in
        guard let id = TISGetInputSourceProperty(source, "TISPropertyInputSourceID" as CFString) else { return false }
        let sourceID = Unmanaged<CFString>.fromOpaque(id).takeUnretainedValue() as String
        // 匹配ABC和简体拼音输入法
        return sourceID == "com.apple.keylayout.ABC" || sourceID == "com.apple.inputmethod.SCIM.ITABC"
    }) else {
        print("English input source not found")
        return
    }
    
    TISSelectInputSource(abcKeyboard)
    usleep(500000)
}
