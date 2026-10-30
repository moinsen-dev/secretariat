import Charts
import SwiftUI
import SecretariatCore

extension AppModel {
    /// Applies the retention setting and reads this Mac's history off the main thread; reading never changes the file.
    /// Switching retention only saves the setting here; the deletion itself runs in `loadHistory`, off the main thread.
    func loadHistory() {
        let paths = paths
        Task {
            let entries = await Task.detached { () -> [HistoryEntry] in
                let vault = Vault(paths: paths); vault.pruneHistory(); return vault.audit.entries()
            }.value
            history = entries
        }
    }

    func setHistoryRetention(_ on: Bool) {
        if perform({ try vault.setHistoryRetention(days: on ? 30 : nil) }) { loadHistory() }
    }
}

extension Origin.Kind {
    var symbol: String {
        switch self {
        case .app: "macwindow"
        case .person: "person"
        case .agent: "sparkles"
        case .mcp: "point.3.connected.trianglepath.dotted"
        case .script: "terminal"
        case .earlier: "clock"
        }
    }
}

// MARK: - Middle column: period, chart, origins, retention

struct HistorySummary: View {
    @Bindable var model: AppModel
    static let palette: [Color] = [.blue, .orange, .green, .pink, .purple, .teal, .yellow, .red, .brown, .indigo]
    /// The origin list is the chart's legend: same order, same colors.
    static func color(_ via: String, _ origins: [(via: String, count: Int)]) -> Color {
        palette[(origins.firstIndex { $0.via == via } ?? 0) % palette.count]
    }

    private var selected: [HistoryEntry] { History.select(model.history, model.historyPeriod) }

    var body: some View {
        let entries = selected
        let shown = model.historyVia.map { via in entries.filter { $0.via == via } } ?? entries
        let origins = History.origins(entries)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Period", selection: $model.historyPeriod) {
                    ForEach(HistoryPeriod.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(shown.count)").font(.system(size: 34, weight: .semibold)).monospacedDigit()
                    Text(shown.count == 1 ? "access in the last \(model.historyPeriod.title.lowercased())" : "accesses in the last \(model.historyPeriod.title.lowercased())")
                        .foregroundStyle(.secondary)
                }

                Chart(History.buckets(shown, model.historyPeriod)) { bucket in
                    BarMark(x: .value("Time", bucket.start, unit: model.historyPeriod.bucket), y: .value("Accesses", bucket.count))
                        .foregroundStyle(by: .value("Origin", Origin.title(bucket.via)))
                }
                .chartXScale(domain: model.historyPeriod.start(now: Date())...Date())
                .chartForegroundStyleScale(domain: origins.map { Origin.title($0.via) }, range: origins.map { Self.color($0.via, origins) })
                .chartLegend(.hidden)
                .frame(height: 170)
                .accessibilityLabel("Accesses over the last \(model.historyPeriod.title.lowercased()), by origin")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Origin").font(.headline)
                    if entries.isEmpty { Text("Nothing in this period.").foregroundStyle(.secondary) }
                    ForEach(origins, id: \.via) { origin in
                        Button {
                            model.historyVia = model.historyVia == origin.via ? nil : origin.via
                        } label: {
                            HStack {
                                Circle().fill(Self.color(origin.via, origins)).frame(width: 8, height: 8)
                                Label(Origin.title(origin.via), systemImage: Origin.kind(origin.via).symbol)
                                Spacer()
                                Text("\(origin.count)").monospacedDigit().foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6).padding(.horizontal, 10)
                            .background(model.historyVia == origin.via ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(Origin.title(origin.via)), \(origin.count)")
                        .accessibilityAddTraits(model.historyVia == origin.via ? .isSelected : [])
                    }
                    if model.historyVia != nil { Button("Show all origins") { model.historyVia = nil }.controlSize(.small) }
                }
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Delete entries older than 30 days", isOn: SwiftUI.Binding(
                    get: { model.configuration.historyRetentionDays != nil }, set: { model.setHistoryRetention($0) }))
                Text("Only this Mac's history. The origin is what the calling program reports; an agent can hide it. Names only, never values.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(.bar)
        }
        .navigationTitle("History")
        .navigationSubtitle(model.historyVia.map(Origin.title) ?? "All origins")
        .task { model.loadHistory() }
    }
}

// MARK: - Detail column: the entries

struct HistoryList: View {
    let model: AppModel

    var body: some View {
        let entries = History.select(model.history, model.historyPeriod, via: model.historyVia)
        List {
            ForEach(entries.prefix(1000)) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: Origin.kind(entry.via).symbol).foregroundStyle(.secondary).frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.summary).lineLimit(2)
                        Text("\(Origin.title(entry.via)) · \(entry.at.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            if entries.count > 1000 {
                Text("Showing the newest 1,000 of \(entries.count). Choose a shorter period or one origin.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("No Accesses", systemImage: "clock.arrow.circlepath",
                                       description: Text("Nothing used Secretariat in this period."))
            }
        }
    }
}

