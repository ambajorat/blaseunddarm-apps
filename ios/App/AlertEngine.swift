import Foundation
import UserNotifications

// MARK: - Status fürs UI

enum RuleState { case ok, warn, waiting, noData }

struct RuleStatus: Identifiable {
    let id: String
    let title: String
    let detail: String
    let state: RuleState
}

struct Baseline {
    let avgMl: Int
    let avgCount: Double
    let days: Int
}

// MARK: - Engine

enum AlertEngine {

    /// Ab dieser Stunde werden "Unter"-Grenzen und Abweichungen nach unten
    /// bewertet — vorher wäre jeder Morgen automatisch "zu wenig".
    static let underCheckHour = 18
    /// Ab dieser Uhrzeit wird der Vortag bewertet (nicht mitten in der Nacht).
    static let morningCheckHour = 9

    // MARK: Baseline

    /// Ø der letzten 14 vollen Tage (ohne heute), nur Tage mit Einträgen.
    /// Mindestens 5 Datentage, sonst keine Baseline.
    static func baseline(entries: [ToiletEntry]) -> Baseline? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var mlValues: [Int] = []
        var counts: [Int] = []
        for i in 1...14 {
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let dayEntries = entries.filter { cal.isDate($0.timestamp, inSameDayAs: day) }
            guard !dayEntries.isEmpty else { continue }
            mlValues.append(dayEntries.reduce(0) { $0 + $1.urineMl })
            counts.append(dayEntries.count)
        }
        guard mlValues.count >= 5 else { return nil }
        return Baseline(
            avgMl: mlValues.reduce(0, +) / mlValues.count,
            avgCount: Double(counts.reduce(0, +)) / Double(counts.count),
            days: mlValues.count
        )
    }

    // MARK: Prüfungen mit Benachrichtigung

    /// Sofort beim Speichern eines Eintrags (App, Siri, Watch via DataStore).
    static func checkEntry(_ entry: ToiletEntry, settings: AlertSettings = .load()) {
        checkUtiEntry(entry)
        checkAdEntry(entry)
        guard settings.singleOverEnabled,
              entry.urineMl >= settings.singleOverMl else { return }
        notifyOnce(
            rule: "single_\(entry.id.uuidString)",
            title: String(localized: "Hohe Einzelmenge"),
            body: String(localized: "\(entry.urineMl) ml auf einmal — über deiner Grenze von \(settings.singleOverMl) ml."),
            timeSensitive: true
        )
    }

    /// Tages-Checks: "Über" sofort (Grenze schon gerissen = aussagekräftig),
    /// "Unter" und Abweichungen nach unten bewerten den ABGESCHLOSSENEN Vortag.
    static func checkDay(entries: [ToiletEntry], settings: AlertSettings = .load()) {
        let cal = Calendar.current
        let today = entries.filter { cal.isDateInToday($0.timestamp) }
        let ml = today.reduce(0) { $0 + $1.urineMl }
        let count = today.count
        let dateKey = Date.now.formatted(.iso8601.year().month().day())
        let base = settings.baselineEnabled ? baseline(entries: entries) : nil
        let dev = Double(settings.baselineDeviationPercent) / 100.0

        if settings.dayOverEnabled, ml >= settings.dayOverMl {
            notifyOnce(rule: "dayOver_\(dateKey)",
                       title: String(localized: "Hohe Tagesmenge"),
                       body: String(localized: "Heute schon \(ml) ml — über deiner Grenze von \(settings.dayOverMl) ml."))
        }
        if settings.countOverEnabled, count >= settings.countOverLimit {
            notifyOnce(rule: "countOver_\(dateKey)",
                       title: String(localized: "Viele Toilettengänge"),
                       body: String(localized: "Heute schon \(count) Gänge — über deiner Grenze von \(settings.countOverLimit)."))
        }
        if let base {
            if Double(ml) > Double(base.avgMl) * (1 + dev) {
                notifyOnce(rule: "baseMlOver_\(dateKey)",
                           title: String(localized: "Deutlich über deinem Schnitt"),
                           body: String(localized: "Heute \(ml) ml — dein 14-Tage-Schnitt liegt bei \(base.avgMl) ml."))
            }
            if Double(count) > base.avgCount * (1 + dev) {
                notifyOnce(rule: "baseCountOver_\(dateKey)",
                           title: String(localized: "Häufiger als sonst"),
                           body: String(localized: "Heute \(count) Gänge — dein Schnitt liegt bei \(String(format: "%.0f", base.avgCount))."))
            }
        }

        checkCatheterStock(entries: entries, dateKey: dateKey)
        checkUtiDay(entries: entries, dateKey: dateKey)

        // "Unter" bewertet den ABGESCHLOSSENEN Vortag — ein Teiltag ("heute erst
        // 4 Gänge um 18 Uhr") sagt nichts aus. Ausgewertet ab morgens beim ersten
        // Check des Tages; Vortage ganz ohne Einträge werden übersprungen
        // (App-Pause ist kein "zu wenig").
        guard cal.component(.hour, from: .now) >= morningCheckHour else { return }
        let yesterday = entries.filter { cal.isDateInYesterday($0.timestamp) }
        guard !yesterday.isEmpty else { return }
        let yMl = yesterday.reduce(0) { $0 + $1.urineMl }
        let yCount = yesterday.count
        let yKey = cal.date(byAdding: .day, value: -1, to: .now)!
            .formatted(.iso8601.year().month().day())

        if settings.dayUnderEnabled, yMl < settings.dayUnderMl {
            notifyOnce(rule: "dayUnder_\(yKey)",
                       title: String(localized: "Niedrige Tagesmenge"),
                       body: String(localized: "Gestern \(yMl) ml — unter deiner Grenze von \(settings.dayUnderMl) ml. Genug getrunken?"))
        }
        if settings.countUnderEnabled, yCount < settings.countUnderLimit {
            notifyOnce(rule: "countUnder_\(yKey)",
                       title: String(localized: "Wenige Toilettengänge"),
                       body: String(localized: "Gestern \(yCount) Gänge — unter deiner Grenze von \(settings.countUnderLimit)."))
        }
        if let base {
            if Double(yMl) < Double(base.avgMl) * (1 - dev) {
                notifyOnce(rule: "baseMlUnder_\(yKey)",
                           title: String(localized: "Deutlich unter deinem Schnitt"),
                           body: String(localized: "Gestern \(yMl) ml — dein 14-Tage-Schnitt liegt bei \(base.avgMl) ml."))
            }
            if Double(yCount) < base.avgCount * (1 - dev) {
                notifyOnce(rule: "baseCountUnder_\(yKey)",
                           title: String(localized: "Seltener als sonst"),
                           body: String(localized: "Gestern \(yCount) Gänge — dein Schnitt liegt bei \(String(format: "%.0f", base.avgCount))."))
            }
        }
    }

    // MARK: Vegetative Zeichen (AD)

    /// Hinweis, wenn vegetative Zeichen OHNE Entleerung erfasst wurden —
    /// Erinnerung an etabliertes Vorgehen, keine Diagnose.
    static func checkAdEntry(_ entry: ToiletEntry, ad: AdSettings = .load()) {
        guard ad.enabled, let signs = entry.adSigns, !signs.isEmpty, entry.urineMl == 0 else { return }
        notifyOnce(
            rule: "adSigns_\(entry.id.uuidString)",
            title: String(localized: "Vegetative Zeichen erfasst"),
            body: String(localized: "Bei voller Blase können das Füllungssignale sein — Blase entleeren und mögliche Auslöser prüfen."),
            timeSensitive: true
        )
    }

    // MARK: HWI-Frühwarnung

    /// Sofort-Hinweis bei dringlichen Anzeichen (Blut, Fieber) am Eintrag.
    /// Bewusst KEINE Diagnose-Sprache — nur Beobachtung + Empfehlung.
    static func checkUtiEntry(_ entry: ToiletEntry, uti: UtiSettings = .load()) {
        guard uti.enabled, let syms = entry.symptoms, !syms.isEmpty else { return }
        let urgent = syms.filter { $0.isUrgent }
        guard !urgent.isEmpty else { return }
        let names = urgent.map(\.label).joined(separator: ", ")
        notifyOnce(
            rule: "utiUrgent_\(entry.id.uuidString)",
            title: String(localized: "Auffälligkeit erfasst"),
            body: String(localized: "\(names) — bei ISK bitte zeitnah ärztlich abklären."),
            timeSensitive: true
        )
    }

    /// Muster-Checks: Symptome an zwei Tagen in Folge sowie
    /// überwiegend dunkler/trüber Urin an mehreren Tagen.
    static func checkUtiDay(entries: [ToiletEntry], dateKey: String, uti: UtiSettings = .load()) {
        guard uti.enabled else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        func daySymptoms(_ offset: Int) -> Set<UtiSymptom> {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return [] }
            let dayEntries = entries.filter { cal.isDate($0.timestamp, inSameDayAs: day) }
            return Set(dayEntries.flatMap { $0.symptoms ?? [] })
        }

        // Regel: Symptome heute UND gestern, insgesamt mindestens 2 verschiedene.
        let t = daySymptoms(0)
        let y = daySymptoms(1)
        if !t.isEmpty, !y.isEmpty, t.union(y).count >= 2 {
            notifyOnce(
                rule: "utiPattern_\(dateKey)",
                title: String(localized: "Auffälligkeiten seit zwei Tagen"),
                body: String(localized: "Mehrere Anzeichen an zwei Tagen in Folge — das kann bei ISK auf einen Harnwegsinfekt hindeuten. Ggf. ärztlich abklären.")
            )
        }

        // Regel: An mindestens 2 der letzten 3 Tage überwiegend dunkler/trüber Urin.
        var darkDays = 0
        for i in 0...2 {
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let colored = entries.filter { cal.isDate($0.timestamp, inSameDayAs: day) && $0.urineColor != .none }
            guard !colored.isEmpty else { continue }
            let dark = colored.filter { $0.urineColor == .darkYellow || $0.urineColor == .cloudy }.count
            if dark * 2 > colored.count { darkDays += 1 }
        }
        if darkDays >= 2 {
            notifyOnce(
                rule: "utiColor_\(dateKey)",
                title: String(localized: "Urin auffällig dunkel oder trüb"),
                body: String(localized: "An mehreren Tagen überwiegend dunkler oder trüber Urin — mehr trinken und beobachten; hält es an, ärztlich abklären.")
            )
        }
    }

    // MARK: Katheterbestand

    /// Warnt einmal am Tag, wenn die rechnerische Reichweite unter die
    /// eingestellte Grenze fällt. Eigene Settings (CatheterStock), damit
    /// AlertSettings von Bestandsnutzern unangetastet bleiben.
    static func checkCatheterStock(entries: [ToiletEntry], dateKey: String, stock: CatheterStock = .load()) {
        guard stock.enabled else { return }
        let sorts = stock.effectiveSorts
        for sort in sorts {
            guard let days = stock.daysRemaining(of: sort, entries: entries), days <= stock.warnDays else { continue }
            let count = stock.stock(of: sort, entries: entries)
            let body: String
            if sorts.count > 1 {
                if let empty = stock.estimatedEmptyDate(of: sort, entries: entries) {
                    body = String(localized: "Noch \(count) Katheter (\(sort.name)) — reicht etwa bis \(empty.formatted(.dateTime.day().month())). Zeit fürs Rezept.")
                } else {
                    body = String(localized: "Noch \(count) Katheter (\(sort.name)). Zeit fürs Rezept.")
                }
            } else {
                if let empty = stock.estimatedEmptyDate(of: sort, entries: entries) {
                    body = String(localized: "Noch \(count) Katheter — reicht etwa bis \(empty.formatted(.dateTime.day().month())). Zeit fürs Rezept.")
                } else {
                    body = String(localized: "Noch \(count) Katheter. Zeit fürs Rezept.")
                }
            }
            notifyOnce(rule: "cathLow_\(dateKey)_\(sort.name)",
                       title: String(localized: "Katheter werden knapp"),
                       body: body)
        }
    }

    // MARK: Status-Liste für den Hinweise-Reiter

    static func statusList(entries: [ToiletEntry], settings: AlertSettings) -> [RuleStatus] {
        let cal = Calendar.current
        let today = entries.filter { cal.isDateInToday($0.timestamp) }
        let ml = today.reduce(0) { $0 + $1.urineMl }
        let count = today.count
        let maxSingle = today.map(\.urineMl).max() ?? 0
        let lateEnough = cal.component(.hour, from: .now) >= underCheckHour
        let base = baseline(entries: entries)
        let dev = Double(settings.baselineDeviationPercent) / 100.0

        var result: [RuleStatus] = []

        if settings.singleOverEnabled {
            result.append(RuleStatus(
                id: "single",
                title: String(localized: "Einzelmenge"),
                detail: String(localized: "größte heute: \(maxSingle) ml · Grenze \(settings.singleOverMl) ml"),
                state: maxSingle >= settings.singleOverMl ? .warn : .ok
            ))
        }
        if settings.dayOverEnabled {
            result.append(RuleStatus(
                id: "dayOver",
                title: String(localized: "Tagesmenge zu hoch"),
                detail: String(localized: "\(ml) ml · Grenze \(settings.dayOverMl) ml"),
                state: ml >= settings.dayOverMl ? .warn : .ok
            ))
        }
        if settings.dayUnderEnabled {
            result.append(RuleStatus(
                id: "dayUnder",
                title: String(localized: "Tagesmenge zu niedrig"),
                detail: String(localized: "\(ml) ml · Grenze \(settings.dayUnderMl) ml"),
                state: !lateEnough ? .waiting : (ml < settings.dayUnderMl ? .warn : .ok)
            ))
        }
        if settings.countOverEnabled {
            result.append(RuleStatus(
                id: "countOver",
                title: String(localized: "Zu viele Gänge"),
                detail: String(localized: "\(count) · Grenze \(settings.countOverLimit)"),
                state: count >= settings.countOverLimit ? .warn : .ok
            ))
        }
        if settings.countUnderEnabled {
            result.append(RuleStatus(
                id: "countUnder",
                title: String(localized: "Zu wenige Gänge"),
                detail: String(localized: "\(count) · Grenze \(settings.countUnderLimit)"),
                state: !lateEnough ? .waiting : (count < settings.countUnderLimit ? .warn : .ok)
            ))
        }
        if settings.baselineEnabled {
            if let base {
                let mlHigh = Double(ml) > Double(base.avgMl) * (1 + dev)
                let mlLow = lateEnough && Double(ml) < Double(base.avgMl) * (1 - dev)
                let cntHigh = Double(count) > base.avgCount * (1 + dev)
                let cntLow = lateEnough && Double(count) < base.avgCount * (1 - dev)
                let deviates = mlHigh || mlLow || cntHigh || cntLow
                result.append(RuleStatus(
                    id: "baseline",
                    title: String(localized: "Abweichung vom Schnitt"),
                    detail: String(localized: "Ø \(base.avgMl) ml · Ø \(String(format: "%.0f", base.avgCount)) Gänge (\(base.days) Tage) · ±\(settings.baselineDeviationPercent) %"),
                    state: deviates ? .warn : .ok
                ))
            } else {
                result.append(RuleStatus(
                    id: "baseline",
                    title: String(localized: "Abweichung vom Schnitt"),
                    detail: String(localized: "Noch nicht genug Daten (mind. 5 Tage mit Einträgen in den letzten 14 Tagen)"),
                    state: .noData
                ))
            }
        }
        return result
    }

    // MARK: Benachrichtigung mit Dedup (pro Regel/Tag genau einmal)

    private static func notifyOnce(rule: String, title: String, body: String, timeSensitive: Bool = false) {
        let flag = "bb_alert_fired_\(rule)"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)

        let content = UNMutableNotificationContent()
        content.title = "💡 \(title)"
        content.body = body
        content.sound = .default
        content.interruptionLevel = timeSensitive ? .timeSensitive : .active

        let request = UNNotificationRequest(
            identifier: "alert_\(rule)",
            content: content,
            trigger: nil // sofort
        )
        UNUserNotificationCenter.current().add(request)
    }
}
