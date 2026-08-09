import SwiftUI
import StoreKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(DataStore.self) private var store
    @Environment(NotificationManager.self) private var notifications
    @Environment(CloudBackupManager.self) private var cloudBackup
    @State private var showDeleteConfirm = false
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var importResult: (count: Int, message: String)?
    @State private var showImportResult = false
    @State private var showRestoreConfirm = false
    @State private var newQuickValue = ""
    @State private var drink = DrinkSettings.load()
    @State private var newDrinkValue = ""

    var body: some View {
        NavigationStack {
            List {
                reminderSection
                quickValuesSection
                drinkSection
                cloudSection
                dataSection
                aboutSection
            }
            .navigationTitle(String(localized: "tab_settings"))
            .onChange(of: drink) { _, new in new.save() }
            .alert("Alle Daten löschen?", isPresented: $showDeleteConfirm) {
                Button("Abbrechen", role: .cancel) {}
                Button("Endgültig löschen", role: .destructive) {
                    store.deleteAll()
                }
            } message: {
                Text("Alle \(store.entries.count) Einträge werden unwiderruflich gelöscht.")
            }
            .alert("Backup wiederherstellen?", isPresented: $showRestoreConfirm) {
                Button("Abbrechen", role: .cancel) {}
                Button("Wiederherstellen", role: .destructive) {
                    cloudBackup.restore { entries, settings in
                        store.restoreFromBackup(entries: entries, settings: settings)
                    }
                }
            } message: {
                Text("Deine aktuellen Daten werden durch das Backup ersetzt.")
            }
            .alert(importResult?.message ?? "", isPresented: $showImportResult) {
                Button("OK") {}
            }
            .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                switch result {
                case .success(let url):
                    importCSV(from: url)
                case .failure:
                    importResult = (0, "Datei konnte nicht geöffnet werden.")
                    showImportResult = true
                }
            }
        }
    }

    // MARK: - Reminder Section

    private var reminderSection: some View {
        @Bindable var s = store
        return Section {
            Toggle(isOn: Binding(
                get: { store.settings.reminderEnabled },
                set: { newVal in
                    store.settings.reminderEnabled = newVal
                    if !newVal { notifications.cancelAll() }
                }
            )) {
                Label("Erinnerungen", systemImage: store.settings.reminderEnabled ? "bell.fill" : "bell.slash")
            }

            if store.settings.reminderEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Schnellwahl")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 8) {
                        ForEach(AppSettings.intervals, id: \.minutes) { item in
                            Button {
                                store.settings.intervalMinutes = item.minutes
                            } label: {
                                Text(item.label)
                                    .font(.subheadline.weight(
                                        store.settings.intervalMinutes == item.minutes ? .bold : .medium
                                    ))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        store.settings.intervalMinutes == item.minutes
                                        ? Color.accentBlue.opacity(0.12)
                                        : Color(.systemGroupedBackground),
                                        in: .rect(cornerRadius: 8)
                                    )
                                    .foregroundStyle(
                                        store.settings.intervalMinutes == item.minutes
                                        ? Color.accentBlue
                                        : .secondary
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)

                // Custom interval with stepper
                Stepper(value: Binding(
                    get: { store.settings.intervalMinutes },
                    set: { store.settings.intervalMinutes = $0 }
                ), in: 15...480, step: 15) {
                    HStack {
                        Text("Intervall")
                        Spacer()
                        Text(formatInterval(store.settings.intervalMinutes))
                            .foregroundStyle(Color.accentBlue)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                }

                if !notifications.permissionGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Benachrichtigungen in den Systemeinstellungen aktivieren.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Quiet hours
                Toggle(isOn: Binding(
                    get: { store.settings.quietHoursEnabled },
                    set: { store.settings.quietHoursEnabled = $0 }
                )) {
                    Label("Ruhezeit", systemImage: "moon.fill")
                }

                if store.settings.quietHoursEnabled {
                    HStack {
                        Text("Von")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { store.settings.quietFrom },
                            set: { store.settings.quietFrom = $0 }
                        )) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d:00", h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("Bis")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { store.settings.quietTo },
                            set: { store.settings.quietTo = $0 }
                        )) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d:00", h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        } header: {
            Text("Erinnerungen")
        }
    }

    private func formatInterval(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) Min" }
        if m == 0 { return "\(h) Std" }
        return "\(h) Std \(m) Min"
    }

    // MARK: - Quick Values Section

    private var quickValuesSection: some View {
        Section {
            ForEach(Array(store.settings.quickValues.enumerated()), id: \.offset) { index, value in
                HStack {
                    Text("\(value) ml")
                        .monospacedDigit()
                    Spacer()
                    Button(role: .destructive) {
                        store.settings.quickValues.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onMove { from, to in
                store.settings.quickValues.move(fromOffsets: from, toOffset: to)
            }

            HStack {
                TextField("Neuer Wert", text: $newQuickValue)
                    .keyboardType(.numberPad)

                Button {
                    if let val = Int(newQuickValue), val > 0 {
                        store.settings.quickValues.append(val)
                        store.settings.quickValues.sort()
                        newQuickValue = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentBlue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(Int(newQuickValue) == nil || Int(newQuickValue)! <= 0)
            }
        } header: {
            Text("Schnellwahl-Mengen (ml)")
        } footer: {
            Text("Diese Werte erscheinen als Schnelltasten beim Erfassen.")
                .font(.caption)
        }
    }

    // MARK: - Trinkmengen (optional)

    private var drinkSection: some View {
        Section {
            Toggle(isOn: $drink.enabled) {
                Label("Trinkmengen erfassen", systemImage: "cup.and.saucer.fill")
            }

            if drink.enabled {
                ForEach(Array(drink.presets.enumerated()), id: \.offset) { index, value in
                    HStack {
                        Text("\(value) ml")
                            .monospacedDigit()
                        Spacer()
                        Button(role: .destructive) {
                            drink.presets.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("Neuer Wert", text: $newDrinkValue)
                        .keyboardType(.numberPad)

                    Button {
                        if let val = Int(newDrinkValue), val > 0 {
                            drink.presets.append(val)
                            drink.presets.sort()
                            newDrinkValue = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentBlue)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(Int(newDrinkValue) == nil || Int(newDrinkValue)! <= 0)
                }
            }
        } header: {
            Text("Trinkmengen")
        } footer: {
            Text(drink.enabled
                 ? "Erscheint beim Erfassen als eigener Abschnitt \u{201E}Getrunken (ml)\u{201C} mit diesen Schnelltasten."
                 : "Optional: Erfasse zusätzlich, wie viel du trinkst — für die Ein-/Ausfuhr-Bilanz.")
                .font(.caption)
        }
    }

    // MARK: - Cloud Section

    private var cloudSection: some View {
        Section {
            if cloudBackup.isAvailable {
                Button {
                    cloudBackup.backup(entries: store.entries, settings: store.settings)
                } label: {
                    HStack {
                        Label("Jetzt sichern", systemImage: "icloud.and.arrow.up")
                        Spacer()
                        if cloudBackup.status == .syncing {
                            ProgressView()
                        }
                    }
                }
                .disabled(cloudBackup.status == .syncing || store.entries.isEmpty)

                Button {
                    showRestoreConfirm = true
                } label: {
                    Label("Wiederherstellen", systemImage: "icloud.and.arrow.down")
                }
                .disabled(cloudBackup.status == .syncing)

                if let lastDate = cloudBackup.lastBackupDate {
                    HStack {
                        Text("Letztes Backup")
                        Spacer()
                        Text(lastDate.formatted(.dateTime.day().month().year().hour().minute()))
                            .foregroundStyle(.secondary)
                    }
                }

                switch cloudBackup.status {
                case .success(let msg):
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .error(let msg):
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                default:
                    EmptyView()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.slash")
                        .foregroundStyle(.secondary)
                    Text("iCloud ist nicht verfügbar. Melde dich in den Systemeinstellungen bei iCloud an.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("iCloud Backup")
        } footer: {
            Text("Sichert alle Einträge und Einstellungen in deinem iCloud Drive.")
                .font(.caption)
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            HStack {
                Text(String(localized: "stored_entries"))
                Spacer()
                Text("\(store.entries.count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let first = store.entries.last {
                HStack {
                    Text(String(localized: "first_entry"))
                    Spacer()
                    Text(first.timestamp.formatted(.dateTime.day().month().year()))
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: exportCSV) {
                Label(String(localized: "export_csv"), systemImage: "square.and.arrow.up")
            }
            .disabled(store.entries.isEmpty)

            Button {
                showImportPicker = true
            } label: {
                Label(String(localized: "import_csv"), systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(String(localized: "delete_all"), systemImage: "trash")
            }
            .disabled(store.entries.isEmpty)
        } header: {
            Text(String(localized: "data"))
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://blaseunddarm.de/datenschutz.html")!) {
                HStack {
                    Label("Datenschutzerklärung", systemImage: "hand.raised")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Button {
                let url = URL(string: "https://apps.apple.com/de/app/blase-darm-manager/id6792282103")
                let av = UIActivityViewController(activityItems: ["Blase & Darm Manager - die App fuer dein Toiletten-Management", url as Any], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let root = scene.windows.first?.rootViewController {
                    if let popover = av.popoverPresentationController { popover.sourceView = root.view }
                    root.present(av, animated: true)
                }
            } label: {
                HStack {
                    Label("App empfehlen", systemImage: "square.and.arrow.up")
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                }
            }

            Button {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    AppStore.requestReview(in: scene)
                }
            } label: {
                HStack {
                    Label("App bewerten", systemImage: "star.fill")
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                }
            }

            Link(destination: URL(string: "https://blaseunddarm.de")!) {
                HStack {
                    Label("blaseunddarm.de", systemImage: "globe")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("Info")
        } footer: {
            Text("Alle Daten werden lokal auf diesem Gerät gespeichert und nicht an Dritte weitergegeben.\n© André M. Bajorat")
                .font(.caption)
        }
    }

    // MARK: - CSV Export

    private func exportCSV() {
        var csv = "Datum;Uhrzeit;Urin_ml;Getrunken_ml;Stuhlgang;Notiz\n"
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"

        for e in store.entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            let note = e.note.replacingOccurrences(of: ";", with: ",")
            csv += "\(df.string(from: e.timestamp));\(tf.string(from: e.timestamp));\(e.urineMl);\(e.drinkMl ?? 0);\(e.bowel ? "Ja" : "Nein");\(note)\n"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("blasen_darm_protokoll.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)

        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            if let popover = av.popoverPresentationController {
                popover.sourceView = root.view
                popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            }
            root.present(av, animated: true)
        }
    }

    // MARK: - CSV Import

    private func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importResult = (0, "Kein Zugriff auf die Datei.")
            showImportResult = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            importResult = (0, "Datei konnte nicht gelesen werden.")
            showImportResult = true
            return
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else {
            importResult = (0, "Die CSV-Datei enthält keine Daten.")
            showImportResult = true
            return
        }

        let header = lines[0].lowercased()
        let separator: Character = header.contains(";") ? ";" : ","

        let columns = lines[0].split(separator: separator).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        let datumIdx = columns.firstIndex(where: { $0.contains("datum") || $0.contains("date") })
        let zeitIdx = columns.firstIndex(where: { $0.contains("uhrzeit") || $0.contains("zeit") || $0.contains("time") })
        let mlIdx = columns.firstIndex(where: { $0.contains("urin") || $0.contains("ml") || $0.contains("menge") })
        let stuhlIdx = columns.firstIndex(where: { $0.contains("stuhl") || $0.contains("bowel") })
        let drinkIdx = columns.firstIndex(where: { $0.contains("getrunken") || $0.contains("trink") || $0.contains("drink") })
        let notizIdx = columns.firstIndex(where: { $0.contains("notiz") || $0.contains("note") })

        let df = DateFormatter()
        let dateFormats = ["dd.MM.yyyy", "yyyy-MM-dd", "d.M.yyyy", "dd/MM/yyyy"]
        let timeFormats = ["HH:mm", "HH:mm:ss", "H:mm"]

        var imported = 0

        for line in lines.dropFirst() {
            let fields = String(line).split(separator: separator, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count >= 2 else { continue }

            var entryDate: Date?
            if let di = datumIdx, di < fields.count {
                for fmt in dateFormats {
                    df.dateFormat = fmt
                    if let d = df.date(from: fields[di]) {
                        entryDate = d
                        break
                    }
                }
            }
            guard var date = entryDate else { continue }

            if let ti = zeitIdx, ti < fields.count {
                for fmt in timeFormats {
                    df.dateFormat = fmt
                    if let t = df.date(from: fields[ti]) {
                        let cal = Calendar.current
                        let hour = cal.component(.hour, from: t)
                        let minute = cal.component(.minute, from: t)
                        date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
                        break
                    }
                }
            }

            var ml = 0
            if let mi = mlIdx, mi < fields.count {
                ml = Int(fields[mi].replacingOccurrences(of: "ml", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
            }

            var bowel = false
            if let si = stuhlIdx, si < fields.count {
                let val = fields[si].lowercased()
                bowel = val == "ja" || val == "yes" || val == "1" || val == "true" || val == "✓"
            }

            var note = ""
            if let ni = notizIdx, ni < fields.count {
                note = fields[ni]
            }

            var drinkVal: Int? = nil
            if let di = drinkIdx, di < fields.count {
                let v = Int(fields[di].replacingOccurrences(of: "ml", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
                if v > 0 { drinkVal = v }
            }

            let entry = ToiletEntry(timestamp: date, urineMl: ml, bowel: bowel, note: note, drinkMl: drinkVal)
            store.add(entry)
            imported += 1
        }

        importResult = (imported, "\(imported) Einträge importiert.")
        showImportResult = true
    }
}

#Preview {
    SettingsView()
        .environment(DataStore())
        .environment(NotificationManager())
        .environment(CloudBackupManager())
}
