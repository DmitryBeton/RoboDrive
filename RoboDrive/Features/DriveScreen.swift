import SwiftUI
import SwiftData
import SpriteKit

/// Полноэкранный заезд: владеет сеансом, показывает полигон или результат и сохраняет попытку.
struct DriveScreen: View {
    let mission: Mission
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("sensitivity") private var sensitivity = 1.0
    @AppStorage("showTrail") private var showTrail = true
    @AppStorage("haptics") private var haptics = true
    @State private var session: DriveSession?
    @State private var attempt: Attempt?
    @State private var saved = false
    @State private var saveError: String?
    @State private var confirmExit = false

    var body: some View {
        Group {
            if let session {
                if session.phase == .finished, let attempt {
                    NavigationStack {
                        ScrollView {
                            VStack(spacing: 24) {
                                AttemptSummary(attempt: attempt, mission: mission)
                                if let saveError {
                                    Label("Результат не сохранен: \(saveError)", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                                    Button("Повторить сохранение") { save(session) }
                                } else if saved { Label("Результат сохранен на устройстве", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary) }
                                PrimaryButton(title: "Повторить заезд", symbol: "arrow.counterclockwise") { restart() }
                                Button("К заданиям") { dismiss() }.padding(.bottom)
                            }.padding().frame(maxWidth: 700)
                        }.frame(maxWidth: .infinity).background(Color(.systemGroupedBackground)).navigationTitle("Результат").navigationBarTitleDisplayMode(.inline)
                    }
                } else { simulator(session) }
            } else { ProgressView("Подготовка полигона") }
        }
        .task { if session == nil { restart() } }
        .onChange(of: session?.phase) { _, phase in
            if phase == .finished, let session { save(session) }
        }
        // Потеря активности (например, открытие системного экрана) немедленно ставит заезд на паузу.
        .onChange(of: scenePhase) { _, phase in if phase != .active { session?.pause() } }
        .onDisappear { session?.stop(); session?.scene.isPaused = true }
        .confirmationDialog("Выйти из заезда? Текущая попытка не сохранится.", isPresented: $confirmExit) {
            Button("Выйти", role: .destructive) { dismiss() }
            Button("Остаться", role: .cancel) { }
        }
    }

    private func simulator(_ session: DriveSession) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                HStack {
                    Button { session.pause(); confirmExit = true } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Выйти из заезда")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mission.title).font(.headline)
                        Text(mission.isFree ? "Свободный заезд" : "Точки: \(session.checkpoint)/\(mission.checkpoints.count)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(session.elapsed.driveTime).monospacedDigit().font(.headline)
                    Button { session.pause() } label: { Image(systemName: "pause.fill").frame(width: 44, height: 44) }.accessibilityLabel("Пауза").disabled(session.phase != .driving)
                }
                // В горизонтальном режиме управление находится справа, в вертикальном — под полигоном.
                if geometry.size.width > geometry.size.height {
                    HStack(spacing: 16) {
                        arena(session)
                        controls(session, compact: true).frame(width: min(250, geometry.size.width * 0.3))
                    }
                } else {
                    arena(session)
                    controls(session, compact: false)
                }
            }.padding(12)
        }.background(Color(.systemGroupedBackground))
    }

    private func arena(_ session: DriveSession) -> some View {
        ZStack {
            Color(red: 0.09, green: 0.13, blue: 0.19)
            SpriteView(scene: session.scene, isPaused: session.phase != .driving, preferredFramesPerSecond: 60)
                .aspectRatio(1.5, contentMode: .fit)
                .accessibilityLabel("Полигон с роботом. Используйте джойстик для движения.")
            if session.phase == .ready || session.phase == .paused {
                VStack(spacing: 16) {
                    Image(systemName: session.phase == .ready ? "steeringwheel" : "pause.circle").font(.largeTitle)
                    Text(session.phase == .ready ? "Готовы к заезду?" : "Пауза").font(.title2.bold())
                    Text(session.phase == .ready ? "Вверх — вперед. В сторону — поворот. Отпустите джойстик для остановки." : "Управление остановлено.")
                        .font(.subheadline).multilineTextAlignment(.center)
                    Button(session.phase == .ready ? "Поехали" : "Продолжить") {
                        if session.phase == .ready { session.begin() } else { session.resume() }
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                    if mission.isFree && session.phase == .paused {
                        Button("Завершить и сохранить") { session.finishFreeDrive() }
                    }
                }.padding(22).frame(maxWidth: 340).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24)).padding(12)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 20)).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controls(_ session: DriveSession, compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 12) {
            HStack {
                Label("\(session.collisions)" + (mission.isFree ? " касаний" : " / \(mission.collisionLimit) касаний"), systemImage: "shield")
                Spacer()
                Text(String(format: "%.1f м", session.distance))
            }.font(.caption).foregroundStyle(.secondary).monospacedDigit()
            HStack(spacing: 20) {
                Joystick { x, y in session.control(x: x, y: y) }
                    // Смена фазы сбрасывает локальное положение ручки и состояние активного жеста.
                    .id(session.phase).disabled(session.phase != .driving)
                if !compact {
                    VStack(spacing: 12) {
                        stopButton(session)
                        Button { session.showData.toggle() } label: { Label("Данные", systemImage: "gauge.with.dots.needle.50percent") }.font(.subheadline)
                    }.frame(maxWidth: .infinity)
                }
            }
            if compact { stopButton(session) }
            VStack(spacing: 2) {
                HStack { Text("Максимальная скорость"); Spacer(); Text(String(format: "%.1f м/с", session.speedLimit)).monospacedDigit() }.font(.caption)
                Slider(value: Binding(get: { session.speedLimit }, set: { session.speedLimit = $0 }), in: 0.3...2, step: 0.1).accessibilityLabel("Максимальная скорость")
            }
            if session.showData && !compact {
                HStack { Text(String(format: "Левое: %+.2f м/с", session.leftWheel)); Spacer(); Text(String(format: "Правое: %+.2f м/с", session.rightWheel)) }.font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }
    private func stopButton(_ session: DriveSession) -> some View {
        Button { session.stop() } label: { Label("Стоп", systemImage: "stop.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8) }
            .buttonStyle(.borderedProminent).tint(.red).disabled(session.phase != .driving)
    }
    /// Новый сеанс сбрасывает таймер, маршрут и сцену. Несохраненную запись старой попытки удаляем из context.
    private func restart() {
        session?.stop(); session?.scene.isPaused = true
        if let attempt, !saved { context.delete(attempt) }
        attempt = nil; saved = false; saveError = nil
        session = DriveSession(mission: mission, sensitivity: sensitivity, showTrail: showTrail, haptics: haptics)
    }
    /// Вставка выполняется один раз. При ошибке повторно сохраняем ту же запись, не дублируя результат.
    private func save(_ session: DriveSession) {
        guard !saved else { return }
        if attempt == nil {
            let record = Attempt(id: session.id, engine: session.engine)
            context.insert(record); attempt = record
        }
        do { try context.save(); saved = true; saveError = nil }
        catch { saveError = error.localizedDescription }
    }
}

/// Переводит смещение пальца в две команды модели. Отпускание всегда обнуляет управление.
private struct Joystick: View {
    let control: (Double, Double) -> Void
    @State private var offset = CGSize.zero
    @State private var accessibilityThrottle = 0.0
    private let radius = 48.0
    var body: some View {
        ZStack {
            Circle().fill(.blue.opacity(0.07))
            Circle().stroke(.blue.opacity(0.16), lineWidth: 1).padding(14)
            Image(systemName: "plus").font(.title3).foregroundStyle(.blue.opacity(0.25))
            Circle().fill(.blue.gradient).frame(width: 54, height: 54)
                .shadow(color: .blue.opacity(0.22), radius: 10, y: 5).offset(offset)
        }.frame(width: 150, height: 150).contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let dx = value.translation.width, dy = value.translation.height
                // Ограничиваем ручку окружностью, сохраняя направление диагонального отклонения.
                let length = max(hypot(dx, dy), radius)
                offset = CGSize(width: dx / length * radius, height: dy / length * radius)
                let x = Double(offset.width) / radius, y = -Double(offset.height) / radius
                // В SwiftUI Y растет вниз, а положительный steering модели поворачивает влево.
                // Небольшая мертвая зона подавляет случайное движение около центра.
                control(abs(x) < 0.08 ? 0 : -x, abs(y) < 0.08 ? 0 : y)
            }.onEnded { _ in offset = .zero; control(0, 0) })
            .accessibilityElement().accessibilityLabel("Джойстик")
            .accessibilityHint("Смахните вверх или вниз для изменения скорости. Действия позволяют поворачивать и остановиться.")
            .accessibilityAdjustableAction { direction in
                accessibilityThrottle = (accessibilityThrottle + (direction == .increment ? 0.25 : -0.25)).clamped(to: -1...1)
                control(0, accessibilityThrottle)
            }
            .accessibilityAction(named: "Поворот налево") { control(0.5, accessibilityThrottle) }
            .accessibilityAction(named: "Поворот направо") { control(-0.5, accessibilityThrottle) }
            .accessibilityAction(named: "Остановиться") { accessibilityThrottle = 0; control(0, 0) }
            .onDisappear { control(0, 0) }
    }
}
