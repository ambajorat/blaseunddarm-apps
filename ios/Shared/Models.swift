import Foundation

enum UrineColor: String, Codable, CaseIterable, Identifiable {
    case none = "keine Angabe"
    case clear = "Durchsichtig"
    case lightYellow = "Hell gelb"
    case yellow = "Gelb"
    case darkYellow = "Dunkel gelb"
    case cloudy = "Trüb"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .none: "⚪️"
        case .clear: "💧"
        case .lightYellow: "🍋"
        case .yellow: "🟡"
        case .darkYellow: "🟠"
        case .cloudy: "🌫️"
        }
    }

    var localizedName: String {
        switch self {
        case .none: String(localized: "color_none")
        case .clear: String(localized: "color_clear")
        case .lightYellow: String(localized: "color_light")
        case .yellow: String(localized: "color_yellow")
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
        case .none: String(localized: "Keine Angabe")
        case .type1: String(localized: "Typ 1")
        case .type2: String(localized: "Typ 2")
        case .type3: String(localized: "Typ 3")
        case .type4: String(localized: "Typ 4")
        case .type5: String(localized: "Typ 5")
        case .type6: String(localized: "Typ 6")
        case .type7: String(localized: "Typ 7")
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
        case .type1: String(localized: "Einzelne harte Klumpen")
        case .type2: String(localized: "Wurstartig, klumpig")
        case .type3: String(localized: "Wurstartig, rissig")
        case .type4: String(localized: "Glatt, weich")
        case .type5: String(localized: "Weiche Klümpchen")
        case .type6: String(localized: "Breiig, aufgelöst")
        case .type7: String(localized: "Wässrig, flüssig")
        }
    }

    var detail: String {
        switch self {
        case .none: ""
        case .type1: String(localized: "Einzelne, harte Klumpen wie Nüsse. Schwer auszuscheiden. Zeichen für starke Verstopfung.")
        case .type2: String(localized: "Wurstartig, aber klumpig. Zeichen für leichte Verstopfung.")
        case .type3: String(localized: "Wie eine Wurst mit Rissen an der Oberfläche. Normal.")
        case .type4: String(localized: "Wie eine Wurst oder Schlange, glatt und weich. Ideale Form.")
        case .type5: String(localized: "Weiche Klümpchen mit klaren Rändern. Neigung zu Durchfall.")
        case .type6: String(localized: "Breiige Konsistenz mit unscharfen Rändern. Leichter Durchfall.")
        case .type7: String(localized: "Wässrig, keine festen Bestandteile. Starker Durchfall.")
        }
    }

    var category: String {
        switch self {
        case .none: ""
        case .type1, .type2: String(localized: "Verstopfung")
        case .type3, .type4: String(localized: "Normal")
        case .type5, .type6, .type7: String(localized: "Durchfall")
        }
    }
}

/// Auffälligkeiten für die HWI-Frühwarnung (ISK).
/// Trüber Urin läuft bewusst über die Urinfarbe, nicht doppelt hier.
enum UtiSymptom: String, Codable, CaseIterable, Identifiable {
    case smell = "Starker Geruch"
    case blood = "Blut im Urin"
    case pain = "Brennen/Schmerzen"
    case spasticity = "Vermehrte Spastik"
    case fever = "Fieber/Schüttelfrost"
    case malaise = "Abgeschlagenheit"

    var id: String { rawValue }

    /// Anzeichen, die sofort einen Hinweis auslösen (nicht erst als Muster).
    var isUrgent: Bool { self == .blood || self == .fever }
}

/// Tastbefund oberhalb der Symphyse — Selbsteinschätzung des Füllungsgrades (ISK).
enum PalpationFinding: String, Codable, CaseIterable, Identifiable {
    case soft = "Tief eindrückbar"
    case medium = "Leichter Widerstand"
    case firm = "Deutlich federnd"
    var id: String { rawValue }
}

/// Vegetative Zeichen (autonome Dysreflexie) — bei hoher Lähmung oft
/// die einzigen Füllungssignale. Bewusst getrennt von den Infektzeichen.
enum AdSign: String, Codable, CaseIterable, Identifiable {
    case goosebumps = "Gänsehaut"
    case sweating = "Schwitzen"
    case heat = "Hitzegefühl"
    case headache = "Kopfschmerz"
    var id: String { rawValue }
}

/// Anzeige-Label: rawValue ist Speicher-/CSV-Format (deutsch, stabil),
/// label läuft durchs Lokalisierungssystem.
extension UrineColor { var label: String { String(localized: String.LocalizationValue(rawValue)) } }
extension UtiSymptom { var label: String { String(localized: String.LocalizationValue(rawValue)) } }
extension PalpationFinding { var label: String { String(localized: String.LocalizationValue(rawValue)) } }
extension AdSign { var label: String { String(localized: String.LocalizationValue(rawValue)) } }

/// Stuhlmenge in fünf Stufen — Tier-Größenskala mit Augenzwinkern.
enum StoolAmount: String, Codable, CaseIterable, Identifiable {
    case verySmall = "Sehr klein"
    case small = "Klein"
    case medium = "Mittel"
    case large = "Groß"
    case huge = "Riesig"

    var id: String { rawValue }
    var label: String { String(localized: String.LocalizationValue(rawValue)) }
    var emoji: String {
        switch self {
        case .verySmall: "🐜"
        case .small: "🐭"
        case .medium: "🐰"
        case .large: "🐕"
        case .huge: "🐘"
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
    /// Optional, damit alte gespeicherte Einträge weiter decodieren
    var drinkMl: Int?
    /// Optional, damit alte gespeicherte Einträge weiter decodieren
    var symptoms: [UtiSymptom]?
    /// Optional, damit alte gespeicherte Einträge weiter decodieren
    var palpation: PalpationFinding?
    /// Optional, damit alte gespeicherte Einträge weiter decodieren
    var adSigns: [AdSign]?
    /// Optional, damit alte gespeicherte Einträge weiter decodieren
    var systolicBp: Int?
    /// Optional, damit alte gespeicherte Einträge weiter decodieren
    var stoolAmount: StoolAmount?
    /// Kathetersorte des Eintrags (4.11, Name aus CatheterStock.sorts; nil = Standardsorte)
    var catheterSort: String?
    /// Namen der bei diesem Eintrag genommenen Medikamente (4.12). Optional
    /// mit nil-Default — Alt-Einträge decodieren unverändert.
    var medications: [String]? = nil

    init(id: UUID = UUID(), timestamp: Date = .now, urineMl: Int = 0, bowel: Bool = false, bristolType: BristolType = .none, urineColor: UrineColor = .none, note: String = "", drinkMl: Int? = nil, symptoms: [UtiSymptom]? = nil, palpation: PalpationFinding? = nil, adSigns: [AdSign]? = nil, systolicBp: Int? = nil, stoolAmount: StoolAmount? = nil, catheterSort: String? = nil, medications: [String]? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.urineMl = urineMl
        self.bowel = bowel
        self.bristolType = bristolType
        self.urineColor = urineColor
        self.note = note
        self.drinkMl = drinkMl
        self.symptoms = symptoms
        self.palpation = palpation
        self.adSigns = adSigns
        self.systolicBp = systolicBp
        self.stoolAmount = stoolAmount
        self.catheterSort = catheterSort
        self.medications = medications
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
    // Wecker-Modus: Erinnerungen zu festen Uhrzeiten statt Intervall
    // (Optionals: Bestandsdaten ohne diese Felder decodieren sauber zu nil)
    var useFixedTimes: Bool? = nil
    var fixedTimes: [Int]? = nil  // Minuten seit Mitternacht, z.B. 420 = 07:00
    // Zielmenge je Entleerung für den Vorschlag „Abstände nach Tageszeit“ (nil = 400 ml)
    var targetVolumeMl: Int? = nil
    // Feste Zeiten an der ersten Entleerung am Morgen ausrichten:
    // fixedTimesTemplate = Grundplan (erste Zeit = Aufwachzeit), fixedTimes = heute
    // verschobene Fassung, anchorDayKey = Tag der letzten Ausrichtung.
    var anchorToFirstVoid: Bool? = nil
    var fixedTimesTemplate: [Int]? = nil
    var anchorDayKey: String? = nil

    var fixedTimesEnabled: Bool { (useFixedTimes ?? false) && !(fixedTimes ?? []).isEmpty }
    var sortedFixedTimes: [Int] { (fixedTimes ?? []).sorted() }
    var anchorsToFirstVoid: Bool { anchorToFirstVoid ?? false }
    /// Grundplan der festen Zeiten — bei Ausrichtung die Vorlage, sonst die Zeiten selbst.
    var fixedTemplate: [Int] {
        anchorsToFirstVoid ? (fixedTimesTemplate ?? sortedFixedTimes).sorted() : sortedFixedTimes
    }

    /// Grundplan so verschieben, dass seine erste Zeit auf `firstVoidMinute` fällt.
    /// Zeiten jenseits von Mitternacht entfallen.
    static func shiftedTimes(_ template: [Int], firstVoidMinute: Int) -> [Int] {
        guard let base = template.min() else { return [] }
        let delta = firstVoidMinute - base
        return Array(Set(template.map { $0 + delta }.filter { (0..<1440).contains($0) })).sorted()
    }

    /// Erste Entleerung des heutigen Morgens: erster Urin-Eintrag heute zwischen
    /// 04 und 12 Uhr nach mindestens 5 Stunden Pause (= nach der Nacht).
    static func firstMorningVoid(entries: [ToiletEntry], now: Date = .now) -> Date? {
        let cal = Calendar.current
        let urine = entries.filter { $0.urineMl > 0 && $0.timestamp <= now }
            .map(\.timestamp).sorted()
        let today = cal.startOfDay(for: now)
        for (i, t) in urine.enumerated() where t >= today {
            let h = cal.component(.hour, from: t)
            guard (4..<12).contains(h) else { continue }
            if i == 0 || t.timeIntervalSince(urine[i - 1]) >= 5 * 3600 { return t }
        }
        return nil
    }

    /// Richtet fixedTimes einmal pro Tag an der ersten Morgen-Entleerung aus.
    /// true = Zeiten wurden geändert (Erinnerungen neu planen).
    mutating func alignFixedTimes(entries: [ToiletEntry], now: Date = .now) -> Bool {
        guard anchorsToFirstVoid, useFixedTimes ?? false else { return false }
        let template = fixedTemplate
        guard !template.isEmpty else { return false }
        let key = now.formatted(.iso8601.year().month().day())
        guard anchorDayKey != key,
              let first = Self.firstMorningVoid(entries: entries, now: now) else { return false }
        let cal = Calendar.current
        let minute = cal.component(.hour, from: first) * 60 + cal.component(.minute, from: first)
        let shifted = Self.shiftedTimes(template, firstVoidMinute: minute)
        guard !shifted.isEmpty else { return false }
        fixedTimes = shifted
        anchorDayKey = key
        return true
    }

    /// Nächste feste Erinnerungszeit nach `date` (heute oder morgen früh).
    static func nextFixedDue(after date: Date, times: [Int]) -> Date? {
        guard !times.isEmpty else { return nil }
        let sorted = times.sorted()
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let nowMin = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        if let next = sorted.first(where: { $0 > nowMin }) {
            return startOfDay.addingTimeInterval(TimeInterval(next * 60))
        }
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }
        return tomorrow.addingTimeInterval(TimeInterval(sorted[0] * 60))
    }

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
    /// Echte Toilettengänge (Urin oder Stuhl) — reine Trink-/Symptom-Einträge zählen nicht.
    var visitCount: Int { entries.filter { $0.urineMl > 0 || $0.bowel }.count }
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
