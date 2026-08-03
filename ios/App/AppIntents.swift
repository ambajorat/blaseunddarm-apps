import AppIntents
import ActivityKit
import Foundation

enum SiriUrineColor: String, AppEnum {
    case clear = "durchsichtig"
    case lightYellow = "hell gelb"
    case darkYellow = "dunkel gelb"
    case cloudy = "trueb"
    case none = "keine"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Urinfarbe")
    static var caseDisplayRepresentations: [SiriUrineColor: DisplayRepresentation] = [
        .clear: "Durchsichtig",
        .lightYellow: "Hell gelb",
        .darkYellow: "Dunkel gelb",
        .cloudy: "Trueb",
        .none: "Keine Angabe"
    ]

    var toUrineColor: UrineColor {
        switch self {
        case .clear: .clear
        case .lightYellow: .lightYellow
        case .darkYellow: .darkYellow
        case .cloudy: .cloudy
        case .none: .none
        }
    }
}

// MARK: - Eintrag erfassen via Siri/Shortcuts
// Diese Intents starten eine Live Activity und nehmen daher LiveActivityIntent an,
// damit iOS das auch aus dem Hintergrund (Siri) erlaubt.

struct LogEntryIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toilettengang erfassen"
    static var description: IntentDescription = "Erfasst einen neuen Toilettengang"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Menge in ml", requestValueDialog: "Wie viel Milliliter?")    var urineMl: Int?

    @Parameter(title: "Stuhlgang")
    var bowel: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Erfasse \(\.$urineMl) ml Urin, Stuhlgang: \(\.$bowel)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = SharedDataStore.shared
        let entry = ToiletEntry(
            urineMl: urineMl ?? 0,
            bowel: bowel
        )
        store.addEntry(entry)
        NotificationManager.rescheduleReminder(
            afterMinutes: store.settings.intervalMinutes,
            settings: store.settings
        )
        await LiveActivityManager.shared.startTimer(
            from: entry.timestamp,
            intervalMinutes: store.settings.intervalMinutes,
            todayMl: store.todayMl,
            todayCount: store.todayCount,
            settings: store.settings
        )

        let msg = if bowel && (urineMl ?? 0) > 0 {
            "Eintrag gespeichert: \(urineMl ?? 0) ml Urin und Stuhlgang"
        } else if bowel {
            "Eintrag gespeichert: Stuhlgang"
        } else {
            "Eintrag gespeichert: \(urineMl ?? 0) ml Urin"
        }
        return .result(dialog: "\(msg)")
    }
}

// MARK: - Schnelleintrag nur Urin

struct QuickUrineIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Urin erfassen"
    static var description: IntentDescription = "Erfasst schnell eine Urinmenge"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Menge in ml", requestValueDialog: "Wie viel Milliliter?")
    var amount: Int

    @Parameter(title: "Urinfarbe", requestValueDialog: "Welche Farbe hatte der Urin?")
    var color: SiriUrineColor

    static var parameterSummary: some ParameterSummary {
        Summary("Erfasse \(\.$amount) ml Urin, Farbe: \(\.$color)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = SharedDataStore.shared
        let entry = ToiletEntry(urineMl: amount, urineColor: color.toUrineColor)
        store.addEntry(entry)
        NotificationManager.rescheduleReminder(
            afterMinutes: store.settings.intervalMinutes,
            settings: store.settings
        )
        await LiveActivityManager.shared.startTimer(
            from: entry.timestamp,
            intervalMinutes: store.settings.intervalMinutes,
            todayMl: store.todayMl,
            todayCount: store.todayCount,
            settings: store.settings
        )
        return .result(dialog: "\(amount) ml Urin erfasst (\(color.rawValue))")
    }
}

// MARK: - Schnelleintrag nur Stuhlgang

struct QuickBowelIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stuhlgang erfassen"
    static var description: IntentDescription = "Erfasst einen Stuhlgang"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = SharedDataStore.shared
        let entry = ToiletEntry(bowel: true)
        store.addEntry(entry)
        NotificationManager.rescheduleReminder(
            afterMinutes: store.settings.intervalMinutes,
            settings: store.settings
        )
        await LiveActivityManager.shared.startTimer(
            from: entry.timestamp,
            intervalMinutes: store.settings.intervalMinutes,
            todayMl: store.todayMl,
            todayCount: store.todayCount,
            settings: store.settings
        )
        return .result(dialog: "Stuhlgang erfasst")
    }
}

// MARK: - Tagesübersicht abfragen

struct TodaySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Tagesübersicht"
    static var description: IntentDescription = "Zeigt die heutige Zusammenfassung"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = SharedDataStore.shared
        let ml = store.todayMl
        let bowel = store.todayBowel
        let count = store.todayCount
        return .result(dialog: "Heute: \(ml) ml Urin, \(bowel)× Stuhlgang, \(count) Einträge")
    }
}

// MARK: - Timer Status

struct TimerStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Timer-Status"
    static var description: IntentDescription = "Zeigt die verbleibende Zeit bis zur nächsten Erinnerung"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = SharedDataStore.shared
        guard let last = store.lastEntry else {
            return .result(dialog: "Kein Eintrag vorhanden. Erfasse zuerst einen Toilettengang.")
        }
        let elapsed = Int(Date.now.timeIntervalSince(last.timestamp))
        let remaining = (store.settings.intervalMinutes * 60) - elapsed
        if remaining <= 0 {
            let overdue = abs(remaining) / 60
            return .result(dialog: "Überfällig seit \(overdue) Minuten!")
        } else {
            let mins = remaining / 60
            return .result(dialog: "Nächste Erinnerung in \(mins) Minuten")
        }
    }
}

// MARK: - Shortcuts Provider

struct BDMShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickUrineIntent(),
            phrases: [
                "Erfasse Urin in \(.applicationName)",
                "Urin protokollieren mit \(.applicationName)",
                "\(.applicationName) Urin erfassen",
                "Log urine in \(.applicationName)",
                "Record urine with \(.applicationName)"
            ],
            shortTitle: "Urin erfassen",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: QuickBowelIntent(),
            phrases: [
                "Erfasse Stuhlgang in \(.applicationName)",
                "Stuhlgang protokollieren mit \(.applicationName)",
                "\(.applicationName) Stuhlgang",
                "Log bowel movement in \(.applicationName)",
                "Record stool with \(.applicationName)"
            ],
            shortTitle: "Stuhlgang erfassen",
            systemImageName: "checkmark.circle.fill"
        )

        AppShortcut(
            intent: TodaySummaryIntent(),
            phrases: [
                "Tagesübersicht von \(.applicationName)",
                "Wie war mein Tag mit \(.applicationName)",
                "\(.applicationName) Zusammenfassung",
                "Today summary from \(.applicationName)",
                "How is my day with \(.applicationName)"
            ],
            shortTitle: "Tagesübersicht",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: TimerStatusIntent(),
            phrases: [
                "Wann muss ich auf Toilette \(.applicationName)",
                "Timer Status von \(.applicationName)",
                "\(.applicationName) nächste Erinnerung",
                "When is my next reminder \(.applicationName)",
                "Timer status from \(.applicationName)"
            ],
            shortTitle: "Timer-Status",
            systemImageName: "timer"
        )
    }
}
