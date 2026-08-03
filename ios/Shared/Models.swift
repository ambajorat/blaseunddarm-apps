import Foundation

enum UrineColor: String, Codable, CaseIterable, Identifiable {
    case none = "keine Angabe"
    case clear = "Durchsichtig"
    case lightYellow = "Hell gelb"
    case darkYellow = "Dunkel gelb"
    case cloudy = "Trüb"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .none: "⚪️"
        case .clear: "💧"
        case .lightYellow: "🟡"
        case .darkYellow: "🟠"
        case .cloudy: "🌫️"
        }
    }

    var localizedName: String {
        switch self {
        case .none: String(localized: "color_none")
        case .clear: String(localized: "color_clear")
        case .lightYellow: String(localized: "color_light")
        case .darkYellow: String(localized: "color_dark")
        case .cloudy: String(localized: "color_cloudy")
        }
    }
}

enum BristolType: Int, Codable, CaseIterable, Identifiable {
    case none = 0
    case type1 = 1
    case type2 = 2
    case type3 = 3
    case type4 = 4
    case type5 = 5
    case type6 = 6
    case type7 = 7

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: "Keine Angabe"
        case .type1: "Typ 1"
        case .type2: "Typ 2"
        case .type3: "Typ 3"
        case .type4: "Typ 4"
        case .type5: "Typ 5"
        case .type6: "Typ 6"
        case .type7: "Typ 7"
        }
    }

    var emoji: String {
        switch self {
        case .none: "⚪️"
        case .type1: "🫘"
        case .type2: "🥜"
        case .type3: "🌽"
        case .type4: "🍌"
        case .type5: "🫐"
        case .type6: "🍲"
        case .type7: "💧"
        }
    }

    var shortDesc: String {
        switch self {
        case .none: ""
        case .type1: "Einzelne harte Klumpen"
        case .type2: "Wurstartig, klumpig"
        case .type3: "Wurstartig, rissig"
        case .type4: "Glatt, weich"
        case .type5: "Weiche Klümpchen"
        case .type6: "Breiig, aufgelöst"
        case .type7: "Wässrig, flüssig"
        }
    }

    var detail: String {
        switch self {
        case .none: ""
        case .type1: "Einzelne, harte Klumpen wie Nüsse. Schwer auszuscheiden. Zeichen für starke Verstopfung."
        case .type2: "Wurstartig, aber klumpig. Zeichen für leichte Verstopfung."
        case .type3: "Wie eine Wurst mit Rissen an der Oberfläche. Normal."
        case .type4: "Wie eine Wurst oder Schlange, glatt und weich. Ideale Form."
        case .type5: "Weiche Klümpchen mit klaren Rändern. Neigung zu Durchfall."
        case .type6: "Breiige Konsistenz mit unscharfen Rändern. Leichter Durchfall."
        case .type7: "Wässrig, keine festen Bestandteile. Starker Durchfall."
        }
    }

    var category: String {
        switch self {
        case .none: ""
        case .type1, .type2: "Verstopfung"
        case .type3, .type4: "Normal"
        case .type5, .type6, .type7: "Durchfall"
        }
    }
}

struct ToiletEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var timestamp: Date
    var urineMl: Int
    var bowel: Bool
    var bristolType: BristolType
    var urineColor: UrineColor
    var note: String

    init(id: UUID = UUID(), timestamp: Date = .now, urineMl: Int = 0, bowel: Bool = false, bristolType: BristolType = .none, urineColor: UrineColor = .none, note: String = "") {
        self.id = id
        self.timestamp = timestamp
        self.urineMl = urineMl
        self.bowel = bowel
        self.bristolType = bristolType
        self.urineColor = urineColor
        self.note = note
    }

    var dateKey: String {
        timestamp.formatted(.iso8601.year().month().day())
    }
}

struct AppSettings: Codable, Equatable {
    var reminderEnabled: Bool = true
    var intervalMinutes: Int = 210
    var quickValues: [Int] = [100, 200, 300, 400, 500]
    var quietHoursEnabled: Bool = true
    var quietFrom: Int = 22  // Stunde (0-23)
    var quietTo: Int = 6     // Stunde (0-23)

    var isInQuietHours: Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        if quietFrom < quietTo {
            return hour >= quietFrom && hour < quietTo
        } else {
            // Über Mitternacht: z.B. 22-6
            return hour >= quietFrom || hour < quietTo
        }
    }

    static let intervals: [(label: String, minutes: Int)] = [
        ("1 Std", 60),
        ("1,5 Std", 90),
        ("2 Std", 120),
        ("2,5 Std", 150),
        ("3 Std", 180),
        ("3,5 Std", 210),
        ("4 Std", 240),
    ]
}

// MARK: - Grouping & Stats

struct DaySummary: Identifiable {
    let id: String // date key
    let date: Date
    let entries: [ToiletEntry]

    var totalMl: Int { entries.reduce(0) { $0 + $1.urineMl } }
    var count: Int { entries.count }
    var bowelCount: Int { entries.filter(\.bowel).count }
}

extension Array where Element == ToiletEntry {
    func grouped() -> [DaySummary] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: self) { entry in
            cal.startOfDay(for: entry.timestamp)
        }
        return grouped.map { date, entries in
            DaySummary(
                id: date.formatted(.iso8601.year().month().day()),
                date: date,
                entries: entries.sorted { $0.timestamp > $1.timestamp }
            )
        }
        .sorted { $0.date > $1.date }
    }

    func summariesForRange(days: Int) -> [DaySummary] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let actualDays: Int
        if days >= 9999, let oldest = self.min(by: { $0.timestamp < $1.timestamp }) {
            actualDays = Swift.max(1, (cal.dateComponents([.day], from: cal.startOfDay(for: oldest.timestamp), to: today).day ?? 0) + 1)
        } else {
            actualDays = days
        }
        var result: [DaySummary] = []
        for i in (0..<actualDays).reversed() {
            guard let date = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let dayEntries = self.filter { cal.isDate($0.timestamp, inSameDayAs: date) }
            result.append(DaySummary(
                id: date.formatted(.iso8601.year().month().day()),
                date: date,
                entries: dayEntries
            ))
        }
        return result
    }
}
