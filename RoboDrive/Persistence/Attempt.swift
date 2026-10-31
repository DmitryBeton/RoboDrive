import Foundation
import SwiftData

@Model final class Attempt {
    @Attribute(.unique) var id: UUID
    var missionID: String
    var missionTitle: String
    var date: Date
    var duration: Double
    var distance: Double
    var collisions: Int
    var succeeded: Bool
    var freeDrive: Bool
    var routeData: Data

    init(id: UUID, engine: RobotEngine) {
        self.id = id
        missionID = engine.mission.id
        missionTitle = engine.mission.title
        date = .now
        duration = engine.elapsed
        distance = engine.distance
        collisions = engine.collisions
        succeeded = engine.succeeded
        freeDrive = engine.mission.isFree
        routeData = (try? JSONEncoder().encode(engine.route)) ?? Data()
    }
    var route: [Vector2] { (try? JSONDecoder().decode([Vector2].self, from: routeData)) ?? [] }
}
