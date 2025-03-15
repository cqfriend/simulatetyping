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
        print("Failed to create event source.")
        return
    }
    
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
            print("Unsupported character: \(character) (Unicode: \(character.unicodeScalars.first!.value))")
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
            usleep(50000) // 延长shift释放延迟
        }
        
        usleep(40000)
    }
    
    isTyping = false
    print("Simulated ASCII typing completed.")
}

// Unicode字符输入函数
func simulateUnicodeTyping(text: String) {
    guard let source = CGEventSource(stateID:.combinedSessionState) else {
        print("Failed to create event source.")
        return
    }

    usleep(50000)
    
    shouldStopCurrentInput = false
    isTyping = true

    for character in text {
        // 检查是否应该停止当前输入
        if shouldStopCurrentInput {
            print("Input stopped by user.")
            break
        }
        
        guard let unicodeScalar = character.unicodeScalars.first else { continue }
        let uniChar = UniChar(unicodeScalar.value & 0xFFFF)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

        keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])
        keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])

        keyDown?.post(tap:.cghidEventTap)
        usleep(20000) // 延长按键延迟
        keyUp?.post(tap:.cghidEventTap)

        usleep(40000) // 延长字符间延迟
    }
    
    isTyping = false
    print("Simulated Unicode typing completed.")
}

// 处理F10按键事件
func handleF10KeyPress() {
    let semaphore = DispatchSemaphore(value: 0)
    
    guard let clipboardContent = NSPasteboard.general.string(forType:.string) else {
        print("Clipboard is empty or does not contain text.")
        return
    }
    
    print("Clipboard content detected: \(clipboardContent)")

    // 检查剪贴板内容并模拟键入
    if isAscii(text: clipboardContent) {
        DispatchQueue.global().async {
            print("Preparing to simulate ASCII typing...")
            usleep(2000000) // 2秒延迟 - 给用户准备时间
            print("Starting simulation...")
            simulateAsciiTyping(text: clipboardContent)
            semaphore.signal()
        }
    } else {
        DispatchQueue.global().async {
            print("Preparing to simulate Unicode typing...")
            usleep(2000000) // 2秒延迟
            print("Starting simulation...")
            simulateUnicodeTyping(text: clipboardContent)
            semaphore.signal()
        }
    }

    // 等待输入完成
    semaphore.wait()
}

// 处理F12按键事件 - 停止当前输入
func handleF12KeyPress() {
    if isTyping {
        shouldStopCurrentInput = true
        print("Stopping current input...")
    } else {
        print("No active typing to stop.")
    }
}

// 判断文本是否仅包含ASCII字符
func isAscii(text: String) -> Bool {
    return text.allSatisfy { $0.isASCII }
}

// 事件回调函数
func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == CGEventType.tapDisabledByTimeout || type == CGEventType.tapDisabledByUserInput {
        print("Re-acquiring assistive functionality.")
        if let machPortPointer = refcon?.assumingMemoryBound(to: CFMachPort.self).pointee {
            CGEvent.tapEnable(tap: machPortPointer, enable: true)
        }
        return nil
    }

    if type == CGEventType.keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == kVK_F10 {
            print("F10 key detected")
            DispatchQueue.global().async {
                handleF10KeyPress()
            }
            // 返回nil以消耗这个事件
            return nil
        } else if keyCode == kVK_F12 {
            print("F12 key detected")
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
        print("Please enable assistive functionality.")
        exit(1)
    }

    // 创建运行循环源
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, unwrappedEventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

    // 启用事件tap
    CGEvent.tapEnable(tap: unwrappedEventTap, enable: true)

    print("Keyboard simulator started.")
    print("Press F10 to type clipboard content")
    print("Press F12 to stop current typing")
    CFRunLoopRun()
}

// 主函数
func main() {
    monitorKeyEvents()
}

main()
