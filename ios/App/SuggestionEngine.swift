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
