import SwiftUI
import Observation

@Observable @MainActor final class DriveSession {
    enum Phase: Hashable { case ready, driving, paused, finished }
    let id = UUID()
    let mission: Mission
    @ObservationIgnored private(set) var engine: RobotEngine
    @ObservationIgnored lazy var scene = RobotScene(session: self)
    var phase: Phase = .ready
    var elapsed = 0.0
    var distance = 0.0
    var collisions = 0
    var leftWheel = 0.0
    var rightWheel = 0.0
    var checkpoint = 0
    var speedLimit = 1.2
    var showData = false
    var showTrail: Bool
    var haptics: Bool
    @ObservationIgnored private var lastPublished = 0.0

    init(mission: Mission, sensitivity: Double, showTrail: Bool, haptics: Bool) {
        self.mission = mission
        self.engine = RobotEngine(mission: mission)
        self.engine.sensitivity = sensitivity
        self.showTrail = showTrail
        self.haptics = haptics
    }
    func begin() { guard phase == .ready else { return }; scene.resetClock(); phase = .driving }
    func control(x: Double, y: Double) {
        guard phase == .driving else { engine.stop(); return }
        engine.steering = x
        engine.throttle = y
    }
    func stop() { engine.stop(); leftWheel = 0; rightWheel = 0 }
    func pause() { guard phase == .driving else { return }; stop(); phase = .paused }
    func resume() { guard phase == .paused else { return }; stop(); scene.resetClock(); phase = .driving }
    func finishFreeDrive() {
        guard mission.isFree else { return }
        engine.endFreeDrive(); publish(); phase = .finished
    }
    func advance(_ dt: Double) {
        guard phase == .driving else { return }
        engine.maximumSpeed = speedLimit
        let previous = engine.collisions
        engine.step(dt)
        if previous != engine.collisions && haptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        if engine.elapsed - lastPublished >= 0.1 || engine.finished { publish() }
        if engine.finished { phase = .finished }
    }
    private func publish() {
        elapsed = engine.elapsed; distance = engine.distance; collisions = engine.collisions
        leftWheel = engine.leftWheel; rightWheel = engine.rightWheel
        checkpoint = engine.checkpointIndex; lastPublished = elapsed
    }
}
