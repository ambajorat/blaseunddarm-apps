import Foundation

/// Vorschläge aus den EIGENEN Daten der letzten 30 Tage.
/// Rein beschreibende Statistik (Perzentile, Mediane, Häufigkeiten) —
/// nichts wird automatisch übernommen, der Nutzer tippt jeden Wert
/// selbst an. Keine medizinische Empfehlung.
struct Suggestions {
    var singleOverMl: Int?
    /// true, wenn das 95. Perzentil über der Deckelung (500 ml) lag —
    /// bewusst nicht höher vorschlagen, um Überdehnung nicht zu normalisieren.
    var singleCapped: Bool = false
    var dayOverMl: Int?
    var dayUnderMl: Int?
    var countOver: Int?
    var countUnder: Int?
    /// Median-Abstand zwischen Tages-Einträgen, auf 30 min gerundet, 60–240.
    var intervalMinutes: Int?
    var urineQuickValues: [Int]?
    var drinkQuickValues: [Int]?

    var isEmpty: Bool {
        singleOverMl == nil && dayOverMl == nil && dayUnderMl == nil
            && countOver == nil && countUnder == nil && intervalMinutes == nil
    }
}

enum SuggestionEngine {

    static let singleCap = 500

    /// nil, wenn zu wenig Daten (unter 7 Tage mit Einträgen in 30 Tagen).
    static func compute(entries: [ToiletEntry]) -> Suggestions? {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: .now)) ?? .distantPast
        let recent = entries.filter { $0.timestamp >= start }

        // Tage gruppieren
        var days: [Date: [ToiletEntry]] = [:]
        for e in recent {
            days[cal.startOfDay(for: e.timestamp), default: []].append(e)
        }
        let daysWithUrine = days.filter { $0.value.contains { $0.urineMl > 0 } }
        guard daysWithUrine.count >= 7 else { return nil }

        var s = Suggestions()

        // Einzelmenge: 95. Perzentil, auf 25 gerundet, gedeckelt
        let singles = recent.map(\.urineMl).filter { $0 > 0 }.sorted()
        if singles.count >= 20 {
            let p95 = percentile(singles, 0.95)
            let rounded = roundTo(p95, 25)
            if rounded > singleCap {
                s.singleOverMl = singleCap
                s.singleCapped = true
            } else if rounded >= 200 {
                s.singleOverMl = rounded
            }
        }

        // Tagesmengen: Schnitt ±20 %, auf 50 gerundet
        let totals = daysWithUrine.values.map { $0.reduce(0) { $0 + $1.urineMl } }
        let avgTotal = totals.reduce(0, +) / totals.count
        if avgTotal > 0 {
            s.dayOverMl = roundTo(Int(Double(avgTotal) * 1.2), 50)
            s.dayUnderMl = roundTo(Int(Double(avgTotal) * 0.8), 50)
        }

        // Gänge: Schnitt ±, mindestens sinnvolle Spanne
        let counts = daysWithUrine.values.map { $0.filter { $0.urineMl > 0 }.count }
        let avgCount = Double(counts.reduce(0, +)) / Double(counts.count)
        s.countOver = max(Int(avgCount.rounded()) + 2, Int((avgCount * 1.3).rounded()))
        s.countUnder = max(1, min(Int(avgCount.rounded()) - 2, Int((avgCount * 0.7).rounded())))

        // Intervall: Median-Abstand aufeinanderfolgender Urin-Einträge
        // innerhalb eines Tages (Nachtpausen fallen so heraus)
        var gaps: [Int] = []
        for (_, dayEntries) in daysWithUrine {
            let times = dayEntries.filter { $0.urineMl > 0 }.map(\.timestamp).sorted()
            for i in 1..<max(times.count, 1) where times.count > 1 {
                let m = Int(times[i].timeIntervalSince(times[i-1]) / 60)
                if (30...480).contains(m) { gaps.append(m) }
            }
        }
        if gaps.count >= 10 {
            let median = gaps.sorted()[gaps.count / 2]
            s.intervalMinutes = min(240, max(60, roundTo(median, 30)))
        }

        // Häufigste Mengen als Schnellwahl (auf 10 ml gerundet gruppiert)
        s.urineQuickValues = topValues(recent.map(\.urineMl).filter { $0 > 0 })
        s.drinkQuickValues = topValues(recent.compactMap(\.drinkMl).filter { $0 > 0 })

        return s
    }

    // MARK: - Helfer

    private static func percentile(_ sorted: [Int], _ p: Double) -> Int {
        guard !sorted.isEmpty else { return 0 }
        let idx = min(sorted.count - 1, Int(Double(sorted.count) * p))
        return sorted[idx]
    }

    private static func roundTo(_ value: Int, _ step: Int) -> Int {
        ((value + step / 2) / step) * step
    }

    /// Die 4 häufigsten Werte (auf 10er gerundet), aufsteigend — nil unter 15 Werten.
    private static func topValues(_ values: [Int]) -> [Int]? {
        guard values.count >= 15 else { return nil }
        var freq: [Int: Int] = [:]
        for v in values { freq[roundTo(v, 10), default: 0] += 1 }
        let top = freq.sorted { $0.value > $1.value }.prefix(4).map(\.key).sorted()
        return top.count >= 3 ? top : nil
    }
}


// MARK: - Abstände nach Tageszeit

/// Ein Tagesfenster mit der eigenen Füllrate und dem daraus abgeleiteten Abstand.
struct DaytimeSlot: Identifiable, Equatable {
    let id: Int
    let startHour: Int
    /// exklusiv; 24 = Mitternacht
    let endHour: Int
    /// 75. Perzentil der Füllrate (ml pro Stunde) — eher hoch angesetzt,
    /// damit die Zielmenge in drei von vier Abständen nicht erreicht wird.
    let rateMlPerHour: Int
    let samples: Int
    let suggestedMinutes: Int
    /// Abstände in diesem Fenster, deren Menge über der Zielmenge lag.
    let overTarget: Int
    /// true, wenn das Fenster zu wenige eigene Abstände hatte und die
    /// Tages-Füllrate als Ersatz genommen wurde.
    let usesFallback: Bool

    var label: String { Self.name(for: id) }

    static func name(for id: Int) -> String {
        switch id {
        case 0: return String(localized: "Morgens")
        case 1: return String(localized: "Mittags")
        case 2: return String(localized: "Nachmittags")
        default: return String(localized: "Abends")
        }
    }

    var rangeText: String {
        String(format: "%02d–%02d", startHour, endHour)
    }
}

/// Vorschlag „Abstände nach Tageszeit“ — rein beschreibend aus den eigenen
/// Einträgen der letzten 30 Tage, wird nie automatisch übernommen.
struct IntervalPlan: Equatable {
    let targetMl: Int
    let slots: [DaytimeSlot]
    /// Vorgeschlagene feste Erinnerungszeiten (Minuten seit Mitternacht).
    let times: [Int]
    let wakeMinutes: Int
    let bedMinutes: Int
    /// Alle Mengen im Zeitraum / davon über der Zielmenge.
    let volumes: Int
    let overTarget: Int
    /// Erste Menge nach der Nachtpause.
    let morningMedianMl: Int?
    let morningSamples: Int
    let morningOverTarget: Int
}

extension SuggestionEngine {

    static let defaultTargetMl = 400
    /// Tagesfenster: Morgens, Mittags, Nachmittags, Abends.
    static let slotBounds: [(Int, Int)] = [(5, 11), (11, 15), (15, 19), (19, 24)]
    /// Längster Abstand, der noch als Tagesabstand zählt (darüber = Nachtpause).
    static let maxDayGap = 360
    static let minNightGap = 300
    /// Höchstens so viele Erinnerungen am Tag schlägt der Plan vor; darüber
    /// werden die Abstände leicht gestreckt (bis rund ein Viertel).
    static let maxTimesPerDay = 8

    static func slotIndex(forMinute minute: Int) -> Int {
        let h = (minute / 60) % 24
        if h < slotBounds[0].0 { return 0 }
        return slotBounds.firstIndex { h >= $0.0 && h < $0.1 } ?? slotBounds.count - 1
    }

    /// nil bei zu wenig Daten (unter 7 Tagen mit Urin-Einträgen in 30 Tagen
    /// oder unter 20 Tagesabständen insgesamt).
    /// `days` = Betrachtungszeitraum (Vorschlagsseite 30, lernender Grundplan 14).
    static func intervalPlan(entries: [ToiletEntry], targetMl: Int, now: Date = .now,
                             days: Int = 30) -> IntervalPlan? {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: now)) ?? .distantPast

        // Urin-Einträge; Doppel innerhalb von 10 Minuten = eine Entleerung
        var pts: [(t: Date, ml: Int)] = []
        for e in entries.filter({ $0.urineMl > 0 && $0.timestamp >= start && $0.timestamp <= now })
            .sorted(by: { $0.timestamp < $1.timestamp }) {
            if let last = pts.last, e.timestamp.timeIntervalSince(last.t) < 600 {
                pts[pts.count - 1] = (e.timestamp, max(last.ml, e.urineMl))
            } else {
                pts.append((e.timestamp, e.urineMl))
            }
        }
        let dayCount = Set(pts.map { cal.startOfDay(for: $0.t) }).count
        guard dayCount >= 7 else { return nil }

        func minuteOfDay(_ d: Date) -> Int {
            cal.component(.hour, from: d) * 60 + cal.component(.minute, from: d)
        }

        var slotRates = Array(repeating: [Double](), count: slotBounds.count)
        var slotOver = Array(repeating: 0, count: slotBounds.count)
        var morningMl: [Int] = []
        var wakes: [Int] = []
        var beds: [Int] = []

        for i in 1..<max(pts.count, 1) where pts.count > 1 {
            let a = pts[i - 1], b = pts[i]
            let gap = Int(b.t.timeIntervalSince(a.t) / 60)
            let aMin = minuteOfDay(a.t)
            let bHour = cal.component(.hour, from: b.t)
            if gap >= minNightGap && (4..<12).contains(bHour) {
                // Nachtpause: a = letzte vor dem Schlafen, b = erste am Morgen
                morningMl.append(b.ml)
                wakes.append(minuteOfDay(b.t))
                beds.append(aMin < 4 * 60 ? aMin + 1440 : aMin)
                continue
            }
            guard (20...maxDayGap).contains(gap), aMin >= slotBounds[0].0 * 60 else { continue }
            // Der Abstand zählt für das Fenster, in dem seine Mitte liegt —
            // dort ist der größte Teil der Menge entstanden.
            let idx = slotIndex(forMinute: min(aMin + gap / 2, 1439))
            slotRates[idx].append(Double(b.ml) / Double(gap) * 60)
            if b.ml > targetMl { slotOver[idx] += 1 }
        }

        let allRates = slotRates.flatMap { $0 }.sorted()
        guard allRates.count >= 20 else { return nil }
        let pooledP75 = percentileD(allRates, 0.75)

        func minutes(for rate: Double) -> Int {
            guard rate > 0 else { return 240 }
            return min(240, max(60, roundTo(Int(Double(targetMl) * 60 / rate), 15)))
        }

        var slots: [DaytimeSlot] = []
        var rates: [Double] = []
        for (i, b) in slotBounds.enumerated() {
            let r = slotRates[i].sorted()
            let fallback = r.count < 8
            let rate = fallback ? pooledP75 : percentileD(r, 0.75)
            rates.append(rate)
            slots.append(DaytimeSlot(
                id: i, startHour: b.0, endHour: b.1,
                rateMlPerHour: Int(rate.rounded()), samples: r.count,
                suggestedMinutes: minutes(for: rate),
                overTarget: slotOver[i], usesFallback: fallback))
        }

        // Tagesrahmen aus den eigenen Gewohnheiten (Median, auf 15 min)
        let wake = wakes.count >= 5 ? roundTo(median(wakes), 15) : 7 * 60
        var bed = beds.count >= 5 ? roundTo(median(beds), 15) : 22 * 60
        bed = min(bed, 1425)
        guard bed > wake + 120 else { return nil }

        /// Minuten ab `t`, bis `target` ml zusammenkommen — über die
        /// Fenstergrenzen hinweg gerechnet: ein Abstand, der morgens beginnt
        /// und in den Mittag reicht, füllt sich dort mit der Mittagsrate
        /// (60…240 min, auf 15 min).
        func step(from t: Int, target: Double) -> Int {
            var ml = 0.0
            var cur = Double(t)
            while true {
                let idx = slotIndex(forMinute: Int(cur))
                let rate = rates[idx]
                guard rate > 0 else { cur = Double(t + 240); break }
                let end = Double(slotBounds[idx].1 * 60)
                let need = (target - ml) / rate * 60
                if end >= 1440 || cur + need <= end { cur += need; break }
                ml += (end - cur) * rate / 60
                cur = end
            }
            return min(240, max(60, roundTo(Int(cur) - t, 15)))
        }
        func build(_ target: Double) -> [Int] {
            var out = [wake]
            var t = wake
            while out.count < 16 {
                let next = t + step(from: t, target: target)
                if next > bed { break }
                out.append(next)
                t = next
            }
            if let last = out.last, bed - last >= 75, bed < 1440 { out.append(bed) }
            return out
        }
        // Höchstens maxTimesPerDay Erinnerungen: sonst die Abstände in
        // 5-%-Schritten strecken (höchstens fünfmal, rund +28 %).
        var effTarget = Double(targetMl)
        var times = build(effTarget)
        var rounds = 0
        while times.count > maxTimesPerDay && rounds < 5 {
            effTarget *= 1.05
            times = build(effTarget)
            rounds += 1
        }

        let vols = pts.map(\.ml)
        return IntervalPlan(
            targetMl: targetMl,
            slots: slots,
            times: times,
            wakeMinutes: wake,
            bedMinutes: bed,
            volumes: vols.count,
            overTarget: vols.filter { $0 > targetMl }.count,
            morningMedianMl: morningMl.count >= 5 ? median(morningMl) : nil,
            morningSamples: morningMl.count,
            morningOverTarget: morningMl.filter { $0 > targetMl }.count)
    }

    private static func percentileD(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        return sorted[min(sorted.count - 1, Int(Double(sorted.count) * p))]
    }

    private static func median(_ v: [Int]) -> Int {
        let s = v.sorted()
        return s[s.count / 2]
    }
}

// MARK: - Menge nach Tageszeit in 3-Stunden-Blöcken (4.22)

/// Ein 3-Stunden-Block des Tages mit der durchschnittlichen Urinmenge je Entleerung.
struct VolumeBlock: Identifiable, Equatable {
    /// 0…7 = 00–03, 03–06, … 21–24
    let id: Int
    let avgMl: Int
    let count: Int

    var startHour: Int { id * 3 }
    var endHour: Int { id * 3 + 3 }
    var rangeText: String { String(format: "%02d–%02d", startHour, endHour) }

    var label: String {
        switch id {
        case 0: return String(localized: "Nachts")
        case 1: return String(localized: "Frühmorgens")
        case 2: return String(localized: "Morgens")
        case 3: return String(localized: "Vormittags")
        case 4: return String(localized: "Mittags")
        case 5: return String(localized: "Nachmittags")
        case 6: return String(localized: "Abends")
        default: return String(localized: "Spätabends")
        }
    }
}

extension SuggestionEngine {
    /// Ø Urinmenge je Entleerung in 3-Stunden-Blöcken, zugeordnet nach der Uhrzeit
    /// des Eintrags. `since` = Beginn des Zeitraums (nil = alle). Blöcke mit weniger
    /// als `minCount` Einträgen fehlen — rein beschreibend.
    static func volumeBlocks(entries: [ToiletEntry], since: Date? = nil, minCount: Int = 3,
                             calendar: Calendar = .current) -> [VolumeBlock] {
        var buckets = Array(repeating: [Int](), count: 8)
        for e in entries where e.urineMl > 0 {
            if let since, e.timestamp < since { continue }
            let h = calendar.component(.hour, from: e.timestamp)
            buckets[min(7, max(0, h / 3))].append(e.urineMl)
        }
        return buckets.enumerated().compactMap { (i, mls) -> VolumeBlock? in
            guard mls.count >= minCount else { return nil }
            let avg = Int((Double(mls.reduce(0, +)) / Double(mls.count)).rounded())
            return VolumeBlock(id: i, avgMl: avg, count: mls.count)
        }
    }
}

// MARK: - Statistik: Verdichtung und Trendlinie (4.22)

enum StatsGranularity: Equatable { case day, week, month }

/// Ein Balken der Statistik-Diagramme: ein Tag, eine Woche oder ein Monat.
/// Bei Woche/Monat sind die Werte Durchschnitte pro Tag MIT Einträgen.
struct StatsBucket: Identifiable, Equatable {
    let start: Date
    /// Mitte des Abschnitts — Stützpunkt der Trendlinie.
    let mid: Date
    let activeDays: Int
    let avgMl: Double
    let avgVisits: Double
    let avgBowel: Double
    var id: Date { start }
}

struct StatsTrendPoint: Identifiable, Equatable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Ausgleichsgerade (kleinste Quadrate) über die Abschnitte mit Einträgen.
struct StatsTrendLine: Equatable {
    let startDate: Date
    let endDate: Date
    let startValue: Double
    let endValue: Double

    var points: [StatsTrendPoint] {
        [StatsTrendPoint(date: startDate, value: startValue), StatsTrendPoint(date: endDate, value: endValue)]
    }

    /// Veränderung vom Anfang zum Ende der Geraden in Prozent; nil, wenn der Anfangswert 0 ist.
    var changePercent: Int? {
        guard startValue > 0 else { return nil }
        return Int(((endValue - startValue) / startValue * 100).rounded())
    }
}

enum StatsTrend {
    /// Bis 30 Tage Tageswerte, 3 Monate Wochen, 1 Jahr Monate.
    /// „Alle“ (days ≥ 9999) richtet sich nach der tatsächlichen Spanne.
    static func granularity(forDays days: Int, spanDays: Int) -> StatsGranularity {
        let effective = days >= 9999 ? spanDays : days
        if effective <= 45 { return .day }
        if effective <= 180 { return .week }
        return .month
    }

    static func buckets(_ summaries: [DaySummary], by granularity: StatsGranularity,
                        calendar: Calendar = .current) -> [StatsBucket] {
        func make(start: Date, mid: Date, days: [DaySummary]) -> StatsBucket {
            let active = days.filter { $0.visitCount > 0 }
            let n = Double(max(active.count, 1))
            return StatsBucket(start: start, mid: mid, activeDays: active.count,
                               avgMl: Double(active.reduce(0) { $0 + $1.totalMl }) / n,
                               avgVisits: Double(active.reduce(0) { $0 + $1.visitCount }) / n,
                               avgBowel: Double(active.reduce(0) { $0 + $1.bowelCount }) / n)
        }
        switch granularity {
        case .day:
            // Jeder Tag bleibt ein Balken (auch leere Tage) — wie bisher.
            return summaries.sorted { $0.date < $1.date }.map {
                make(start: $0.date, mid: $0.date.addingTimeInterval(43_200), days: [$0])
            }
        case .week, .month:
            let component: Calendar.Component = granularity == .week ? .weekOfYear : .month
            let halfDays: Double = granularity == .week ? 3.5 : 15
            let groups = Dictionary(grouping: summaries) { day in
                calendar.dateInterval(of: component, for: day.date)?.start ?? day.date
            }
            return groups.compactMap { (start, days) -> StatsBucket? in
                let bucket = make(start: start, mid: start.addingTimeInterval(halfDays * 86_400), days: days)
                return bucket.activeDays > 0 ? bucket : nil
            }.sorted { $0.start < $1.start }
        }
    }

    /// nil bei weniger als 3 Abschnitten mit Einträgen. Werte werden bei 0 gekappt.
    static func trend(_ buckets: [StatsBucket], value: (StatsBucket) -> Double) -> StatsTrendLine? {
        let pts = buckets.filter { $0.activeDays > 0 }
        guard pts.count >= 3, let first = pts.first, let last = pts.last else { return nil }
        let xs = pts.map { $0.mid.timeIntervalSince(first.mid) / 86_400 }
        let ys = pts.map(value)
        let n = Double(pts.count)
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        var sxx = 0.0
        var sxy = 0.0
        for i in 0..<pts.count {
            sxx += (xs[i] - mx) * (xs[i] - mx)
            sxy += (xs[i] - mx) * (ys[i] - my)
        }
        guard sxx > 0 else { return nil }
        let slope = sxy / sxx
        let intercept = my - slope * mx
        return StatsTrendLine(startDate: first.mid, endDate: last.mid,
                              startValue: max(0, intercept),
                              endValue: max(0, intercept + slope * (xs.last ?? 0)))
    }
}
