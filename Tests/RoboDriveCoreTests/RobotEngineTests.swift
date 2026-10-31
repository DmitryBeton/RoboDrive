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

@Test func firstMissionCanBeCompletedByDrivingThenStopping() throws {
    var engine = RobotEngine(mission: try MissionCatalog.load()[0])
    engine.throttle = 1
    for _ in 0..<800 { engine.step(1.0 / 120) }
    #expect(!engine.finished)
    #expect(engine.position.distance(to: engine.mission.goal) < 0.58)
    engine.stop()
    for _ in 0..<60 { engine.step(1.0 / 120) }
    #expect(engine.finished && engine.succeeded)
    #expect(engine.route.last == engine.position)
    let time = engine.elapsed
    engine.step(0.1)
    #expect(engine.elapsed == time)
}

@Test func thinBarrierStopsFastRobotAndFailsZeroCollisionMission() throws {
    let base = try MissionCatalog.load()[0]
    let mission = Mission(id: "wall", title: "", subtitle: "", lesson: "", difficulty: "", symbol: "", start: base.start, heading: 0, goal: base.goal, checkpoints: [], barriers: [Barrier(id: "thin", x: 3, y: 4, width: 0.01, height: 3, round: false)], collisionLimit: 0)
    var engine = RobotEngine(mission: mission)
    engine.maximumSpeed = 2; engine.throttle = 1
    for _ in 0..<15 { engine.step(0.1) }
    #expect(engine.position.x < 3 - RobotEngine.radius)
    #expect(engine.finished && !engine.succeeded)
    #expect(engine.collisions == 1 && engine.speed == 0)
}

@Test func checkpointOrderAndFreeDriveCompletion() throws {
    let base = try MissionCatalog.load()[0]
    let mission = Mission(id: "ordered", title: "", subtitle: "", lesson: "", difficulty: "", symbol: "", start: base.start, heading: 0, goal: base.goal, checkpoints: [Vector2(x: 4, y: 4), Vector2(x: 2, y: 4)], barriers: [], collisionLimit: 0)
    var ordered = RobotEngine(mission: mission)
    ordered.step(0.1)
    #expect(ordered.checkpointIndex == 0)
    ordered.throttle = 1
    for _ in 0..<20 { ordered.step(0.1) }
    #expect(ordered.checkpointIndex == 1)
    ordered.throttle = -1
    for _ in 0..<20 { ordered.step(0.1) }
    #expect(ordered.checkpointIndex == 2)
    var free = RobotEngine(mission: base.freeVariant)
    free.throttle = 1
    free.step(0.1)
    free.endFreeDrive()
    #expect(free.finished && free.succeeded && free.speed == 0)
    #expect(free.route.last == free.position)
}

@Test func wheelSpeedsRespectLimitAndFramePartition() throws {
    let mission = try MissionCatalog.load()[0]
    var coarse = RobotEngine(mission: mission), fine = RobotEngine(mission: mission)
    coarse.throttle = 1; coarse.steering = 1; coarse.maximumSpeed = 0.5
    fine.throttle = 1; fine.steering = 1; fine.maximumSpeed = 0.5
    for _ in 0..<10 { coarse.step(0.1) }
    for _ in 0..<120 { fine.step(1.0 / 120) }
    #expect(abs(coarse.leftWheel) <= 0.5 && abs(coarse.rightWheel) <= 0.5)
    #expect(coarse.position.distance(to: fine.position) < 0.0001)
    #expect(abs(coarse.heading - fine.heading) < 0.0001)
}
