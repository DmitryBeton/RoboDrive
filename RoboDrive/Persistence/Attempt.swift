import Foundation
import SwiftData

/// Снимок завершенной попытки. Отделен от живого сеанса и хранится локально через SwiftData.
/// Название сохраняем вместе с ID, чтобы история оставалась понятной после переименования задания.
@Model final class Attempt {
    // UUID сеанса позволяет повторять сохранение той же попытки без создания нового идентификатора.
    @Attribute(.unique) var id: UUID
    var missionID: String
    var missionTitle: String
    var date: Date
    var duration: Double
    var distance: Double
    var collisions: Int
    var succeeded: Bool
    var freeDrive: Bool
    // Точки кодируются одним JSON-блоком: отдельные SwiftData-сущности для каждой точки не нужны.
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
    /// Если данные траектории повреждены, остальные показатели результата остаются доступны.
    var route: [Vector2] { (try? JSONDecoder().decode([Vector2].self, from: routeData)) ?? [] }
}
