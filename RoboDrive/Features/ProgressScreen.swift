import SwiftUI
import SwiftData

struct ProgressScreen: View {
    let missions: [Mission]
    @Query(sort: \Attempt.date, order: .reverse) private var attempts: [Attempt]
    @Environment(\.modelContext) private var context
    @State private var deleteID: UUID?
    @State private var showDeleteConfirmation = false
    @State private var deletionError: String?
    private var completed: Int { Set(attempts.filter { $0.succeeded && !$0.freeDrive }.map(\.missionID)).count }
    var body: some View {
        List {
            Section {
                HStack { Metric(title: "Заданий", value: "\(completed)/\(missions.count)"); Metric(title: "Заездов", value: String(attempts.count)); Metric(title: "Общий путь", value: String(format: "%.0f м", attempts.reduce(0) { $0 + $1.distance })) }.padding(.vertical, 10)
            }
            if attempts.isEmpty {
                ContentUnavailableView("Первый заезд впереди", systemImage: "flag.checkered", description: Text("Пройдите задание или завершите свободную практику. Результат появится здесь."))
            } else {
                Section("История заездов") {
                    ForEach(attempts) { attempt in
                        NavigationLink {
                            ScrollView { AttemptSummary(attempt: attempt, mission: originalMission(attempt)).padding() }
                                .navigationTitle("Результат").navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack {
                                Image(systemName: attempt.freeDrive ? "steeringwheel" : (attempt.succeeded ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"))
                                    .foregroundStyle(attempt.succeeded ? .green : .orange)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(attempt.missionTitle).font(.headline)
                                    Text(attempt.date, format: .dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary)
                                    Text(attempt.freeDrive ? "Свободный заезд" : (attempt.succeeded ? "Выполнено" : "Не завершено")).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(attempt.duration.driveTime).monospacedDigit().foregroundStyle(.secondary)
                            }
                        }.swipeActions { Button("Удалить", role: .destructive) { deleteID = attempt.id; showDeleteConfirmation = true } }
                    }
                }
            }
        }.navigationTitle("Прогресс")
            .confirmationDialog("Удалить этот результат?", isPresented: $showDeleteConfirmation) {
                Button("Удалить", role: .destructive) {
                    guard let record = attempts.first(where: { $0.id == deleteID }) else { return }
                    context.delete(record)
                    do { try context.save() } catch { context.rollback(); deletionError = error.localizedDescription }
                    deleteID = nil
                }
            }
            .alert("Не удалось удалить результат", isPresented: Binding(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) { Button("Понятно") { deletionError = nil } } message: { Text(deletionError ?? "") }
    }
    private func originalMission(_ attempt: Attempt) -> Mission? {
        missions.first { attempt.freeDrive ? "free-" + $0.id == attempt.missionID : $0.id == attempt.missionID }.map { attempt.freeDrive ? $0.freeVariant : $0 }
    }
}

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showTrail") private var showTrail = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("sensitivity") private var sensitivity = 1.0
    @AppStorage("appearance") private var appearance = "system"
    var body: some View {
        NavigationStack {
            Form {
                Section("Управление") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Чувствительность поворота: \(sensitivity, specifier: "%.1f")")
                        Slider(value: $sensitivity, in: 0.5...1.5, step: 0.1).accessibilityLabel("Чувствительность поворота")
                    }
                    Toggle("Вибрация при столкновении", isOn: $haptics)
                    Toggle("Показывать траекторию", isOn: $showTrail)
                }
                Section("Оформление") {
                    Picker("Тема", selection: $appearance) { Text("Системная").tag("system"); Text("Светлая").tag("light"); Text("Темная").tag("dark") }
                }
                Section("О тренажере") {
                    Text("RoboDrive").font(.headline)
                    Text("Учебная модель колесного робота. Движение рассчитывается без проскальзывания и инерции. Все задания и результаты доступны без интернета.").font(.subheadline).foregroundStyle(.secondary)
                    Text("Чалов Дмитрий Максимович · 251-325").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Настройки").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }
}
