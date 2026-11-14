import Foundation

struct TestFailure: Error, CustomStringConvertible { let description: String }
func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw TestFailure(description: message) }
}
func rejects(_ args: [String]) throws {
    do {
        _ = try Options.parse(args)
    } catch is MoverError { return }
    throw TestFailure(description: "Expected rejection: \(args)")
}
var passed = 0
func test(_ name: String, _ body: () throws -> Void) throws {
    try body()
    passed += 1
    print("PASS \(name)")
}
let base = ["--from", "100,200", "--to", "600,1100", "--image-size", "692,1524"]
let frame = Frame(x: -500, y: 80, width: 346, height: 762)
let plan = try GesturePlan(options: Options.parse(base + ["--dry-run"]), frame: frame)

try test("pixel scaling preserves a negative-origin display") {
    try expect(plan.from == Point(x: -450, y: 180), "Source scaling is wrong")
    try expect(plan.to == Point(x: -200, y: 630), "Target scaling is wrong")
}
try test("every event stays within the chosen window") {
    for event in plan.events {
        try expect(event.point.x >= frame.x && event.point.x < frame.x + frame.width,
                   "Event outside horizontal window bounds")
        try expect(event.point.y >= frame.y && event.point.y < frame.y + frame.height,
                   "Event outside vertical window bounds")
    }
}
try test("one press and release, only held drags between them") {
    let kinds = plan.events.map(\.kind)
    try expect(kinds.first == .move && kinds.last == .up, "Incorrect endpoints")
    try expect(kinds.filter { $0 == .down }.count == 1, "Expected one down")
    try expect(kinds.filter { $0 == .up }.count == 1, "Expected one up")
    try expect(kinds.dropFirst(2).dropLast().allSatisfy { $0 == .drag }, "Non-drag while held")
    try expect(abs(plan.totalSeconds - 2.6) < 0.000001, "Timing changed")
}
try test("drop moves away from the edge before release") {
    let options = try Options.parse(base + ["--dry-run", "--drop", "250,900", "--drop-duration", "0.4", "--dwell", "0"])
    let result = try GesturePlan(options: options, frame: frame)
    try expect(result.events.last?.point == Point(x: -375, y: 530), "Wrong final point")
    try expect(abs(result.totalSeconds - 2.1) < 0.000001, "Zero dwell / drop duration is wrong")
}
try test("offline geometry is forbidden for live input") {
    try rejects(base + ["--live", "--expect-window-frame", "0,0,346,762", "--window-frame", "0,0,346,762"])
    try rejects(["--check", "--window-frame", "0,0,346,762"])
}
try test("ambiguous modes, unknown and duplicate flags fail") {
    try rejects(base + ["--dry-run", "--check"])
    try rejects(base + ["--from", "0,0"])
    try rejects(base + ["--unknown"])
    try rejects(["--from"])
    try rejects(["--help", "--hold", "1"])
    try rejects(["--check", "--duration", "1"])
    try rejects(base + ["--drop-duration", "1"])
}
try test("NaN, infinity, malformed tuples and invalid bounds fail") {
    for bad in ["nan,0", "inf,0", "-1,0", "692,0", "0,1524", "1,,2", "1,2,3"] {
        try rejects(["--dry-run", "--from", bad, "--to", "10,10", "--image-size", "692,1524"])
    }
    for bad in ["0,100", "-1,100", "inf,100"] {
        try rejects(["--dry-run", "--from", "0,0", "--to", "10,10", "--image-size", bad])
    }
    try rejects(base + ["--dry-run", "--drop", "700,0"])
    try rejects(base + ["--dry-run", "--duration", "nan"])
    try rejects(base + ["--dry-run", "--hold", "4"])
    try rejects(base + ["--dry-run", "--dwell", "-1"])
    try rejects(base + ["--dry-run", "--duration", "0"])
    try rejects(base + ["--dry-run", "--window-frame", "0,0,0,20"])
}
try test("live input requires explicit mode and captured frame") {
    try rejects(base)
    try rejects(base + ["--live"])
    let options = try Options.parse(base + ["--live", "--expect-window-frame", "-500,80,346,762"])
    _ = try GesturePlan(options: options, frame: frame)
    do {
        _ = try GesturePlan(options: options, frame: Frame(x: -500, y: 80, width: 350, height: 762))
        throw TestFailure(description: "Changed frame was accepted")
    } catch let error as MoverError { try expect(error.code == 5, "Wrong changed-frame error") }
}
try test("a phone-only crop with a different aspect ratio is rejected") {
    let options = try Options.parse(["--dry-run", "--from", "10,10", "--to", "100,200", "--image-size", "692,1000"])
    do {
        _ = try GesturePlan(options: options, frame: frame)
        throw TestFailure(description: "Mismatched image was accepted")
    } catch is MoverError {}
}
try test("prepared event mapping preserves indices and uses spare release after failure") {
    let tags = Array(plan.events.indices)
    var queue = try PreparedEventQueue(planned: plan.events, prepared: tags, spareRelease: -1)
    var posted: [Int] = []
    try queue.send(plan.events[0]) { tag, _ in posted.append(tag) }
    try queue.send(plan.events[1]) { tag, _ in posted.append(tag) }
    do {
        try queue.send(plan.events[2]) { _, _ in throw MoverError("injected post failure", code: 6) }
        throw TestFailure(description: "Expected posting failure")
    } catch is MoverError {}
    try expect(queue.next == 2, "Failed posting consumed an event")
    try queue.send(GestureEvent(kind: .up, point: plan.from, waitAfter: 0)) { tag, point in
        try expect(point == plan.from, "Wrong release point")
        posted.append(tag)
    }
    try expect(posted == [0, 1, -1], "Spare release was not selected")
}
try test("prepared count mismatch fails before sending") {
    do {
        _ = try PreparedEventQueue(planned: plan.events, prepared: [1], spareRelease: 0)
        throw TestFailure(description: "Count mismatch was accepted")
    } catch is MoverError {}
}
try test("preflight failure sends no mouse events") {
    var sent: [GestureEvent] = []
    do {
        try runGesture(plan, validateBeforePress: { throw MoverError("blocked", code: 5) },
                       send: { sent.append($0) }, wait: { _ in })
        throw TestFailure(description: "Expected preflight failure")
    } catch is MoverError {}
    try expect(sent.isEmpty, "Input was sent despite failed preflight")
}
try test("focus change after pointer movement prevents mouse-down") {
    var calls = 0
    var sent: [GestureEvent] = []
    do {
        try runGesture(plan, validateBeforePress: {
            calls += 1
            if calls == 2 { throw MoverError("focus changed", code: 5) }
        }, send: { sent.append($0) }, wait: { _ in })
        throw TestFailure(description: "Expected focus failure")
    } catch is MoverError {}
    try expect(sent.count == 1 && sent[0].kind == .move, "A mouse-down escaped the second check")
}
try test("a failed first drag releases at the last posted point and keeps failure") {
    var sent: [GestureEvent] = []
    do {
        try runGesture(plan, validateBeforePress: {}, send: {
            if $0.kind == .drag { throw MoverError("injected send failure", code: 6) }
            sent.append($0)
        }, wait: { _ in })
        throw TestFailure(description: "Failure was hidden")
    } catch let error as MoverError {
        try expect(error.code == 6, "Wrong failure code")
    }
    try expect(sent.map(\.kind) == [.move, .down, .up], "Missing cleanup release")
    try expect(sent.last?.point == plan.from, "Cleanup used an unposted coordinate")
}
try test("an error while holding releases the button") {
    var sent: [GestureEvent] = []
    var waits = 0
    do {
        try runGesture(plan, validateBeforePress: {}, send: { sent.append($0) }, wait: { _ in
            waits += 1
            if waits == 2 { throw MoverError("injected hold failure", code: 6) }
        })
        throw TestFailure(description: "Failure was hidden")
    } catch is MoverError {}
    try expect(sent.last?.kind == .up, "Missing cleanup after wait failure")
}
try test("cleanup failure is explicit") {
    do {
        try runGesture(plan, validateBeforePress: {}, send: {
            if $0.kind == .drag || $0.kind == .up { throw MoverError("injected failure", code: 6) }
        }, wait: { _ in })
        throw TestFailure(description: "Expected cleanup failure")
    } catch let error as MoverError {
        try expect(error.description.contains("cleanup mouse-up"), "Cleanup failure was hidden")
    }
}
try test("successful execution does not send a duplicate cleanup release") {
    var sent: [GestureEvent] = []
    try runGesture(plan, validateBeforePress: {}, send: { sent.append($0) }, wait: { _ in })
    try expect(sent == plan.events, "Unexpected extra input")
}

// Integration checks execute only help, invalid arguments, and offline dry runs.
// No Accessibility permission, live window lookup, or real event sender is used.
if CommandLine.arguments.count == 2 {
    let executable = CommandLine.arguments[1]
    func run(_ args: [String]) throws -> (Int32, Data, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let error = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, data, String(decoding: error, as: UTF8.self))
    }
    try test("CLI help does not require Accessibility") {
        let (code, data, _) = try run([])
        try expect(code == 0 && String(decoding: data, as: UTF8.self).contains("--dry-run"), "Help failed")
    }
    try test("CLI invalid geometry fails before access check") {
        let (code, _, error) = try run(base + ["--dry-run", "--drop", "999,0"])
        try expect(code == 2 && error.contains("inside the screenshot"), "Validation did not run first")
    }
    try test("CLI offline dry-run returns the computed JSON plan") {
        let (code, data, _) = try run(base + ["--dry-run", "--window-frame", "-500,80,346,762"])
        let decoded = try JSONDecoder().decode(GesturePlan.self, from: data)
        try expect(code == 0 && decoded.from == plan.from && decoded.drop == plan.drop, "Offline plan mismatch")
    }
    try test("launcher status records helper failure, not just process launch") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("status").path
        let (code, _, _) = try run(["--status-file", path, "--invalid"])
        let status = try String(contentsOfFile: path, encoding: .utf8)
        try expect(code == 2 && status == "2\n", "Wrong recorded helper result")
    }
}
print("\(passed) tests passed. No live input was sent.")
