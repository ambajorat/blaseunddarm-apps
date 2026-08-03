import Foundation
import WatchConnectivity
import Observation

@Observable
final class ConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = ConnectivityManager()
    var onEntriesReceived: (([ToiletEntry]) -> Void)?
    var onSettingsReceived: ((AppSettings) -> Void)?
    var onNewEntry: ((ToiletEntry) -> Void)?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Send from iPhone to Watch

    func sendEntriesToWatch(_ entries: [ToiletEntry], settings: AppSettings) {
        guard WCSession.default.isReachable else {
            // Use application context for background delivery
            sendContext(entries: entries, settings: settings)
            return
        }
        guard let entriesData = try? encoder.encode(entries),
              let settingsData = try? encoder.encode(settings) else { return }
        WCSession.default.sendMessage([
            "entries": entriesData,
            "settings": settingsData
        ], replyHandler: nil)
    }

    func sendContext(entries: [ToiletEntry], settings: AppSettings) {
        guard let entriesData = try? encoder.encode(Array(entries.prefix(50))),
              let settingsData = try? encoder.encode(settings) else { return }
        try? WCSession.default.updateApplicationContext([
            "entries": entriesData,
            "settings": settingsData
        ])
    }

    // MARK: - Send from Watch to iPhone

    func sendNewEntry(_ entry: ToiletEntry) {
        guard let data = try? encoder.encode(entry) else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["newEntry": data], replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(["newEntry": data])
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { [self] in
            // iPhone receives new entry from Watch
            if let data = message["newEntry"] as? Data,
               let entry = try? decoder.decode(ToiletEntry.self, from: data) {
                onNewEntry?(entry)
            }
            // Watch receives entries + settings from iPhone
            if let entriesData = message["entries"] as? Data,
               let entries = try? decoder.decode([ToiletEntry].self, from: entriesData) {
                onEntriesReceived?(entries)
            }
            if let settingsData = message["settings"] as? Data,
               let settings = try? decoder.decode(AppSettings.self, from: settingsData) {
                onSettingsReceived?(settings)
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { [self] in
            if let entriesData = applicationContext["entries"] as? Data,
               let entries = try? decoder.decode([ToiletEntry].self, from: entriesData) {
                onEntriesReceived?(entries)
            }
            if let settingsData = applicationContext["settings"] as? Data,
               let settings = try? decoder.decode(AppSettings.self, from: settingsData) {
                onSettingsReceived?(settings)
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async { [self] in
            if let data = userInfo["newEntry"] as? Data,
               let entry = try? decoder.decode(ToiletEntry.self, from: data) {
                onNewEntry?(entry)
            }
        }
    }
}
