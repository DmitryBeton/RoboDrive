import Foundation

/// Координаты в метрах: начало полигона слева внизу, ось Y направлена вверх.
/// nonisolated оставляет ядро независимым от MainActor приложения и доступным для тестов.
nonisolated struct Vector2: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    static let zero = Vector2(x: 0, y: 0)
    func distance(to other: Vector2) -> Double { hypot(x - other.x, y - other.y) }
}

/// Геометрия препятствия из JSON. x/y задают центр, width/height — размеры в метрах.
/// Для круглой колонны width задает диаметр, height при проверке контакта не используется.
nonisolated struct Barrier: Codable, Identifiable, Sendable {
    let id: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let round: Bool

    /// Контакт круглого робота с колонной или ближайшей точкой прямоугольника.
    func intersects(_ point: Vector2, radius: Double) -> Bool {
        if round { return point.distance(to: Vector2(x: x, y: y)) < width / 2 + radius }
        let dx = max(abs(point.x - x) - width / 2, 0)
        let dy = max(abs(point.y - y) - height / 2, 0)
        return hypot(dx, dy) < radius
    }
}

/// Описание задания без изменяемого состояния заезда. heading измеряется в радианах:
/// ноль означает движение вправо, положительное направление — против часовой стрелки.
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
    /// Сохраняем геометрию, но убираем обязательные точки и лимит касаний.
    /// Префикс free- отделяет такие результаты от прогресса учебных заданий.
    var freeVariant: Mission {
        Mission(id: "free-" + id, title: title, subtitle: "Свободная практика", lesson: lesson,
                difficulty: difficulty, symbol: symbol, start: start, heading: heading,
                goal: goal, checkpoints: [], barriers: barriers, collisionLimit: Int.max)
    }
}

nonisolated enum MissionCatalog {
    static func load() throws -> [Mission] {
        // В тестовом Swift Package ресурсы находятся в отдельном bundle, в приложении — в основном.
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

/// Идеальная модель дифференциального привода без инерции и проскальзывания.
/// Это единственный источник положения робота, контактов и результата задания.
/// SpriteKit только отображает состояние, его физический движок здесь не используется.
nonisolated struct RobotEngine {
    static let width = 12.0
    static let height = 8.0
    static let radius = 0.32
    // Расстояние между ведущими колесами. Используется для перевода разности скоростей в поворот.
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
    // Начальная точка существует всегда; это гарантирует безопасный доступ к route.last в integrate.
    private(set) var route: [Vector2]
    private var touching = false
    private var dwell = 0.0
    // Нормализованные команды [-1, 1]: throttle — вперед/назад, steering — поворот влево/вправо.
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

    /// В этой учебной модели остановка мгновенная: сбрасываем команды и обе скорости колес.
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
        // После задержки кадра не догоняем все пропущенное время резким скачком.
        // Маленькие подшаги не дают роботу перескочить через тонкую стену.
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
        // v = (vL + vR) / 2, ω = (vR - vL) / track.
        // Ограничение применяется к каждому колесу, поэтому на резком повороте скорость снижается.
        leftWheel = (forward - turn * Self.track / 2).clamped(to: -limit...limit)
        rightWheel = (forward + turn * Self.track / 2).clamped(to: -limit...limit)
        let omega = (rightWheel - leftWheel) / Self.track
        // Направление в середине подшага уменьшает погрешность движения по дуге.
        let midAngle = heading + omega * dt / 2
        let candidate = Vector2(x: position.x + speed * cos(midAngle) * dt,
                                y: position.y + speed * sin(midAngle) * dt)
        // Нормализуем угол в [-π, π], чтобы он не накапливался при длительных вращениях.
        heading = atan2(sin(heading + omega * dt), cos(heading + omega * dt))
        let hit = isBlocked(candidate)
        // Контакт блокирует перемещение, но не вращение круглой модели робота.
        // touching объединяет непрерывное давление на стену в одно касание.
        if hit {
            if !touching { collisions += 1 }
            touching = true
            if !mission.isFree && collisions > mission.collisionLimit {
                finished = true; succeeded = false; stop(); recordEndpoint(); return
            }
        } else {
            // Поворот на месте не сбрасывает контакт: новое касание возможно после отъезда.
            if abs(speed) > 0.01 { touching = false }
            distance += position.distance(to: candidate)
            position = candidate
        }
        // Прореживаем траекторию по пройденному расстоянию, а не по частоте кадров.
        if route.last!.distance(to: position) >= 0.07 { route.append(position) }
        // Проверяем только следующую точку: пересечение будущей точки заранее не засчитывается.
        if let checkpoint = nextCheckpoint, position.distance(to: checkpoint) < 0.58 {
            checkpointIndex += 1
        }
        // Финиш требует всех точек и почти полной остановки на 0,35 секунды.
        // Простой проезд через зеленую зону не завершает упражнение.
        if !mission.isFree && nextCheckpoint == nil && position.distance(to: mission.goal) < 0.58 && abs(speed) < 0.12 {
            dwell += dt
            if dwell >= 0.35 { finished = true; succeeded = true; stop(); recordEndpoint() }
        } else { dwell = 0 }
    }

    /// Финальная точка нужна на карте результата, даже если робот проехал меньше шага записи 0,07 м.
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
