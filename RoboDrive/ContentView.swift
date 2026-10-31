import SwiftUI
import SwiftData

/// Корень навигации: практика, свободный режим и история.
/// Каталог общий для вкладок, а каждый открытый заезд получает собственный DriveRequest.
struct ContentView: View {
    @Query(sort: \Attempt.date, order: .reverse) private var attempts: [Attempt]
    @State private var missions: [Mission] = []
    @State private var loadError: String?
    @State private var settings = false
    @State private var selection = 0
    @State private var freeMission = "first-drive"
    @State private var request: DriveRequest?
    @AppStorage("lastMission") private var lastMission = "first-drive"

    // Свободные и неуспешные попытки не увеличивают число пройденных учебных заданий.
    private var completed: Set<String> { Set(attempts.filter { $0.succeeded && !$0.freeDrive }.map(\.missionID)) }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("ROBOT CONTROL SIMULATOR", systemImage: "steeringwheel").font(.caption.weight(.semibold)).foregroundStyle(.blue)
                            Text("Почувствуй\nдвижение робота").font(.largeTitle.bold())
                            Text("Пять заданий. Два колеса. Полный контроль.").foregroundStyle(.secondary)
                            ProgressView(value: Double(completed.count), total: Double(max(1, missions.count))).tint(.blue)
                            Text("Пройдено \(completed.count) из \(missions.count)").font(.caption).foregroundStyle(.secondary)
                        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
                        if let next = missions.first(where: { $0.id == lastMission && !completed.contains($0.id) }) ?? missions.first(where: { !completed.contains($0.id) }) {
                            PrimaryButton(title: "Продолжить практику", symbol: "play.fill") { start(next) }
                        }
                        Text("Учебные задания").font(.title2.bold())
                        ForEach(missions) { mission in
                            NavigationLink { MissionDetail(mission: mission, best: best(for: mission)) { start(mission) } } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: mission.symbol).font(.title2).foregroundStyle(.blue).frame(width: 42)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(mission.title).font(.headline).foregroundStyle(.primary)
                                        Text(mission.subtitle).font(.subheadline).foregroundStyle(.secondary)
                                        Text(mission.difficulty).font(.caption).foregroundStyle(.blue)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: completed.contains(mission.id) ? "checkmark.circle.fill" : "chevron.right")
                                        .foregroundStyle(completed.contains(mission.id) ? .green : .secondary)
                                }.padding(18).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                            }.buttonStyle(.plain)
                        }
                        if let loadError { ContentUnavailableView("Задания недоступны", systemImage: "exclamationmark.triangle", description: Text(loadError)) }
                    }.padding()
                }.background(Color(.systemGroupedBackground))
                    .navigationTitle("RoboDrive")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Настройки", systemImage: "gearshape") { settings = true } } }
            }.tabItem { Label("Практика", systemImage: "square.grid.2x2") }.tag(0)
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Своя скорость.\nСвой маршрут.").font(.largeTitle.bold())
                        Text("Исследуйте движение без ограничений по времени и столкновениям.").foregroundStyle(.secondary)
                        Picker("Полигон", selection: $freeMission) { ForEach(missions) { Text($0.title).tag($0.id) } }.pickerStyle(.menu)
                        if let mission = missions.first(where: { $0.id == freeMission }) {
                            RouteMap(mission: mission.freeVariant)
                            Text(mission.subtitle).font(.title3.weight(.semibold))
                            Label("Завершите заезд вручную, чтобы сохранить траекторию и результат.", systemImage: "info.circle").font(.subheadline).foregroundStyle(.secondary)
                            PrimaryButton(title: "Начать свободный заезд", symbol: "steeringwheel") { request = DriveRequest(mission: mission.freeVariant) }
                        }
                    }.padding()
                }.background(Color(.systemGroupedBackground)).navigationTitle("Свободный режим")
            }.tabItem { Label("Свободный режим", systemImage: "steeringwheel") }.tag(1)
            NavigationStack { ProgressScreen(missions: missions) }
                .tabItem { Label("Прогресс", systemImage: "chart.xyaxis.line") }.tag(2)
        }
        .sheet(isPresented: $settings) { SettingsScreen() }
        .fullScreenCover(item: $request) { request in DriveScreen(mission: request.mission) }
        .task {
            do { missions = try MissionCatalog.load() }
            catch { loadError = "Не удалось прочитать встроенные полигоны. \(error.localizedDescription)" }
        }
    }
    /// Сначала сравниваем точность (касания), затем время. Это же правило используется в подписи результата.
    private func best(for mission: Mission) -> Attempt? {
        attempts.filter { $0.missionID == mission.id && $0.succeeded }.min { ($0.collisions, $0.duration) < ($1.collisions, $1.duration) }
    }
    private func start(_ mission: Mission) { lastMission = mission.id; request = DriveRequest(mission: mission) }
}

/// Новый UUID позволяет повторно открыть то же упражнение как независимый полноэкранный заезд.
struct DriveRequest: Identifiable { let id = UUID(); let mission: Mission }

struct MissionDetail: View {
    let mission: Mission
    let best: Attempt?
    let start: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RouteMap(mission: mission)
                Text(mission.subtitle).font(.title2.bold())
                Text(mission.lesson).font(.body)
                Label(mission.collisionLimit == 0 ? "Без столкновений" : "Допустимо касаний: \(mission.collisionLimit)", systemImage: "shield.checkered").foregroundStyle(.secondary)
                Label("Остановитесь в зоне финиша после всех контрольных точек.", systemImage: "flag.checkered").foregroundStyle(.secondary)
                if let best { HStack { Metric(title: "Лучшее время*", value: best.duration.driveTime); Metric(title: "Касания", value: String(best.collisions)) }; Text("* Среди попыток с наименьшим числом касаний.").font(.caption).foregroundStyle(.secondary) }
                PrimaryButton(title: "Начать задание", symbol: "play.fill", action: start)
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle(mission.title).navigationBarTitleDisplayMode(.inline)
    }
}
