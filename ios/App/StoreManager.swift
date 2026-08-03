import Foundation
import Observation

// Premium wurde entfernt: Alle Funktionen sind kostenlos.
// Diese Fassung behält die bekannte API (hasAccess, isPremium, purchase,
// restorePurchases, startTrialIfNeeded), damit die aufrufenden Views
// unverändert kompilieren — sie tut aber nichts mehr mit StoreKit.
// Dadurch lädt die App keine In-App-Käufe mehr und der Reviewer kann
// nicht über nicht ladende Produkte stolpern.
@Observable
final class StoreManager {
    // Immer freigeschaltet
    let isPremium = true
    var hasAccess: Bool { true }

    // Nur noch da, damit vorhandene Views weiterhin kompilieren.
    // Werden nirgends mehr sinnvoll benutzt.
    let isTrialActive = false
    let trialDaysLeft = 0
    let productsLoaded = true
    let purchaseError: String? = nil
    let productsError: String? = nil

    init() {}

    // MARK: - No-ops (frühere Kauf-/Trial-Logik)

    func startTrialIfNeeded() {}
    func checkTrialStatus() {}
    func restorePurchases() async {}
    func checkSubscriptionStatus() async {}
}
