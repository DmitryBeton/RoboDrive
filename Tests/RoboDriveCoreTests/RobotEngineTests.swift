import Testing
@testable import RoboDriveCore

@Test func catalogAndSpawnPoints() throws {
    let missions = try MissionCatalog.load()
    #expect(missions.count == 5)
    for mission in missions {
        let engine = RobotEngine(mission: mission)
        #expect(!engine.isBlocked(mission.start))
        #expect(!engine.isBlocked(mission.goal))
        for point in mission.checkpoints { #expect(!engine.isBlocked(point)) }
    }
}

@Test func straightAndReverseMotion() throws {
    var engine = RobotEngine(mission: try MissionCatalog.load()[0])
    engine.throttle = 1
    for _ in 0..<120 { engine.step(1.0 / 120) }
    #expect(abs(engine.position.x - 3.2) < 0.001)
    #expect(abs(engine.position.y - 4) < 0.001)
    #expect(engine.leftWheel == engine.rightWheel)
    engine.throttle = -1
    for _ in 0..<120 { engine.step(1.0 / 120) }
    #expect(abs(engine.position.x - 2) < 0.001)
}

@Test func rotationAndStop() throws {
    var engine = RobotEngine(mission: try MissionCatalog.load()[0])
    engine.steering = 1
    engine.step(0.1)
    #expect(engine.position == engine.mission.start)
    #expect(engine.heading > 0)
    #expect(engine.leftWheel < 0 && engine.rightWheel > 0)
    engine.stop()
    let position = engine.position, angle = engine.heading
    engine.step(0.1)
    #expect(engine.position == position && engine.heading == angle)
}

@Test func wallContactDoesNotTunnelOrCountEveryFrame() throws {
    var engine = RobotEngine(mission: try MissionCatalog.load()[0].freeVariant)
    engine.throttle = -1
    for _ in 0..<100 { engine.step(0.1) }
    #expect(engine.position.x >= RobotEngine.radius)
    #expect(engine.collisions == 1)
    engine.throttle = 1
    for _ in 0..<20 { engine.step(0.1) }
    engine.throttle = -1
    for _ in 0..<40 { engine.step(0.1) }
    #expect(engine.collisions == 2)
}

@Test func arrivalRequiresStoppingAndAllCheckpoints() throws {
    let base = try MissionCatalog.load()[0]
    let mission = Mission(id: "test", title: "", subtitle: "", lesson: "", difficulty: "", symbol: "", start: base.start, heading: 0, goal: base.start, checkpoints: [], barriers: [], collisionLimit: 0)
    var engine = RobotEngine(mission: mission)
    for _ in 0..<5 { engine.step(0.1) }
    #expect(engine.finished && engine.succeeded)
    let gated = Mission(id: "gated", title: "", subtitle: "", lesson: "", difficulty: "", symbol: "", start: base.start, heading: 0, goal: base.start, checkpoints: [.zero], barriers: [], collisionLimit: 0)
    var waiting = RobotEngine(mission: gated)
    for _ in 0..<5 { waiting.step(0.1) }
    #expect(!waiting.finished)
}

@Test func excessiveFrameTimeIsBounded() throws {
    var engine = RobotEngine(mission: try MissionCatalog.load()[0])
    engine.throttle = 1
    engine.step(100)
    #expect(engine.distance <= 0.121)
    engine.step(.nan)
    #expect(engine.position.x.isFinite)
}
