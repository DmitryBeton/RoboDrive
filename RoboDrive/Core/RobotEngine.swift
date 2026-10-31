import Foundation

nonisolated struct Vector2: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    static let zero = Vector2(x: 0, y: 0)
    func distance(to other: Vector2) -> Double { hypot(x - other.x, y - other.y) }
}

nonisolated struct Barrier: Codable, Identifiable, Sendable {
    let id: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let round: Bool

    func intersects(_ point: Vector2, radius: Double) -> Bool {
        if round { return point.distance(to: Vector2(x: x, y: y)) < width / 2 + radius }
        let dx = max(abs(point.x - x) - width / 2, 0)
        let dy = max(abs(point.y - y) - height / 2, 0)
        return hypot(dx, dy) < radius
    }
}

nonisolated struct Mission: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let lesson: String
    let difficulty: String
    let symbol: String
    let start: Vector2
    let heading: Double
    let goal: Vector2
    let checkpoints: [Vector2]
    let barriers: [Barrier]
    let collisionLimit: Int
    var isFree: Bool { id.hasPrefix("free-") }
    var freeVariant: Mission {
        Mission(id: "free-" + id, title: title, subtitle: "Свободная практика", lesson: lesson,
                difficulty: difficulty, symbol: symbol, start: start, heading: heading,
                goal: goal, checkpoints: [], barriers: barriers, collisionLimit: Int.max)
    }
}

nonisolated enum MissionCatalog {
    static func load() throws -> [Mission] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "missions", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let missions = try JSONDecoder().decode([Mission].self, from: Data(contentsOf: url))
        guard missions.count >= 3, Set(missions.map(\.id)).count == missions.count,
              missions.allSatisfy({ !$0.id.isEmpty && !$0.isFree && $0.collisionLimit >= 0 }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return missions
    }
}

/// Ideal differential drive in metres and seconds. The renderer does not control physics.
nonisolated struct RobotEngine {
    static let width = 12.0
    static let height = 8.0
    static let radius = 0.32
    static let track = 0.48
    let mission: Mission
    private(set) var position: Vector2
    private(set) var heading: Double
    private(set) var elapsed = 0.0
    private(set) var distance = 0.0
    private(set) var collisions = 0
    private(set) var checkpointIndex = 0
    private(set) var finished = false
    private(set) var succeeded = false
    private(set) var leftWheel = 0.0
    private(set) var rightWheel = 0.0
    private(set) var route: [Vector2]
    private var touching = false
    private var dwell = 0.0
    var throttle = 0.0
    var steering = 0.0
    var maximumSpeed = 1.2
    var sensitivity = 1.0
    var speed: Double { (leftWheel + rightWheel) / 2 }
    var nextCheckpoint: Vector2? {
        checkpointIndex < mission.checkpoints.count ? mission.checkpoints[checkpointIndex] : nil
    }

    init(mission: Mission) {
        self.mission = mission
        position = mission.start
        heading = mission.heading
        route = [mission.start]
    }

    mutating func stop() {
        throttle = 0; steering = 0; leftWheel = 0; rightWheel = 0
    }

    mutating func endFreeDrive() {
        guard mission.isFree else { return }
        finished = true
        succeeded = true
        stop()
        recordEndpoint()
    }

    mutating func step(_ duration: Double) {
        guard !finished, duration.isFinite, duration > 0 else { return }
        // Bound a stalled render frame, then substep to prevent crossing thin walls.
        var remaining = min(duration, 0.1)
        while remaining > 0.000001 && !finished {
            let dt = min(remaining, 1.0 / 120)
            integrate(dt)
            remaining -= dt
        }
    }

    private mutating func integrate(_ dt: Double) {
        elapsed += dt
        let limit = min(maximumSpeed, 2.0).clamped(to: 0.3...2)
        let forward = throttle.clamped(to: -1...1) * limit
        let turn = steering.clamped(to: -1...1) * 2.6 * sensitivity.clamped(to: 0.5...1.5)
        leftWheel = (forward - turn * Self.track / 2).clamped(to: -limit...limit)
        rightWheel = (forward + turn * Self.track / 2).clamped(to: -limit...limit)
        let omega = (rightWheel - leftWheel) / Self.track
        let midAngle = heading + omega * dt / 2
        let candidate = Vector2(x: position.x + speed * cos(midAngle) * dt,
                                y: position.y + speed * sin(midAngle) * dt)
        heading = atan2(sin(heading + omega * dt), cos(heading + omega * dt))
        let hit = isBlocked(candidate)
        if hit {
            if !touching { collisions += 1 }
            touching = true
            if !mission.isFree && collisions > mission.collisionLimit {
                finished = true; succeeded = false; stop(); recordEndpoint(); return
            }
        } else {
            // Pure rotation at the wall does not create repeated collision events.
            if abs(speed) > 0.01 { touching = false }
            distance += position.distance(to: candidate)
            position = candidate
        }
        if route.last!.distance(to: position) >= 0.07 { route.append(position) }
        if let checkpoint = nextCheckpoint, position.distance(to: checkpoint) < 0.58 {
            checkpointIndex += 1
        }
        if !mission.isFree && nextCheckpoint == nil && position.distance(to: mission.goal) < 0.58 && abs(speed) < 0.12 {
            dwell += dt
            if dwell >= 0.35 { finished = true; succeeded = true; stop(); recordEndpoint() }
        } else { dwell = 0 }
    }

    private mutating func recordEndpoint() {
        if route.last != position { route.append(position) }
    }

    func isBlocked(_ p: Vector2) -> Bool {
        p.x < Self.radius || p.y < Self.radius || p.x > Self.width - Self.radius ||
        p.y > Self.height - Self.radius || mission.barriers.contains { $0.intersects(p, radius: Self.radius) }
    }
}

nonisolated extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double { min(max(self, range.lowerBound), range.upperBound) }
}
