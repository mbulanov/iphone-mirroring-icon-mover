import Foundation

struct MoverError: Error, CustomStringConvertible {
    let code: Int32
    let description: String
    init(_ description: String, code: Int32 = 2) {
        self.description = description
        self.code = code
    }
}

struct Point: Codable, Equatable {
    let x: Double
    let y: Double
}

struct Frame: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    func validate() throws {
        guard [x, y, width, height].allSatisfy({ $0.isFinite }),
              width > 0, height > 0,
              abs(x) <= 100_000, abs(y) <= 100_000,
              width <= 100_000, height <= 100_000 else {
            throw MoverError("Invalid window frame: expected finite screen points and positive dimensions.")
        }
    }
}

enum Mode { case help, check, dryRun, live }

struct Options {
    let mode: Mode
    let windowTitle: String
    let fixture: Frame?
    let expectedFrame: Frame?
    let from: Point?
    let to: Point?
    let imageSize: Point?
    let drop: Point?
    let hold: Double
    let duration: Double
    let dwell: Double
    let dropDuration: Double

    static func parse(_ args: [String]) throws -> Options {
        let switches: Set<String> = ["--help", "--check", "--dry-run", "--live"]
        let valued: Set<String> = ["--from", "--to", "--image-size", "--drop", "--hold",
                                  "--duration", "--dwell", "--drop-duration", "--window-frame", "--expect-window-frame", "--window-title"]
        var values: [String: String] = [:]
        var flags: Set<String> = []
        var index = 0
        while index < args.count {
            let key = args[index]
            guard values[key] == nil, !flags.contains(key) else { throw MoverError("Duplicate option: \(key)") }
            if switches.contains(key) {
                flags.insert(key)
            } else if valued.contains(key) {
                index += 1
                guard index < args.count, !args[index].hasPrefix("--") else { throw MoverError("Missing value for \(key)") }
                values[key] = args[index]
            } else {
                throw MoverError("Unknown option: \(key). Use --help.")
            }
            index += 1
        }
        guard flags.count <= 1 else { throw MoverError("Choose only one of --help, --check, --dry-run, or --live.") }
        if !args.isEmpty && flags.isEmpty { throw MoverError("Choose --dry-run to inspect a gesture or --live to send it.") }
        let mode: Mode = args.isEmpty || flags.contains("--help") ? .help :
            flags.contains("--check") ? .check : flags.contains("--dry-run") ? .dryRun : .live
        if mode == .help && !values.isEmpty { throw MoverError("--help cannot be combined with gesture options.") }
        if mode == .check && values.keys.contains(where: { $0 != "--window-title" }) {
            throw MoverError("--check accepts only --window-title; no gesture is performed.")
        }
        if values["--window-frame"] != nil && mode != .dryRun {
            throw MoverError("--window-frame is allowed only with --dry-run; it can never select a live target.")
        }
        if values["--drop-duration"] != nil && values["--drop"] == nil {
            throw MoverError("--drop-duration requires --drop.")
        }
        func tuple(_ key: String, count: Int) throws -> [Double]? {
            guard let raw = values[key] else { return nil }
            let parts = raw.split(separator: ",", omittingEmptySubsequences: false)
            let numbers = parts.compactMap { Double($0) }
            guard parts.count == count, numbers.count == count, numbers.allSatisfy({ $0.isFinite }) else {
                throw MoverError("\(key) requires \(count) finite comma-separated numbers.")
            }
            return numbers
        }
        func point(_ key: String) throws -> Point? {
            guard let a = try tuple(key, count: 2) else { return nil }
            return Point(x: a[0], y: a[1])
        }
        func timing(_ key: String, default value: Double, range: ClosedRange<Double>) throws -> Double {
            guard let raw = values[key] else { return value }
            guard let n = Double(raw), n.isFinite, range.contains(n) else {
                throw MoverError("\(key) must be between \(range.lowerBound) and \(range.upperBound) seconds.")
            }
            return n
        }
        let title = values["--window-title"] ?? "iPhone Mirroring"
        guard !title.isEmpty else { throw MoverError("--window-title cannot be empty.") }
        let from = try point("--from"), to = try point("--to"), size = try point("--image-size")
        let drop = try point("--drop")
        if mode == .live || mode == .dryRun {
            guard let from, let to, let size, size.x > 0, size.y > 0 else {
                throw MoverError("A gesture requires --from X,Y --to X,Y --image-size WIDTH,HEIGHT with positive dimensions.")
            }
            for p in [from, to] + (drop.map { [$0] } ?? []) {
                guard p.x >= 0, p.y >= 0, p.x < size.x, p.y < size.y else {
                    throw MoverError("Every point must be inside the screenshot: 0 <= x < width, 0 <= y < height.")
                }
            }
        }
        let frameNumbers = try tuple("--window-frame", count: 4)
        let frame = frameNumbers.map { Frame(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
        try frame?.validate()
        let expectedNumbers = try tuple("--expect-window-frame", count: 4)
        let expected = expectedNumbers.map { Frame(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
        try expected?.validate()
        if mode == .live && expected == nil {
            throw MoverError("--live requires --expect-window-frame X,Y,W,H recorded with the source screenshot.")
        }
        return Options(mode: mode, windowTitle: title, fixture: frame, expectedFrame: expected, from: from, to: to,
                       imageSize: size, drop: drop,
                       hold: try timing("--hold", default: 0.3, range: 0...3),
                       duration: try timing("--duration", default: 1.25, range: 0.05...5),
                       dwell: try timing("--dwell", default: 0.9, range: 0...1.5),
                       dropDuration: try timing("--drop-duration", default: 0.3, range: 0.05...2))
    }
}

enum EventKind: String, Codable { case move, down, drag, up }
struct GestureEvent: Codable, Equatable {
    let kind: EventKind
    let point: Point
    let waitAfter: Double
}

struct GesturePlan: Codable {
    let window: Frame
    let from: Point
    let to: Point
    let drop: Point
    let totalSeconds: Double
    let events: [GestureEvent]

    init(options: Options, frame: Frame) throws {
        try frame.validate()
        guard let source = options.from, let target = options.to, let size = options.imageSize,
              size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0 else {
            throw MoverError("No gesture coordinates supplied.")
        }
        if let expected = options.expectedFrame, expected != frame {
            throw MoverError("Window frame differs from --expect-window-frame. Capture a fresh full-window screenshot and frame before retrying.", code: 5)
        }
        let imageRatio = size.x / size.y
        let windowRatio = frame.width / frame.height
        guard imageRatio.isFinite, abs(imageRatio / windowRatio - 1) <= 0.02 else {
            throw MoverError("Screenshot/window aspect ratios differ by more than 2%. Use an image of the entire AX window, without external padding.")
        }
        func map(_ p: Point) -> Point {
            Point(x: frame.x + (p.x / size.x) * frame.width, y: frame.y + (p.y / size.y) * frame.height)
        }
        window = frame
        from = map(source)
        to = map(target)
        drop = map(options.drop ?? target)
        var steps = [GestureEvent(kind: .move, point: from, waitAfter: 0.15),
                     GestureEvent(kind: .down, point: from, waitAfter: options.hold)]
        func appendMovement(_ a: Point, _ b: Point, seconds: Double) {
            let count = max(1, Int(ceil(seconds * 90)))
            for i in 1...count {
                let t = Double(i) / Double(count)
                steps.append(GestureEvent(kind: .drag,
                    point: Point(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t),
                    waitAfter: seconds / Double(count)))
            }
        }
        appendMovement(from, to, seconds: options.duration)
        if options.dwell > 0 {
            let count = max(1, Int(ceil(options.dwell * 60)))
            for _ in 0..<count {
                steps.append(GestureEvent(kind: .drag, point: to, waitAfter: options.dwell / Double(count)))
            }
        }
        if drop != to { appendMovement(to, drop, seconds: options.dropDuration) }
        steps.append(GestureEvent(kind: .up, point: drop, waitAfter: 0))
        events = steps
        totalSeconds = steps.reduce(0) { $0 + $1.waitAfter }
    }
}

// Preallocated native events stay aligned with the tested logical event stream.
// The spare release is used only for cleanup after an interrupted sequence.
struct PreparedEventQueue<NativeEvent> {
    let planned: [GestureEvent]
    let prepared: [NativeEvent]
    let spareRelease: NativeEvent
    private(set) var next = 0

    init(planned: [GestureEvent], prepared: [NativeEvent], spareRelease: NativeEvent) throws {
        guard planned.count == prepared.count else { throw MoverError("Prepared event count mismatch.", code: 6) }
        self.planned = planned
        self.prepared = prepared
        self.spareRelease = spareRelease
    }

    mutating func send(_ event: GestureEvent, post: (NativeEvent, Point) throws -> Void) throws {
        if next < planned.count && event == planned[next] {
            try post(prepared[next], event.point)
            next += 1
        } else if event.kind == .up {
            try post(spareRelease, event.point)
        } else {
            throw MoverError("Unexpected event sequence.", code: 6)
        }
    }
}

// The sender must throw BEFORE posting when it cannot send an event.
// A returned send means "posted", never "accepted by the phone".
func runGesture(_ plan: GesturePlan,
                validateBeforePress: () throws -> Void,
                send: (GestureEvent) throws -> Void,
                wait: (Double) throws -> Void) throws {
    var held = false
    var lastPoint = plan.from
    do {
        try validateBeforePress()
        for event in plan.events {
            if event.kind == .down { try validateBeforePress() }
            try send(event)
            lastPoint = event.point
            if event.kind == .down { held = true }
            if event.kind == .up { held = false }
            if event.waitAfter > 0 { try wait(event.waitAfter) }
        }
    } catch {
        if held {
            do {
                try send(GestureEvent(kind: .up, point: lastPoint, waitAfter: 0))
            } catch {
                throw MoverError("Gesture failed and the cleanup mouse-up could not be posted. Release the mouse button manually and inspect the screen.", code: 6)
            }
        }
        throw error
    }
}
