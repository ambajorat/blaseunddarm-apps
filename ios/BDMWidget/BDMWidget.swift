import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct BDMProvider: TimelineProvider {
    func placeholder(in context: Context) -> BDMEntry {
        BDMEntry(date: .now, data: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BDMEntry) -> Void) {
        completion(BDMEntry(date: .now, data: WidgetData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BDMEntry>) -> Void) {
        let data = WidgetData.load()
        let entry = BDMEntry(date: .now, data: data)
        // Update every 5 minutes
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Timeline Entry

struct BDMEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?

    var timeRemaining: Int? {
        guard let data, let last = data.lastEntryDate, data.reminderEnabled else { return nil }
        let elapsed = Int(date.timeIntervalSince(last))
        let remaining = (data.intervalMinutes * 60) - elapsed
        return remaining
    }

    var dueDate: Date? {
        guard let data, let last = data.lastEntryDate, data.reminderEnabled else { return nil }
        return last.addingTimeInterval(TimeInterval(data.intervalMinutes * 60))
    }

    var isInQuietHours: Bool {
        guard let data, data.quietHoursEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        if data.quietFrom < data.quietTo {
            return hour >= data.quietFrom && hour < data.quietTo
        } else {
            return hour >= data.quietFrom || hour < data.quietTo
        }
    }
}

// MARK: - Small Widget View

struct BDMWidgetSmallView: View {
    let entry: BDMEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Timer
            if let remaining = entry.timeRemaining {
                if entry.isInQuietHours {
                    Label("Ruhezeit", systemImage: "moon.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else if remaining <= 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text("Überfällig")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.red)
                    if let due = entry.dueDate {
                        Text(due, style: .relative)
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("Nächste")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let due = entry.dueDate {
                        Text(due, style: .timer)
                            .font(.title.weight(.bold).monospacedDigit())
                            .foregroundStyle(Color(red: 0.91, green: 0.57, blue: 0.23))
                    }
                }
            }

            Spacer()

            // Today summary
            if let data = entry.data {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(data.todayMl)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(red: 0.91, green: 0.57, blue: 0.23))
                        Text("ml")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(data.todayBowel)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(red: 0.70, green: 0.55, blue: 0.85))
                        Text("Stuhl")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(data.todayCount)")
                            .font(.subheadline.weight(.bold))
                        Text("Eintr.")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(red: 0.08, green: 0.08, blue: 0.08)
        }
    }
}

// MARK: - Medium Widget View

struct BDMWidgetMediumView: View {
    let entry: BDMEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Timer
            VStack(alignment: .leading, spacing: 4) {
                Text("Blase & Darm")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let remaining = entry.timeRemaining {
                    if entry.isInQuietHours {
                        Image(systemName: "moon.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Ruhezeit")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else if remaining <= 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                        if let due = entry.dueDate {
                            Text(due, style: .relative)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.red)
                            Text("überfällig")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    } else {
                        if let due = entry.dueDate {
                            Text(due, style: .timer)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Color(red: 0.91, green: 0.57, blue: 0.23))
                        }
                        Text("Nächste Erinnerung")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Right: Today stats
            if let data = entry.data {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Heute")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    statRow(value: "\(data.todayMl) ml", label: "Urin", color: Color(red: 0.91, green: 0.57, blue: 0.23))
                    statRow(value: "\(data.todayBowel)×", label: "Stuhl", color: Color(red: 0.70, green: 0.55, blue: 0.85))
                    statRow(value: "\(data.todayCount)", label: "Einträge", color: .primary)

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(red: 0.08, green: 0.08, blue: 0.08)
        }
    }

    private func statRow(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget Configuration

struct BDMWidget: Widget {
    let kind = "BDMWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BDMProvider()) { entry in
            if #available(iOS 17.0, *) {
                BDMWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Blase & Darm")
        .description("Timer und Tagesübersicht")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BDMWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: BDMEntry

    var body: some View {
        switch family {
        case .systemMedium:
            BDMWidgetMediumView(entry: entry)
        default:
            BDMWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct BDMWidgetBundle: WidgetBundle {
    var body: some Widget {
        BDMWidget()
        ToiletTimerLiveActivity()
    }
}
