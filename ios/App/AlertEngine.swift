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
        guard settings.singleOverEnabled,
              entry.urineMl >= settings.singleOverMl else { return }
        notifyOnce(
            rule: "single_\(entry.id.uuidString)",
            title: "Hohe Einzelmenge",
            body: "\(entry.urineMl) ml auf einmal — über deiner Grenze von \(settings.singleOverMl) ml.",
            timeSensitive: true
        )
    }

    /// Tages-Checks: "Über" sofort, "Unter" und Abweichungen nach unten ab 18 Uhr.
    static func checkDay(entries: [ToiletEntry], settings: AlertSettings = .load()) {
        let cal = Calendar.current
        let today = entries.filter { cal.isDateInToday($0.timestamp) }
        let ml = today.reduce(0) { $0 + $1.urineMl }
        let count = today.count
        let dateKey = Date.now.formatted(.iso8601.year().month().day())
        let lateEnough = cal.component(.hour, from: .now) >= underCheckHour
        let base = settings.baselineEnabled ? baseline(entries: entries) : nil
        let dev = Double(settings.baselineDeviationPercent) / 100.0

        if settings.dayOverEnabled, ml >= settings.dayOverMl {
            notifyOnce(rule: "dayOver_\(dateKey)",
                       title: "Hohe Tagesmenge",
                       body: "Heute schon \(ml) ml — über deiner Grenze von \(settings.dayOverMl) ml.")
        }
        if settings.countOverEnabled, count >= settings.countOverLimit {
            notifyOnce(rule: "countOver_\(dateKey)",
                       title: "Viele Toilettengänge",
                       body: "Heute schon \(count) Gänge — über deiner Grenze von \(settings.countOverLimit).")
        }
        if let base {
            if Double(ml) > Double(base.avgMl) * (1 + dev) {
                notifyOnce(rule: "baseMlOver_\(dateKey)",
                           title: "Deutlich über deinem Schnitt",
                           body: "Heute \(ml) ml — dein 14-Tage-Schnitt liegt bei \(base.avgMl) ml.")
            }
            if Double(count) > base.avgCount * (1 + dev) {
                notifyOnce(rule: "baseCountOver_\(dateKey)",
                           title: "Häufiger als sonst",
                           body: "Heute \(count) Gänge — dein Schnitt liegt bei \(String(format: "%.0f", base.avgCount)).")
            }
        }

        checkCatheterStock(entries: entries, dateKey: dateKey)

        guard lateEnough else { return }

        if settings.dayUnderEnabled, ml < settings.dayUnderMl {
            notifyOnce(rule: "dayUnder_\(dateKey)",
                       title: "Niedrige Tagesmenge",
                       body: "Bis jetzt \(ml) ml — unter deiner Grenze von \(settings.dayUnderMl) ml. Genug getrunken?")
        }
        if settings.countUnderEnabled, count < settings.countUnderLimit {
            notifyOnce(rule: "countUnder_\(dateKey)",
                       title: "Wenige Toilettengänge",
                       body: "Bis jetzt \(count) Gänge — unter deiner Grenze von \(settings.countUnderLimit).")
        }
        if let base {
            if Double(ml) < Double(base.avgMl) * (1 - dev) {
                notifyOnce(rule: "baseMlUnder_\(dateKey)",
                           title: "Deutlich unter deinem Schnitt",
                           body: "Bis jetzt \(ml) ml — dein 14-Tage-Schnitt liegt bei \(base.avgMl) ml.")
            }
            if Double(count) < base.avgCount * (1 - dev) {
                notifyOnce(rule: "baseCountUnder_\(dateKey)",
                           title: "Seltener als sonst",
                           body: "Bis jetzt \(count) Gänge — dein Schnitt liegt bei \(String(format: "%.0f", base.avgCount)).")
            }
        }
    }

    // MARK: Katheterbestand

    /// Warnt einmal am Tag, wenn die rechnerische Reichweite unter die
    /// eingestellte Grenze fällt. Eigene Settings (CatheterStock), damit
    /// AlertSettings von Bestandsnutzern unangetastet bleiben.
    static func checkCatheterStock(entries: [ToiletEntry], dateKey: String, stock: CatheterStock = .load()) {
        guard stock.enabled else { return }
        guard let days = stock.daysRemaining(entries: entries), days <= stock.warnDays else { return }
        let count = stock.currentStock(entries: entries)
        let body: String
        if let empty = stock.estimatedEmptyDate(entries: entries) {
            body = "Noch \(count) Katheter — reicht etwa bis \(empty.formatted(.dateTime.day().month())). Zeit fürs Rezept."
        } else {
            body = "Noch \(count) Katheter. Zeit fürs Rezept."
        }
        notifyOnce(rule: "cathLow_\(dateKey)",
                   title: "Katheter werden knapp",
                   body: body)
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
                title: "Einzelmenge",
                detail: "größte heute: \(maxSingle) ml · Grenze \(settings.singleOverMl) ml",
                state: maxSingle >= settings.singleOverMl ? .warn : .ok
            ))
        }
        if settings.dayOverEnabled {
            result.append(RuleStatus(
                id: "dayOver",
                title: "Tagesmenge zu hoch",
                detail: "\(ml) ml · Grenze \(settings.dayOverMl) ml",
                state: ml >= settings.dayOverMl ? .warn : .ok
            ))
        }
        if settings.dayUnderEnabled {
            result.append(RuleStatus(
                id: "dayUnder",
                title: "Tagesmenge zu niedrig",
                detail: "\(ml) ml · Grenze \(settings.dayUnderMl) ml",
                state: !lateEnough ? .waiting : (ml < settings.dayUnderMl ? .warn : .ok)
            ))
        }
        if settings.countOverEnabled {
            result.append(RuleStatus(
                id: "countOver",
                title: "Zu viele Gänge",
                detail: "\(count) · Grenze \(settings.countOverLimit)",
                state: count >= settings.countOverLimit ? .warn : .ok
            ))
        }
        if settings.countUnderEnabled {
            result.append(RuleStatus(
                id: "countUnder",
                title: "Zu wenige Gänge",
                detail: "\(count) · Grenze \(settings.countUnderLimit)",
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
                    title: "Abweichung vom Schnitt",
                    detail: "Ø \(base.avgMl) ml · Ø \(String(format: "%.0f", base.avgCount)) Gänge (\(base.days) Tage) · ±\(settings.baselineDeviationPercent) %",
                    state: deviates ? .warn : .ok
                ))
            } else {
                result.append(RuleStatus(
                    id: "baseline",
                    title: "Abweichung vom Schnitt",
                    detail: "Noch nicht genug Daten (mind. 5 Tage mit Einträgen in den letzten 14 Tagen)",
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
