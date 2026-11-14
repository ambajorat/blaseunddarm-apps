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
    // Lernender Grundplan: die App leitet den Grundplan täglich aus der
    // Füllrate der letzten 14 Tage so ab, dass die Zielmenge je Entleerung
    // möglichst nicht überschritten wird (nil = an).
    var autoLearnTemplate: Bool? = nil
    var templateLearnDayKey: String? = nil      // Tag der letzten Prüfung
    var templateLearnedAt: Date? = nil          // letzte tatsächliche Anpassung
    var templateLearnedFrom: [Int]? = nil       // Grundplan davor (für die Anzeige)

    var fixedTimesEnabled: Bool { (useFixedTimes ?? false) && !(fixedTimes ?? []).isEmpty }
    var sortedFixedTimes: [Int] { (fixedTimes ?? []).sorted() }
    var anchorsToFirstVoid: Bool { anchorToFirstVoid ?? false }
    var learnsTemplate: Bool { autoLearnTemplate ?? true }
    /// Grundplan der festen Zeiten — bei Ausrichtung die Vorlage, sonst die Zeiten selbst.
    var fixedTemplate: [Int] {
        anchorsToFirstVoid ? (fixedTimesTemplate ?? sortedFixedTimes).sorted() : sortedFixedTimes
    }

    /// Größter Abstand, der im Grundplan noch ohne Hinweis bleibt (4 Stunden —
    /// derselbe Deckel wie beim Vorschlag „Abstände nach Tageszeit").
    static let maxFixedGap = 240

    /// Größte Lücke im Grundplan über `maxGap` Minuten samt Vorschlag für die
    /// fehlende Zeit (Mitte, auf 15 Minuten gerundet). nil = kein Handlungsbedarf.
    static func fixedTemplateGap(in times: [Int], maxGap: Int = maxFixedGap)
        -> (from: Int, to: Int, suggestion: Int)? {
        let s = Array(Set(times)).sorted()
        var best: (from: Int, to: Int)? = nil
        for (a, b) in zip(s, s.dropFirst())
            where b - a > maxGap && b - a > ((best?.to ?? 0) - (best?.from ?? 0)) {
            best = (a, b)
        }
        guard let g = best else { return nil }
        var m = Int((Double(g.from + (g.to - g.from) / 2) / 15).rounded()) * 15
        if s.contains(m) { m += 15 }
        return (g.from, g.to, m)
    }

    /// Grundplan ohne Lücken über `maxGap`: zu große Abstände werden durch
    /// Zwischenzeiten (Mitte, auf 15 Minuten) geteilt, bis alle Abstände passen.
    /// Idempotent — ein Plan ohne Lücken kommt unverändert zurück.
    static func filledFixedTimes(_ times: [Int], maxGap: Int = maxFixedGap) -> [Int] {
        var s = Array(Set(times)).sorted()
        var rounds = 0
        while let g = fixedTemplateGap(in: s, maxGap: maxGap), rounds < 32 {
            s.append(g.suggestion)
            s = Array(Set(s)).sorted()
            rounds += 1
        }
        return s
    }

    /// Lernender Grundplan — Leitplanken gegen „Zittern“: Bei gleicher Anzahl
    /// Zeiten wird jede Zeit nur übernommen, wenn sie sich um mindestens
    /// `minShift` Minuten vom bisherigen Wert unterscheidet; ändert sich die
    /// Anzahl (mehr/weniger Erinnerungen nötig), gilt der Vorschlag ganz.
    /// nil = keine lohnende Änderung. Ergebnis ist lückenfrei (filledFixedTimes).
    static func learnedTemplate(current: [Int], proposed: [Int], minShift: Int = 15) -> [Int]? {
        let cur = Array(Set(current)).sorted()
        let prop = filledFixedTimes(proposed)
        guard !prop.isEmpty else { return nil }
        guard prop.count == cur.count, !cur.isEmpty else {
            return prop == cur ? nil : prop
        }
        var out = cur
        for i in cur.indices where abs(prop[i] - cur[i]) >= minShift { out[i] = prop[i] }
        out = filledFixedTimes(out)
        return out == cur ? nil : out
    }

    /// Grundplan so verschieben, dass seine erste Zeit auf `firstVoidMinute` fällt.
    /// Zeiten jenseits von Mitternacht entfallen (außer `keepPastMidnight`).
    static func shiftedTimes(_ template: [Int], firstVoidMinute: Int,
                             keepPastMidnight: Bool = false) -> [Int] {
        guard let base = template.min() else { return [] }
        let delta = firstVoidMinute - base
        return Array(Set(template.map { $0 + delta }
            .filter { $0 >= 0 && (keepPastMidnight || $0 < 1440) })).sorted()
    }

    /// Erste Entleerung des heutigen Morgens (= Aufwachen): erster Urin-Eintrag
    /// heute im Morgenfenster bis 12 Uhr nach der Nacht.
    /// Morgenfenster: ab 04 Uhr, mit Aufwachzeit `wakeMinute` (erste Grundplanzeit)
    /// erst ab 2,5 Std davor — eine Nacht-Entleerung um 04:31 bei Aufwachzeit 08:15
    /// ist KEIN Aufwachen und darf den Tag nicht um fast 4 Std vorziehen.
    /// Nach der Nacht = ≥ 5 Std Pause ODER die Entleerung davor lag vor dem
    /// Fenster (Nacht-Entleerung).
    static func firstMorningVoid(entries: [ToiletEntry], now: Date = .now,
                                 wakeMinute: Int? = nil) -> Date? {
        let cal = Calendar.current
        let urine = entries.filter { $0.urineMl > 0 && $0.timestamp <= now }
            .map(\.timestamp).sorted()
        let today = cal.startOfDay(for: now)
        let windowStart = max(240, (wakeMinute ?? 240) - 150)
        let windowStartDate = cal.date(bySettingHour: windowStart / 60, minute: windowStart % 60,
                                       second: 0, of: today) ?? today
        for (i, t) in urine.enumerated() where t >= windowStartDate {
            guard cal.component(.hour, from: t) < 12 else { break }
            if i == 0 || t.timeIntervalSince(urine[i - 1]) >= 5 * 3600
                || urine[i - 1] < windowStartDate { return t }
        }
        return nil
    }

    /// Restplan des Tages ab einer Entleerung um `e` (Minuten) neu takten:
    /// Die Entleerung ersetzt die NÄCHSTGELEGENE geplante Zeit (früher dran →
    /// die kommende, später dran → die vergangene). Alle Zeiten danach rücken
    /// um dieselbe Differenz mit, die Abstände bleiben. Die Entleerung wird
    /// selbst zur Zeit im Plan — ein zweiter Aufruf verschiebt nichts mehr.
    /// `protected` = Minuten echter Entleerungen von heute: die werden nie
    /// ersetzt (sonst „verschwindet“ z. B. 19:35, und 20:56 schiebt den Rest
    /// später statt früher).
    static func rechainedTimes(_ times: [Int], afterVoidMinute e: Int,
                               keepPastMidnight: Bool = false,
                               protected: Set<Int> = []) -> [Int] {
        let s = Array(Set(times)).sorted()
        guard let j = s.firstIndex(where: { $0 > e }) else { return s }
        let k = (j > 0 && !protected.contains(s[j - 1]) && e - s[j - 1] <= s[j] - e) ? j - 1 : j
        let delta = e - s[k]
        guard delta != 0 else { return s }
        var out = Array(s[..<k])
        out.append(e)
        out += s[(k + 1)...].map { $0 + delta }.filter { keepPastMidnight || $0 < 1440 }
        return Array(Set(out)).sorted()
    }

    /// Richtet fixedTimes an den Entleerungen des Tages aus:
    /// 1. den ganzen Grundplan auf die erste Morgen-Entleerung,
    /// 2. danach jede weitere Urin-Entleerung des Tages der Reihe nach (rechainedTimes).
    /// Der Tagesplan wird bei jedem Aufruf komplett aus dem Grundplan neu
    /// berechnet. Zeiten nach Mitternacht bleiben dabei ZWISCHENZEITLICH erhalten
    /// und fallen erst am Ende weg — sonst geht eine Zeit, die durch spätes
    /// Aufstehen kurz über Mitternacht rutscht, endgültig verloren, obwohl
    /// spätere frühere Entleerungen sie wieder vor Mitternacht ziehen würden.
    /// true = Zeiten wurden geändert (Erinnerungen neu planen).
    mutating func alignFixedTimes(entries: [ToiletEntry], now: Date = .now) -> Bool {
        guard anchorsToFirstVoid, useFixedTimes ?? false else { return false }
        let template = fixedTemplate
        guard !template.isEmpty else { return false }
        let cal = Calendar.current
        func minuteOf(_ d: Date) -> Int { cal.component(.hour, from: d) * 60 + cal.component(.minute, from: d) }
        let key = now.formatted(.iso8601.year().month().day())

        guard let first = Self.firstMorningVoid(entries: entries, now: now,
                                                wakeMinute: template.first) else { return false }
        var plan = Self.shiftedTimes(template, firstVoidMinute: minuteOf(first), keepPastMidnight: true)
        guard !plan.isEmpty else { return false }

        // Alle weiteren Urin-Entleerungen heute nach der ersten, in Reihenfolge
        let voids = entries.filter { $0.urineMl > 0 && $0.timestamp > first && $0.timestamp <= now }
            .map(\.timestamp).sorted()
        var done: Set<Int> = [minuteOf(first)]
        for v in voids {
            guard let firstTime = plan.first, minuteOf(v) >= firstTime else { continue }
            plan = Self.rechainedTimes(plan, afterVoidMinute: minuteOf(v), keepPastMidnight: true,
                                       protected: done)
            done.insert(minuteOf(v))
        }
        // Tagesende-Anker = letzte Grundplanzeit (Erinnerung vor dem Schlafen):
        // 1. nichts wandert darüber hinaus — Überhang kollabiert in sie, statt
        //    über Mitternacht zu rutschen und gelöscht zu werden;
        // 2. endet der Plan durch frühe Entleerungen mehr als 90 Min davor, wird
        //    der Rest des Tages bis zu ihr gestreckt — die Anzahl der
        //    Erinnerungen bleibt wie im Grundplan. Nur wenn dafür mehr als ein
        //    Viertel Streckung nötig wäre (oder ein Abstand über 4 h entstünde),
        //    kommt sie als zusätzliche Zeit dazu (Lücken > 4 h werden aufgefüllt).
        let lastTemplate = template.max() ?? 1439
        var base = Array(Set(plan.map { min($0, lastTemplate) })).sorted()
        if let last = base.last, last < lastTemplate - 90 {
            let lastVoid = done.max() ?? 0
            let future = base.filter { $0 > lastVoid }
            let den = (future.last ?? lastVoid) - lastVoid
            let num = lastTemplate - lastVoid
            let stretched = den > 0
                ? future.map { lastVoid + (($0 - lastVoid) * num + den / 2) / den } : []
            let gaps = zip([lastVoid] + stretched, stretched).map { $1 - $0 }
            if den > 0, num * 4 <= den * 5, gaps.allSatisfy({ $0 <= Self.maxFixedGap }) {
                base = Array(Set(base.filter { $0 <= lastVoid } + stretched)).sorted()
            } else {
                let tail = Self.filledFixedTimes(base.filter { $0 >= lastVoid } + [lastTemplate])
                base = Array(Set(base.filter { $0 < lastVoid } + tail)).sorted()
            }
        }
        guard !base.isEmpty else { return false }

        var changed = false
        if anchorDayKey != key { anchorDayKey = key; changed = true }
        if base != sortedFixedTimes {
            fixedTimes = base
            changed = true
        }
        return changed
    }

    /// Die HEUTE gültigen festen Zeiten. Bei Ausrichtung gilt bis zur ersten
    /// Morgen-Entleerung der Grundplan — nicht der gestern neu getaktete Plan.
    func effectiveFixedTimes(now: Date = .now) -> [Int] {
        guard anchorsToFirstVoid else { return sortedFixedTimes }
        let key = now.formatted(.iso8601.year().month().day())
        return anchorDayKey == key ? sortedFixedTimes : fixedTemplate
    }

    /// Fälligkeit im Wecker-Modus: die erste geplante Zeit NACH der letzten
    /// Entleerung (heute). Liegt sie vor `now`, ist die Erinnerung überfällig —
    /// eine verpasste Zeit wird nicht still übersprungen. Letzte Entleerung vor
    /// heute → erste Zeit des heutigen Plans. Nach der letzten Zeit des Tages →
    /// erste Zeit des Grundplans morgen.
    func fixedDue(lastVoid: Date?, now: Date = .now) -> Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let times = effectiveFixedTimes(now: now)
        guard !times.isEmpty else { return nil }
        if let last = lastVoid, last >= today {
            let m = cal.component(.hour, from: last) * 60 + cal.component(.minute, from: last)
            if let next = times.first(where: { $0 > m }) {
                return (Calendar.current.date(bySettingHour: (next) / 60, minute: (next) % 60, second: 0, of: today) ?? today.addingTimeInterval(TimeInterval((next) * 60)))
            }
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: today),
                  let first = fixedTemplate.first ?? times.first else { return nil }
            return (Calendar.current.date(bySettingHour: (first) / 60, minute: (first) % 60, second: 0, of: tomorrow) ?? tomorrow.addingTimeInterval(TimeInterval((first) * 60)))
        }
        return (Calendar.current.date(bySettingHour: (times[0]) / 60, minute: (times[0]) % 60, second: 0, of: today) ?? today.addingTimeInterval(TimeInterval((times[0]) * 60)))
    }

    /// Nächste feste Erinnerungszeit nach `date` (heute oder morgen früh).
    static func nextFixedDue(after date: Date, times: [Int]) -> Date? {
        guard !times.isEmpty else { return nil }
        let sorted = times.sorted()
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let nowMin = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        if let next = sorted.first(where: { $0 > nowMin }) {
            return (Calendar.current.date(bySettingHour: (next) / 60, minute: (next) % 60, second: 0, of: startOfDay) ?? startOfDay.addingTimeInterval(TimeInterval((next) * 60)))
        }
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }
        return (Calendar.current.date(bySettingHour: (sorted[0]) / 60, minute: (sorted[0]) % 60, second: 0, of: tomorrow) ?? tomorrow.addingTimeInterval(TimeInterval((sorted[0]) * 60)))
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

// MARK: - Widget-Brücke
// Bewusst hier und nicht in WidgetData.swift: das Watch-Widget-Target
// kompiliert WidgetData.swift OHNE Models.swift und kennt AppSettings nicht.
extension WidgetData {
    /// AppSettings-Ausschnitt für die gemeinsame Fälligkeitslogik.
    var fixedSettings: AppSettings {
        var s = AppSettings()
        s.useFixedTimes = useFixedTimes
        s.fixedTimes = fixedTimes
        s.fixedTimesTemplate = fixedTimesTemplate
        s.anchorToFirstVoid = anchorToFirstVoid
        s.anchorDayKey = anchorDayKey
        return s
    }
}
