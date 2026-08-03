import Foundation
import Observation

@Observable
final class CloudBackupManager {
    var isAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }
    var lastBackupDate: Date?
    var status: BackupStatus = .idle

    enum BackupStatus: Equatable {
        case idle
        case syncing
        case success(String)
        case error(String)
    }

    private let fileName = "blase_darm_backup.json"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        loadLastBackupDate()
    }

    // MARK: - Backup

    func backup(entries: [ToiletEntry], settings: AppSettings) {
        guard isAvailable else {
            status = .error("iCloud nicht verfügbar. Prüfe deine iCloud-Einstellungen.")
            return
        }

        status = .syncing

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            do {
                guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                    DispatchQueue.main.async { self.status = .error("iCloud-Container nicht gefunden.") }
                    return
                }

                let documentsURL = containerURL.appendingPathComponent("Documents")
                try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)

                let backup = BackupData(
                    entries: entries,
                    settings: settings,
                    backupDate: .now,
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                )

                let data = try encoder.encode(backup)
                let fileURL = documentsURL.appendingPathComponent(fileName)
                try data.write(to: fileURL, options: .atomic)

                DispatchQueue.main.async {
                    self.lastBackupDate = .now
                    self.saveLastBackupDate()
                    self.status = .success("\(entries.count) Einträge gesichert")
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = .error("Backup fehlgeschlagen: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Restore

    func restore(completion: @escaping ([ToiletEntry], AppSettings?) -> Void) {
        guard isAvailable else {
            status = .error("iCloud nicht verfügbar.")
            return
        }

        status = .syncing

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            do {
                guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                    DispatchQueue.main.async { self.status = .error("iCloud-Container nicht gefunden.") }
                    return
                }

                let fileURL = containerURL
                    .appendingPathComponent("Documents")
                    .appendingPathComponent(fileName)

                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    DispatchQueue.main.async { self.status = .error("Kein Backup gefunden.") }
                    return
                }

                // Start downloading if needed
                try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)

                let data = try Data(contentsOf: fileURL)
                let backup = try decoder.decode(BackupData.self, from: data)

                DispatchQueue.main.async {
                    completion(backup.entries, backup.settings)
                    self.status = .success("\(backup.entries.count) Einträge wiederhergestellt")
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = .error("Wiederherstellung fehlgeschlagen: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Last Backup Date

    private func saveLastBackupDate() {
        UserDefaults.standard.set(lastBackupDate, forKey: "lastCloudBackup")
    }

    private func loadLastBackupDate() {
        lastBackupDate = UserDefaults.standard.object(forKey: "lastCloudBackup") as? Date
    }
}

// MARK: - Backup Model

struct BackupData: Codable {
    let entries: [ToiletEntry]
    let settings: AppSettings
    let backupDate: Date
    let appVersion: String
}
