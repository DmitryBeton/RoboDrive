import SwiftUI

extension Double {
    var driveTime: String { String(format: "%02d:%02d", Int(max(0, self)) / 60, Int(max(0, self)) % 60) }
}

/// Статическая карта для описания задания и истории. Симуляция здесь не запускается.
struct RouteMap: View {
    let mission: Mission
    var route: [Vector2] = []
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 12, size.height / 8)
            let offset = CGPoint(x: (size.width - 12 * scale) / 2, y: (size.height - 8 * scale) / 2)
            // Canvas отсчитывает Y сверху, модель — снизу; переворачиваем только координату отображения.
            func p(_ v: Vector2) -> CGPoint { CGPoint(x: offset.x + v.x * scale, y: offset.y + (8 - v.y) * scale) }
            var grid = Path()
            for x in 0...12 { grid.move(to: p(Vector2(x: Double(x), y: 0))); grid.addLine(to: p(Vector2(x: Double(x), y: 8))) }
            for y in 0...8 { grid.move(to: p(Vector2(x: 0, y: Double(y)))); grid.addLine(to: p(Vector2(x: 12, y: Double(y)))) }
            context.stroke(grid, with: .color(.white.opacity(0.07)), lineWidth: 0.5)
            for wall in mission.barriers {
                let center = p(Vector2(x: wall.x, y: wall.y))
                let rect = CGRect(x: center.x - wall.width * scale / 2, y: center.y - wall.height * scale / 2, width: wall.width * scale, height: wall.height * scale)
                context.fill(wall.round ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 3), with: .color(.gray.opacity(0.65)))
            }
            for point in mission.checkpoints {
                let center = p(point)
                context.stroke(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(.orange), lineWidth: 1.5)
            }
            if !mission.isFree {
            let goal = p(mission.goal)
            let rect = CGRect(x: goal.x - 0.58 * scale, y: goal.y - 0.58 * scale, width: 1.16 * scale, height: 1.16 * scale)
            context.fill(Path(ellipseIn: rect), with: .color(.green.opacity(0.25)))
            context.stroke(Path(ellipseIn: rect), with: .color(.green), lineWidth: 1.5)
            }
            if route.count > 1 {
                var line = Path(); line.move(to: p(route[0]))
                for point in route.dropFirst() { line.addLine(to: p(point)) }
                context.stroke(line, with: .color(.cyan), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            let start = p(route.last ?? mission.start)
            context.fill(Path(roundedRect: CGRect(x: start.x - 5, y: start.y - 4, width: 10, height: 8), cornerRadius: 2), with: .color(.blue))
        }
        .background(Color(red: 0.09, green: 0.13, blue: 0.19))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .aspectRatio(1.5, contentMode: .fit)
        .accessibilityLabel(route.isEmpty ? "Схема полигона: \(mission.title)" : "Пройденная траектория на полигоне \(mission.title)")
    }
}

struct Metric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrimaryButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: symbol).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 9) }
            .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 16))
    }
}

/// Общая сводка для только что завершенного заезда и ранее сохраненной попытки.
struct AttemptSummary: View {
    let attempt: Attempt
    let mission: Mission?
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: attempt.freeDrive ? "steeringwheel" : (attempt.succeeded ? "checkmark.seal.fill" : "arrow.counterclockwise.circle.fill"))
                    .font(.system(size: 42)).foregroundStyle(attempt.succeeded ? .green : .orange)
                Text(attempt.freeDrive ? "Практика завершена" : (attempt.succeeded ? "Задание выполнено" : "Попробуем еще раз"))
                    .font(.largeTitle.bold())
                Text(attempt.missionTitle).font(.title3).foregroundStyle(.secondary)
            }
            if let mission { RouteMap(mission: mission, route: attempt.route) }
            HStack {
                Metric(title: "Время", value: attempt.duration.driveTime)
                Metric(title: "Путь", value: String(format: "%.1f м", attempt.distance))
                Metric(title: "Касания", value: String(attempt.collisions))
            }
            Label(attempt.collisions > 0 ? "Снижайте скорость перед препятствиями и корректируйте направление заранее." : "Хорошая точность. В следующей попытке попробуйте пройти маршрут плавнее.", systemImage: "lightbulb")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
