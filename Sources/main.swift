import AppKit
import ApplicationServices
import Foundation

let help = """
iPhone Mirroring Icon Mover (release candidate)

  --help                    No input; show this text (also the default).
  --check                   No input; check Accessibility and the Mirroring window.
  --dry-run                 No input; print the planned events as JSON.
  --live                    Explicitly send the planned mouse gesture.

Gesture options (require either --dry-run or --live):
  --from X,Y --to X,Y --image-size WIDTH,HEIGHT
  --hold SECONDS            Before moving: 0...3, default 0.3.
  --duration SECONDS        Main movement: 0.05...5, default 1.25.
  --dwell SECONDS           At target while held: 0...1.5, default 0.9.
  --drop X,Y                Optional final target after dwell.
  --drop-duration SECONDS   Final movement: 0.05...2, default 0.3.
  --window-title TITLE      Exact window title; default: iPhone Mirroring.
  --window-frame X,Y,W,H    Offline fixture, allowed ONLY with --dry-run.
  --expect-window-frame X,Y,W,H
                            Frame recorded with the screenshot; required for --live.

Coordinates refer to an image of the ENTIRE AX window, including its toolbar,
excluding outer screenshot shadow/padding. Obtain a fresh image before each move.
Use ./run.sh for live use via LaunchServices; direct CLI execution can have a
different macOS permission identity. A successful exit does not verify placement.
"""

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

struct TargetWindow {
    let app: NSRunningApplication
    let element: AXUIElement
    let frame: Frame
}

func readFrame(_ element: AXUIElement) throws -> Frame {
    guard let rawPosition = attribute(element, kAXPositionAttribute),
          let rawSize = attribute(element, kAXSizeAttribute),
          CFGetTypeID(rawPosition) == AXValueGetTypeID(), CFGetTypeID(rawSize) == AXValueGetTypeID() else {
        throw MoverError("Cannot read window geometry through Accessibility.", code: 4)
    }
    var position = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(rawPosition as! AXValue, .cgPoint, &position),
          AXValueGetValue(rawSize as! AXValue, .cgSize, &size) else {
        throw MoverError("Invalid Accessibility geometry values.", code: 4)
    }
    let frame = Frame(x: position.x, y: position.y, width: size.width, height: size.height)
    try frame.validate()
    return frame
}

func findWindow(title: String) throws -> TargetWindow {
    guard AXIsProcessTrusted() else {
        throw MoverError("Accessibility access is unavailable. Authorize the intended .app in System Settings, then run --check through ./run.sh. No input sent.", code: 3)
    }
    let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == "com.apple.ScreenContinuity" }
    guard apps.count == 1, let app = apps.first else {
        throw MoverError("Cannot uniquely find the running iPhone Mirroring app. Open it and connect first.", code: 4)
    }
    let element = AXUIElementCreateApplication(app.processIdentifier)
    guard let windows = attribute(element, kAXWindowsAttribute) as? [AXUIElement] else {
        throw MoverError("Cannot read iPhone Mirroring windows through Accessibility.", code: 4)
    }
    let matches = windows.filter { (attribute($0, kAXTitleAttribute) as? String) == title }
    guard matches.count == 1, let window = matches.first else {
        throw MoverError("Cannot uniquely find the window titled '\(title)'. For another UI language, supply its observed exact title with --window-title.", code: 4)
    }
    let frame = try readFrame(window)
    guard frame.width > 150, frame.height > 300,
          (attribute(window, kAXMinimizedAttribute) as? Bool) != true else {
        throw MoverError("The selected window is minimized or not phone-sized. Inspect it before retrying.", code: 4)
    }
    return TargetWindow(app: app, element: window, frame: frame)
}

func sendLive(_ plan: GesturePlan, target: TargetWindow) throws {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
        throw MoverError("Cannot create a mouse event source. No input sent.", code: 6)
    }
    source.localEventsSuppressionInterval = 0
    func makeEvent(_ event: GestureEvent) throws -> CGEvent {
        let type: CGEventType
        switch event.kind {
        case .move: type = .mouseMoved
        case .down: type = .leftMouseDown
        case .drag: type = .leftMouseDragged
        case .up: type = .leftMouseUp
        }
        guard let result = CGEvent(mouseEventSource: source, mouseType: type,
                                   mouseCursorPosition: CGPoint(x: event.point.x, y: event.point.y), mouseButton: .left) else {
            throw MoverError("Cannot allocate a mouse event. No input sent.", code: 6)
        }
        result.flags = []
        result.setIntegerValueField(.mouseEventButtonNumber, value: 0)
        if event.kind == .down || event.kind == .up { result.setIntegerValueField(.mouseEventClickState, value: 1) }
        return result
    }
    // Allocate every event and a spare release BEFORE the first mouse-down.
    let prepared = try plan.events.map(makeEvent)
    let release = try makeEvent(GestureEvent(kind: .up, point: plan.from, waitAfter: 0))
    guard target.app.activate(options: []) else { throw MoverError("Cannot activate iPhone Mirroring. No input sent.", code: 5) }
    Thread.sleep(forTimeInterval: 0.35)
    var queue = try PreparedEventQueue(planned: plan.events, prepared: prepared, spareRelease: release)
    try runGesture(plan, validateBeforePress: {
        guard AXIsProcessTrusted(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.app.processIdentifier,
              try readFrame(target.element) == plan.window,
              (attribute(target.element, kAXMinimizedAttribute) as? Bool) != true,
              !CGEventSource.buttonState(.combinedSessionState, button: .left) else {
            throw MoverError("Focus, geometry, permission, or mouse-button state changed. No mouse-down sent; obtain a fresh screenshot.", code: 5)
        }
    }, send: { event in
        try queue.send(event) { nativeEvent, point in
            nativeEvent.location = CGPoint(x: point.x, y: point.y)
            nativeEvent.post(tap: .cghidEventTap)
        }
    }, wait: { seconds in Thread.sleep(forTimeInterval: seconds) })
}

func execute(_ args: [String]) throws {
    let options = try Options.parse(args)
    if options.mode == .help { print(help); return }
    if options.mode == .check {
        let target = try findWindow(title: options.windowTitle)
        print("Accessibility granted; window frame: \(target.frame.x),\(target.frame.y),\(target.frame.width),\(target.frame.height). No input sent. Record this frame with a fresh screenshot; visually check that the phone is connected.")
        return
    }
    let target = try options.fixture == nil ? findWindow(title: options.windowTitle) : nil
    guard let frame = options.fixture ?? target?.frame else { throw MoverError("No window frame.", code: 4) }
    let plan = try GesturePlan(options: options, frame: frame)
    if options.mode == .dryRun {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(plan), as: UTF8.self))
    } else {
        guard let target else { throw MoverError("Live input requires a real Mirroring window.", code: 4) }
        try sendLive(plan, target: target)
        print("Mouse events posted. The operating system provides no delivery acknowledgement; verify the icon's page and position in iPhone Mirroring.")
    }
}

// Private launcher protocol: a separate status file propagates the helper's exit
// code, because `open -W` reports launch success rather than the app's exit code.
var arguments = Array(CommandLine.arguments.dropFirst())
var statusPath: String?
var result: Int32 = 0
do {
    if let index = arguments.firstIndex(of: "--status-file") {
        guard index + 1 < arguments.count, arguments.filter({ $0 == "--status-file" }).count == 1 else {
            throw MoverError("Invalid launcher status-file option.")
        }
        statusPath = arguments[index + 1]
        arguments.removeSubrange(index...(index + 1))
    }
    try execute(arguments)
} catch {
    result = (error as? MoverError)?.code ?? 6
    fputs("Error: \(error)\n", stderr)
}
if let statusPath {
    do { try "\(result)\n".write(toFile: statusPath, atomically: true, encoding: .utf8) }
    catch { fputs("Error: cannot write launcher exit status: \(error)\n", stderr); result = 7 }
}
exit(result)
