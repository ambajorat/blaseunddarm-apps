import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct BDMComplicationEntry: TimelineEntry {
    let date: Date
    let todayMl: Int
    let todayCount: Int
    let todayBowel: Int
}

// MARK: - Provider

struct BDMComplicationProvider: TimelineProvider {

    func placeholder(in context: Context) -> BDMComplicationEntry {
        BDMComplicationEntry(date: Date(), todayMl: 750, todayCount: 4, todayBowel: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (BDMComplicationEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BDMComplicationEntry>) -> Void) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> BDMComplicationEntry {
        if let d = WidgetData.load() {
            return BDMComplicationEntry(date: Date(), todayMl: d.todayMl, todayCount: d.todayCount, todayBowel: d.todayBowel)
        }
        return BDMComplicationEntry(date: Date(), todayMl: 0, todayCount: 0, todayBowel: 0)
    }
}

// MARK: - View

struct BDMComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BDMComplicationEntry

    var body: some View {
        switch family {

        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 15))
                Text("\(entry.todayMl)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

        case .accessoryInline:
            // In der Zeile ist ein SF-Symbol als Bild erlaubt und wird sauber gerendert
            Label("\(entry.todayMl) ml · \(entry.todayCount)×", systemImage: "drop.fill")

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.title3)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(entry.todayMl) ml")
                        .font(.headline)
                    Text("\(entry.todayCount)× Blase · \(entry.todayBowel)× Darm")
                        .font(.caption2)
                }
            }

        case .accessoryCorner:
            Image(systemName: "drop.fill")
                .font(.title3)
                .widgetLabel("\(entry.todayMl) ml · \(entry.todayCount)×")

        @unknown default:
            Label("\(entry.todayMl) ml", systemImage: "drop.fill")
        }
    }
}

// MARK: - Widget

struct BDMComplication: Widget {
    let kind = "BDMComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BDMComplicationProvider()) { entry in
            BDMComplicationView(entry: entry)
        }
        .configurationDisplayName("Blase & Darm")
        .description("Heutige Werte direkt auf dem Zifferblatt.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular,
            .accessoryCorner
        ])
    }
}

// MARK: - Bundle

@main
struct BDMWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        BDMComplication()
    }
}
