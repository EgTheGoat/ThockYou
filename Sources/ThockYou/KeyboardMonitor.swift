@preconcurrency import ApplicationServices
import Foundation

final class KeyboardMonitor {
    private let onKeyDown: (CGKeyCode) -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    var isMonitoring: Bool {
        eventTap != nil
    }

    init(onKeyDown: @escaping (CGKeyCode) -> Void) {
        self.onKeyDown = onKeyDown
    }

    deinit {
        stop()
    }

    func requestAccessPrompt() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    func startIfPermitted(prompt: Bool) -> Bool {
        if !isTrusted {
            if prompt {
                requestAccessPrompt()
            }
            return false
        }

        if eventTap != nil {
            return true
        }

        let keyDownMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let disabledByTimeoutMask = CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
        let disabledByUserInputMask = CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)
        let mask = keyDownMask | disabledByTimeoutMask | disabledByUserInputMask

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: keyboardEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            return false
        }

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }

        runLoopSource = nil
        eventTap = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .keyDown:
            let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            guard !isAutoRepeat else { return }

            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            onKeyDown(keyCode)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        default:
            break
        }
    }
}

private let keyboardEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    monitor.handle(type: type, event: event)

    return Unmanaged.passUnretained(event)
}
