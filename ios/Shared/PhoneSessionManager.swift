//
//  PhoneSessionManager.swift
//  Blase & Darm Manager (iOS-Target!)
//
//  Gegenstück zur Watch: empfängt Schnelleinträge und reicht sie an
//  deinen Datenspeicher weiter. Diese Datei kommt ins iOS-Target,
//  NICHT ins Watch-Target.
//
//  Einbau:
//    1. Datei ins iOS-Target ziehen.
//    2. Beim App-Start einmal aktivieren, z. B. im App-Init:
//         _ = PhoneSessionManager.shared
//    3. Unten bei "HIER ANDOCKEN" deinen Speicheraufruf einsetzen.
//

import Foundation
import WatchConnectivity

final class PhoneSessionManager: NSObject {

    static let shared = PhoneSessionManager()

    /// Wird für jeden empfangenen Watch-Eintrag aufgerufen (auf dem Main-Thread).
    /// kind: "bladder" oder "bowel", date: Zeitpunkt des Tippers auf der Uhr.
    var onQuickEntry: ((_ kind: String, _ date: Date) -> Void)?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func handle(_ payload: [String: Any]) {
        guard payload["type"] as? String == "quickEntry",
              let kind = payload["kind"] as? String,
              let ts = payload["date"] as? TimeInterval else { return }
        let date = Date(timeIntervalSince1970: ts)

        DispatchQueue.main.async {
            // ================= HIER ANDOCKEN =================
            // Beispiel — ersetze das durch deinen echten Speicher:
            //   DataStore.shared.addEntry(kind: kind, date: date)
            // =================================================
            self.onQuickEntry?(kind, date)
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneSessionManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    // Direktnachricht (iPhone erreichbar): mit Antwort quittieren
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        handle(message)
        replyHandler(["ok": true])
    }

    // Nachgelieferte Einträge aus der Warteschlange (iPhone war nicht erreichbar)
    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String : Any]) {
        handle(userInfo)
    }

    // iOS-Pflichtmethoden
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
