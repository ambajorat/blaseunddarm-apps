import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes

struct ToiletTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startTime: Date
        var intervalMinutes: Int
        var todayMl: Int
        var todayCount: Int
        /// Körperliche Fälligkeit (Eintrag + Intervall, UNVERSCHOBEN) —
        /// identisch mit Header und Widget.
        var dueDate: Date
        /// Gesetzt, wenn die Fälligkeit in die Ruhezeit fällt: Ende der Ruhezeit.
        /// Zwischen dueDate und quietEnd zeigt die Anzeige "Ruhezeit" statt rot.
        var quietEnd: Date?
    }
}

// Markenfarbe (Akzent) an einer Stelle
private let bdmAccent = Color(red: 0.91, green: 0.57, blue: 0.23)

// MARK: - Live Activity Views

struct ToiletTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ToiletTimerAttributes.self) { context in
            // Lock Screen / Banner view
            let due = context.state.dueDate
            let quietEnd = context.state.quietEnd
            // +1 s Toleranz: das staleDate-Re-Rendering feuert oft Millisekunden
            // VOR dem Zielzeitpunkt — ohne Toleranz friert der Snapshot im alten
            // Zustand ein (orange trotz überfällig). context.isStale bestätigt
            // zusätzlich explizit den erreichten Wechselpunkt (Fix14).
            let now = Date.now.addingTimeInterval(1)
            // dueDate ist seit Fix15 die RUHEZEITBEWUSSTE Fälligkeit — dieselbe
            // Zahl wie im App-Header. isStale taugt mit zwei Wechselpunkten
            // (rohe Fälligkeit -> Mond, Ruhe-Ende -> rot) nicht mehr als
            // Erreicht-Signal; die 1-s-Toleranz auf now trägt allein (Fix14/15).
            let reached = due <= now
            let physDue = context.state.startTime.addingTimeInterval(TimeInterval(context.state.intervalMinutes * 60))
            let inQuietWindow = !reached && quietEnd != nil && physDue <= now
            let overdue = reached
            // Ab wann "überfällig" zählt: nach Ruhezeit ab deren Ende, sonst ab Fälligkeit
            let overdueAnchor = quietEnd ?? due

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blase & Darm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if inQuietWindow, let quietEnd {
                        Label("Ruhezeit", systemImage: "moon.fill")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(quietEnd, style: .timer)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } else if overdue {
                        Text("Überfällig")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text(overdueAnchor, style: .timer)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                    } else {
                        Text(due, style: .timer)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(bdmAccent)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(context.state.todayMl) ml")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(overdue ? .red : bdmAccent)
                    Text("\(context.state.todayCount) Einträge")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.08, green: 0.08, blue: 0.08))

        } dynamicIsland: { context in
            let due = context.state.dueDate
            let quietEnd = context.state.quietEnd
            // +1 s Toleranz: das staleDate-Re-Rendering feuert oft Millisekunden
            // VOR dem Zielzeitpunkt — ohne Toleranz friert der Snapshot im alten
            // Zustand ein (orange trotz überfällig). context.isStale bestätigt
            // zusätzlich explizit den erreichten Wechselpunkt (Fix14).
            let now = Date.now.addingTimeInterval(1)
            // dueDate ist seit Fix15 die RUHEZEITBEWUSSTE Fälligkeit — dieselbe
            // Zahl wie im App-Header. isStale taugt mit zwei Wechselpunkten
            // (rohe Fälligkeit -> Mond, Ruhe-Ende -> rot) nicht mehr als
            // Erreicht-Signal; die 1-s-Toleranz auf now trägt allein (Fix14/15).
            let reached = due <= now
            let physDue = context.state.startTime.addingTimeInterval(TimeInterval(context.state.intervalMinutes * 60))
            let inQuietWindow = !reached && quietEnd != nil && physDue <= now
            let overdue = reached

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("Blase & Darm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if inQuietWindow, let quietEnd {
                            Label("Ruhezeit", systemImage: "moon.fill")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(quietEnd, style: .timer)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        } else if overdue {
                            Text("Überfällig")
                                .font(.headline)
                                .foregroundStyle(.red)
                        } else {
                            Text(due, style: .timer)
                                .font(.title2.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(bdmAccent)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("\(context.state.todayMl) ml")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(overdue ? .red : bdmAccent)
                        Text("\(context.state.todayCount)×")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: inQuietWindow ? "moon.fill" : "drop.fill")
                    .foregroundStyle(inQuietWindow ? Color.secondary : (overdue ? Color.red : bdmAccent))
            } compactTrailing: {
                if inQuietWindow, let quietEnd {
                    Text(quietEnd, style: .timer)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else if overdue {
                    Text("!")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                } else {
                    Text(due, style: .timer)
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(bdmAccent)
                }
            } minimal: {
                Image(systemName: inQuietWindow ? "moon.fill" : "drop.fill")
                    .foregroundStyle(inQuietWindow ? Color.secondary : (overdue ? Color.red : bdmAccent))
            }
        }
    }
}
