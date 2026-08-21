import SwiftUI
import StoreKit

/// Entscheidet, WANN wir das System-Bewertungsfenster anfragen dürfen.
/// Das eigentliche Anzeigen übernimmt Apples requestReview-Environment —
/// Apple deckelt systemseitig zusätzlich auf max. 3 Anzeigen pro Jahr,
/// und in Debug/TestFlight erscheint der Dialog grundsätzlich nie.
enum ReviewGate {

    /// Glücksmomente: nach so vielen gespeicherten Einträgen fragen wir (je einmal).
    private static let thresholds = [20, 60, 150]

    /// Frühestens alle 60 Tage erneut fragen, maximal 3-mal in 365 Tagen.
    private static let minDaysBetween = 60
    private static let maxPerYear = 3

    private static let doneKey = "bb_review_done_thresholds"
    private static let datesKey = "bb_review_request_dates"

    static func shouldRequest(entryCount: Int) -> Bool {
        let defaults = UserDefaults.standard
        let done = defaults.array(forKey: doneKey) as? [Int] ?? []

        // Nächste noch nicht quittierte Schwelle, die erreicht ist?
        guard thresholds.contains(where: { entryCount >= $0 && !done.contains($0) }) else {
            return false
        }

        let dates = (defaults.array(forKey: datesKey) as? [Date] ?? [])
        let yearAgo = Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? .distantPast
        let recent = dates.filter { $0 > yearAgo }
        guard recent.count < maxPerYear else { return false }

        if let last = recent.max() {
            let cutoff = Calendar.current.date(byAdding: .day, value: -minDaysBetween, to: Date()) ?? .distantPast
            guard last < cutoff else { return false }
        }
        return true
    }

    /// Markiert ALLE erreichten Schwellen als erledigt (verhindert Doppelfeuer,
    /// wenn ein CSV-Import den Zähler über mehrere Schwellen springen lässt).
    static func markRequested(entryCount: Int) {
        let defaults = UserDefaults.standard
        var done = defaults.array(forKey: doneKey) as? [Int] ?? []
        for t in thresholds where entryCount >= t && !done.contains(t) { done.append(t) }
        defaults.set(done, forKey: doneKey)

        var dates = defaults.array(forKey: datesKey) as? [Date] ?? []
        dates.append(Date())
        defaults.set(dates, forKey: datesKey)
    }
}

/// Hängt an der ContentView und beobachtet die Eintragszahl.
/// Fragt mit 2 Sekunden Verzögerung an, damit der Dialog nicht mitten
/// in die Speichern-Bestätigung platzt.
struct ReviewRequester: ViewModifier {
    @Environment(DataStore.self) private var store
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.onChange(of: store.entries.count) { _, newCount in
            guard ReviewGate.shouldRequest(entryCount: newCount) else { return }
            ReviewGate.markRequested(entryCount: newCount)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                requestReview()
            }
        }
    }
}
