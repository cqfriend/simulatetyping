import Cocoa
import Carbon
import Dispatch

var shouldExit = false

// Get current active window's AXUIElement
func getCurrentAXWindow() -> AXUIElement? {
    guard let activeApp = NSWorkspace.shared.frontmostApplication else {
        return nil
    }
    let appPID = activeApp.processIdentifier
    return AXUIElementCreateApplication(appPID)
}

// Function to simulate typing ASCII characters using key codes
// Function to simulate typing ASCII characters using key codes
// Function to simulate typing ASCII characters using CGKeyCode based on ASCII values
// Function to simulate typing ASCII characters using CGKeyCode based on ASCII values
// 键码映射表
let asciiToKeyCodeMap: [Character: (CGKeyCode, Bool)] = [
    // Letters
    "a": (0x00, false), "b": (0x0B, false), "c": (0x08, false), "d": (0x02, false),
    "e": (0x0E, false), "f": (0x03, false), "g": (0x05, false), "h": (0x04, false),
    "i": (0x22, false), "j": (0x26, false), "k": (0x28, false), "l": (0x25, false),
    "m": (0x2E, false), "n": (0x2D, false), "o": (0x1F, false), "p": (0x23, false),
    "q": (0x0C, false), "r": (0x0F, false), "s": (0x01, false), "t": (0x11, false),
    "u": (0x20, false), "v": (0x09, false), "w": (0x0D, false), "x": (0x07, false),
    "y": (0x10, false), "z": (0x06, false),
    "A": (0x00, true), "B": (0x0B, true), "C": (0x08, true), "D": (0x02, true),
    "E": (0x0E, true), "F": (0x03, true), "G": (0x05, true), "H": (0x04, true),
    "I": (0x22, true), "J": (0x26, true), "K": (0x28, true), "L": (0x25, true),
    "M": (0x2E, true), "N": (0x2D, true), "O": (0x1F, true), "P": (0x23, true),
    "Q": (0x0C, true), "R": (0x0F, true), "S": (0x01, true), "T": (0x11, true),
    "U": (0x20, true), "V": (0x09, true), "W": (0x0D, true), "X": (0x07, true),
    "Y": (0x10, true), "Z": (0x06, true),

    // Numbers
    "1": (0x12, false), "2": (0x13, false), "3": (0x14, false), "4": (0x15, false),
    "5": (0x17, false), "6": (0x16, false), "7": (0x1A, false), "8": (0x1C, false),
    "9": (0x19, false), "0": (0x1D, false),

    // Special Characters
    " ": (0x31, false), "!": (0x12, true), "@": (0x13, true), "#": (0x14, true),
    "$": (0x15, true), "%": (0x17, true), "^": (0x16, true), "&": (0x1A, true),
    "*": (0x1C, true), "(": (0x19, true), ")": (0x1D, true),
    "-": (0x1B, false), "_": (0x1B, true), "=": (0x18, false), "+": (0x18, true),
    "[": (0x21, false), "]": (0x1E, false), "{": (0x21, true), "}": (0x1E, true),
    "\\": (0x2A, false), "|": (0x2A, true), ";": (0x29, false), ":": (0x29, true),
    "'": (0x27, false), "\"": (0x27, true), ",": (0x2B, false), "<": (0x2B, true),
    ".": (0x2F, false), ">": (0x2F, true), "/": (0x2C, false), "?": (0x2C, true),
    "`": (0x32, false), "~": (0x32, true),

    // Tab and Enter
    "\t": (0x30, false), // Tab
    "\n": (0x24, false)  // Enter (Return)
]

func simulateAsciiTyping(text: String) {
    guard let source = CGEventSource(stateID: .combinedSessionState) else {
        print("Failed to create event source.")
        return
    }

    for character in text {
        guard let (keyCode, shiftRequired) = asciiToKeyCodeMap[character] else {
            print("Character \(character) is not supported.")
            continue
        }

        if shiftRequired {
            let shiftDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Shift), keyDown: true)
            shiftDown?.post(tap: .cghidEventTap)
            usleep(10000)
        }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        if shiftRequired {
            let shiftUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Shift), keyDown: false)
            shiftUp?.post(tap: .cghidEventTap)
            usleep(10000)
        }

        usleep(50000) // Delay between key presses
    }

    print("Simulated ASCII typing completed.")
}

// Function to simulate typing Unicode characters
func simulateUnicodeTyping(text: String) {
    guard let source = CGEventSource(stateID:.combinedSessionState) else {
        print("Failed to create event source.")
        return
    }

    usleep(300000)

    for character in text {
        guard let unicodeScalar = character.unicodeScalars.first else { continue }
        let uniChar = UniChar(unicodeScalar.value & 0xFFFF)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

        keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])
        keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])

        keyDown?.post(tap:.cghidEventTap)
        keyUp?.post(tap:.cghidEventTap)

        usleep(50000) // 50ms delay
    }

    print("Simulated Unicode typing completed.")
}

// Handle F10 key press
func handleF10KeyPress() {
    let semaphore = DispatchSemaphore(value: 0)
    
    guard let clipboardContent = NSPasteboard.general.string(forType:.string) else {
        print("Clipboard is empty or does not contain text.")
        return
    }

    // Check if clipboard contains ASCII or Unicode characters and simulate typing accordingly
    if isAscii(text: clipboardContent) {
        DispatchQueue.global().async {
            print("Simulating ASCII typing of clipboard content: \(clipboardContent)")
            usleep(2000000) // Delay before typing
            simulateAsciiTyping(text: clipboardContent) // Simulate ASCII typing
            semaphore.signal()
        }
    } else {
        DispatchQueue.global().async {
            print("Simulating Unicode typing of clipboard content: \(clipboardContent)")
            usleep(2000000) // Delay before typing
            simulateUnicodeTyping(text: clipboardContent) // Simulate Unicode typing
            semaphore.signal()
        }
    }

    // Wait for typing simulation to finish
    semaphore.wait()
}

// Function to check if text contains only ASCII characters
func isAscii(text: String) -> Bool {
    return text.allSatisfy { $0.isASCII }
}

// Event tap callback
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
            DispatchQueue.global().async {
                handleF10KeyPress()
            }
        }
    }

    return Unmanaged.passUnretained(event)
}

// Monitor F10 key
func monitorF10Key() {
    // Declare the event tap variable
    var eventTap: CFMachPort?

    // Create the event tap
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

    // Create the run loop source
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, unwrappedEventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

    // Enable the event tap
    CGEvent.tapEnable(tap: unwrappedEventTap, enable: true)

    print("Press F10 to start simulation.")
    CFRunLoopRun()
}

// Main function
func main() {
    monitorF10Key()
}

main()
