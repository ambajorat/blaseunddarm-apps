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
    /// Fokus-Steuerung für die Ziffernblock-Felder — der numberPad hat
    /// keine Return-Taste, ohne das hier bleibt die Tastatur stehen.
    private enum NumField: Hashable { case quick, drink, stock(UUID), delivery(UUID) }
    @FocusState private var numFocus: NumField?

    @State private var newQuickValue = ""
    @State private var drink = DrinkSettings.load()
    @State private var newDrinkValue = ""
    @State private var catheter = CatheterStock.load()
    @State private var deliveryInputs: [UUID: String] = [:]
    @State private var showFirstRunSheet = false
    @State private var stockInputs: [UUID: String] = [:]
    @State private var uti = UtiSettings.load()
    @State private var palp = PalpationSettings.load()
    @State private var ad = AdSettings.load()

    var body: some View {
        NavigationStack {
            settingsList
                .navigationTitle(String(localized: "tab_settings"))
                .scrollDismissesKeyboard(.immediately)
        }
    }

    /// Ausgelagert: der Typprüfer schafft die List samt Modifier-Kette
    /// nicht mehr als einen Ausdruck (Fehler "unable to type-check").
    /// Fertig-Leiste über dem Ziffernblock — direkt an den Feldern
    /// angebracht, weil sie an der List hängend nicht zuverlässig erscheint.
    @ToolbarContentBuilder
    private var doneToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Fertig") { numFocus = nil }
        }
    }

    private var settingsList: some View {
        List {
            reminderSection
            quickValuesSection
            drinkSection
            catheterSection
            utiSection
            iskExtrasSection
            cloudSection
            dataSection
            aboutSection
        }
        .onChange(of: drink) { _, new in new.save() }
        .onChange(of: catheter) { _, new in new.save() }
        .onChange(of: uti) { _, new in new.save() }
        .onChange(of: palp) { _, new in new.save() }
        .onChange(of: ad) { _, new in new.save() }
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
                reminderModePicker

                if store.settings.useFixedTimes ?? false {
                    fixedTimesEditor
                }

                if !(store.settings.useFixedTimes ?? false) {
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
                                Text(String(localized: String.LocalizationValue(item.label)))
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
                if !(store.settings.useFixedTimes ?? false),
                   let sug = SuggestionEngine.compute(entries: store.entries), let mins = sug.intervalMinutes,
                   mins != store.settings.intervalMinutes {
                    let durationText = formatInterval(mins)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vorschlag aus deinen Daten")
                                .font(.subheadline)
                            Text(String(localized: "Median deiner Abstände: \(durationText)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(String(localized: "Übernehmen")) { store.settings.intervalMinutes = mins }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                    }
                }

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

    // MARK: - Wecker-Modus (feste Erinnerungszeiten)

    private var reminderModePicker: some View {
        Picker(String(localized: "Erinnerungsart"), selection: Binding(
            get: { (store.settings.useFixedTimes ?? false) ? 1 : 0 },
            set: { store.settings.useFixedTimes = ($0 == 1) }
        )) {
            Text("Intervall").tag(0)
            Text("Feste Zeiten").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 2)
    }

    private var fixedTimesEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(store.settings.sortedFixedTimes, id: \.self) { minutes in
                HStack {
                    Image(systemName: "alarm")
                        .foregroundStyle(Color.accentBlue)
                    DatePicker("", selection: Binding(
                        get: { Self.dateFor(minutes: minutes) },
                        set: { replaceFixedTime(minutes, with: Self.minutesOf($0)) }
                    ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Spacer()
                    Button {
                        removeFixedTime(minutes)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Zeit löschen"))
                }
            }
            Button {
                addFixedTime()
            } label: {
                Label(String(localized: "Zeit hinzufügen"), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            Text("Erinnerungen kommen täglich zu diesen Uhrzeiten — unabhängig vom letzten Eintrag. Die Ruhezeit wird dabei nicht angewendet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private static func dateFor(minutes: Int) -> Date {
        Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(minutes * 60))
    }

    private static func minutesOf(_ date: Date) -> Int {
        let c = Calendar.current
        return c.component(.hour, from: date) * 60 + c.component(.minute, from: date)
    }

    private func replaceFixedTime(_ old: Int, with newMinutes: Int) {
        var t = store.settings.fixedTimes ?? []
        if let i = t.firstIndex(of: old) { t[i] = newMinutes }
        store.settings.fixedTimes = Array(Set(t)).sorted()
    }

    private func removeFixedTime(_ minutes: Int) {
        store.settings.fixedTimes = (store.settings.fixedTimes ?? []).filter { $0 != minutes }
    }

    private func addFixedTime() {
        var t = store.settings.fixedTimes ?? []
        let next = t.isEmpty ? 480 : min((t.max() ?? 480) + 180, 1425)
        if !t.contains(next) { t.append(next) }
        store.settings.fixedTimes = t.sorted()
    }

    private func formatInterval(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return String(localized: "\(m) Min") }
        if m == 0 { return String(localized: "\(h) Std") }
        if m == 30 { return String(localized: "\(h),5 Std") }
        return String(localized: "\(h) Std \(m) Min")
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
                    .focused($numFocus, equals: .quick)
                    .toolbar { doneToolbar }

                Button {
                    if let val = Int(newQuickValue), val > 0 {
                        store.settings.quickValues.append(val)
                        store.settings.quickValues.sort()
                        numFocus = nil
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

            if let sug = SuggestionEngine.compute(entries: store.entries),
               let vals = sug.urineQuickValues, vals != store.settings.quickValues {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deine häufigsten Mengen")
                            .font(.subheadline)
                        Text(vals.map { String($0) }.joined(separator: " · ") + " ml")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(String(localized: "Übernehmen")) { store.settings.quickValues = vals }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                }
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
                        .focused($numFocus, equals: .drink)
                    .toolbar { doneToolbar }

                    Button {
                        if let val = Int(newDrinkValue), val > 0 {
                            drink.presets.append(val)
                            drink.presets.sort()
                            numFocus = nil
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

            if drink.enabled,
               let sug = SuggestionEngine.compute(entries: store.entries),
               let vals = sug.drinkQuickValues, vals != drink.presets {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deine häufigsten Mengen")
                            .font(.subheadline)
                        Text(vals.map { String($0) }.joined(separator: " · ") + " ml")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(String(localized: "Übernehmen")) { drink.presets = vals }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                }
            }

        } header: {
            Text("Trinkmengen")
        } footer: {
            Text(drink.enabled
                 ? String(localized: "Erscheint beim Erfassen als eigener Abschnitt \u{201E}Getrunken (ml)\u{201C} mit diesen Schnelltasten.")
                 : String(localized: "Optional: Erfasse zusätzlich, wie viel du trinkst — für die Ein-/Ausfuhr-Bilanz."))
                .font(.caption)
        }
    }

    // MARK: - Katheterbestand (optional)

    /// Bedienzeilen für EINE Kathetersorte (Name, Bestand, Korrektur,
    /// Packung, Lieferung, Ch, Material, Entfernen). Packungsgröße,
    /// Warnschwelle und Rezept bleiben bewusst global (Andrés Modell).
    @ViewBuilder private func catheterSortRows(_ sort: Binding<CatheterSort>) -> some View {
        let id = sort.wrappedValue.id
        HStack {
            Text("Name")
            TextField("z. B. Hersteller", text: sort.name)
                .multilineTextAlignment(.trailing)
        }

        HStack {
            Text("Aktueller Bestand")
            Spacer()
            Text("\(catheter.stock(of: sort.wrappedValue, entries: store.entries)) Stück")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }

        HStack {
            TextField("Bestand eintragen", text: inputBinding($stockInputs, id))
                .keyboardType(.numberPad)
                .focused($numFocus, equals: .stock(id))
            .toolbar { doneToolbar }

            Button {
                if let val = Int(stockInputs[id] ?? ""), val >= 0 {
                    catheter.setStock(val, forSort: id)
                    stockInputs[id] = ""
                    numFocus = nil
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentBlue)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(Int(stockInputs[id] ?? "") == nil || Int(stockInputs[id] ?? "")! < 0)
        }

        Button {
            catheter.addPack(forSort: id, entries: store.entries)
        } label: {
            Label("+1 Packung (\(catheter.packSize) Stück)", systemImage: "plus.circle.fill")
        }

        HStack {
            TextField("Lieferung erfassen (Stück)", text: inputBinding($deliveryInputs, id))
                .keyboardType(.numberPad)
                .focused($numFocus, equals: .delivery(id))

            Button {
                if let val = Int(deliveryInputs[id] ?? ""), val > 0 {
                    catheter.addDelivery(val, forSort: id, entries: store.entries)
                    deliveryInputs[id] = ""
                    numFocus = nil
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentBlue)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(Int(deliveryInputs[id] ?? "") == nil || Int(deliveryInputs[id] ?? "")! <= 0)
        }

        Stepper(value: Binding(get: { sort.wrappedValue.sizeCharriere ?? 12 },
                               set: { sort.wrappedValue.sizeCharriere = $0 }), in: 6...24) {
            HStack {
                Text("Charrière (Ch)")
                Spacer()
                Text(sort.wrappedValue.sizeCharriere.map { "Ch \($0)" } ?? "—")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }

        TextField("Material (z. B. hydrophil beschichtet)", text: Binding(
            get: { sort.wrappedValue.material ?? "" },
            set: { sort.wrappedValue.material = $0.isEmpty ? nil : $0 }))

        if (catheter.sorts?.count ?? 0) > 1 {
            Button(role: .destructive) {
                catheter.sorts?.removeAll { $0.id == id }
                if catheter.lastUsedSortId == id { catheter.lastUsedSortId = nil }
                stockInputs[id] = nil
                deliveryInputs[id] = nil
            } label: {
                Label("Sorte entfernen", systemImage: "minus.circle")
            }
        }

    }

    private func sortTitle(_ id: UUID) -> String {
        let idx = (catheter.sorts?.firstIndex(where: { $0.id == id }) ?? 0) + 1
        return String(format: String(localized: "Sorte %lld"), idx)
    }

    private func inputBinding(_ dict: Binding<[UUID: String]>, _ id: UUID) -> Binding<String> {
        Binding(get: { dict.wrappedValue[id] ?? "" },
                set: { dict.wrappedValue[id] = $0 })
    }

    @ViewBuilder private var catheterSection: some View {
        Section {
            Toggle(isOn: $catheter.enabled) {
                Label("Katheterbestand verfolgen", systemImage: "cross.vial.fill")
            }
            .onAppear {
                if catheter.enabled && (catheter.sorts?.isEmpty ?? true) { catheter.ensureSorts() }
            }
            .onChange(of: catheter.enabled) { _, on in
                if on && (catheter.sorts?.isEmpty ?? true) { catheter.ensureSorts() }
            }
        } header: {
            Text("Katheterbestand")
        } footer: {
            if !catheter.enabled {
                Text(catheterFooterText)
                    .font(.caption)
            }
        }

        if catheter.enabled {
            // Eine eigene Sektion je Sorte — klare optische Trennung,
            // Überschrift automatisch "Sorte 1"/"Sorte 2", Name als beschriftete Zeile.
            if let sortsBinding = Binding($catheter.sorts) {
                ForEach(sortsBinding) { $sort in
                    Section {
                        catheterSortRows($sort)
                    } header: {
                        Text(sortTitle(sort.id))
                    }
                }
            }

            Section {
                Button {
                    catheter.ensureSorts()
                    let n = (catheter.sorts?.count ?? 0) + 1
                    catheter.sorts?.append(CatheterSort(name: "Sorte \(n)"))
                } label: {
                    Label("Sorte hinzufügen", systemImage: "plus.circle")
                }

                Stepper(value: $catheter.packSize, in: 5...120, step: 5) {
                    HStack {
                        Text("Packungsgröße")
                        Spacer()
                        Text("\(catheter.packSize)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $catheter.warnDays, in: 3...30) {
                    HStack {
                        Text("Warnen unter")
                        Spacer()
                        Text("\(catheter.warnDays) Tagen")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: Binding(
                    get: { catheter.prescriptionDate != nil },
                    set: { catheter.prescriptionDate = $0 ? Calendar.current.date(byAdding: .month, value: 1, to: .now) : nil })) {
                    Label("Rezept-Erinnerung", systemImage: "doc.text.fill")
                }

                if catheter.prescriptionDate != nil {
                    DatePicker("Rezept läuft aus", selection: Binding(
                        get: { catheter.prescriptionDate ?? .now },
                        set: { catheter.prescriptionDate = $0 }), displayedComponents: .date)
                }
            } header: {
                Text("Für alle Sorten")
            } footer: {
                Text(catheterFooterText)
                    .font(.caption)
            }
        }
    }

    private var catheterFooterText: String {
        guard catheter.enabled else {
            return String(localized: "Optional: Zählt deine Katheter mit — jeder Blaseneintrag gilt als eine Katheterisierung — und erinnert dich rechtzeitig ans Rezept.")
        }
        if catheter.currentStock(entries: store.entries) == 0 {
            return String(localized: "Trage deinen aktuellen Bestand ein, um zu starten.")
        }
        if let days = catheter.daysRemaining(entries: store.entries),
           let empty = catheter.estimatedEmptyDate(entries: store.entries),
           let usage = catheter.dailyUsage(entries: store.entries) {
            let dateText = empty.formatted(.dateTime.day().month())
            return String(format: String(localized: "Ø %.1f pro Tag — reicht noch etwa %d Tage (bis ca. %@)."), usage, days, dateText)
        }
        return String(localized: "Reichweite erscheint, sobald mindestens 3 Tage mit Blaseneinträgen in den letzten 14 Tagen vorliegen.")
    }

    // MARK: - HWI-Frühwarnung (optional)

    private var utiSection: some View {
        Section {
            Toggle(isOn: $uti.enabled) {
                Label("HWI-Frühwarnung", systemImage: "exclamationmark.shield.fill")
            }
        } header: {
            Text("Harnwegsinfekt")
        } footer: {
            Text(uti.enabled
                 ? String(localized: "Beim Erfassen erscheint der Abschnitt \u{201E}Auffälligkeiten\u{201C}. Bei Blut oder Fieber meldet sich die App sofort, bei Mustern über mehrere Tage mit einem Hinweis. Ersetzt keine ärztliche Diagnose.")
                 : String(localized: "Optional: Erfasse Anzeichen wie Geruch, Brennen oder vermehrte Spastik — die App warnt bei Mustern, die bei ISK auf einen Harnwegsinfekt hindeuten können. Ersetzt keine ärztliche Diagnose."))
                .font(.caption)
        }
    }

    // MARK: - ISK-Erweiterungen (Tastbefund, vegetative Zeichen)

    private var iskExtrasSection: some View {
        Section {
            Toggle(isOn: $palp.enabled) {
                Label("Tastbefund", systemImage: "hand.point.up.left.fill")
            }
            Toggle(isOn: $ad.enabled) {
                Label("Vegetative Zeichen", systemImage: "waveform.path.ecg")
            }
            if ad.enabled {
                Toggle(isOn: $ad.bpEnabled) {
                    Label("Blutdruckfeld (RR systolisch)", systemImage: "heart.fill")
                }
            }
        } header: {
            Text("ISK-Erweiterungen")
        } footer: {
            Text("Tastbefund: Füllungsgrad oberhalb des Schambeins in drei Stufen selbst einschätzen — die Statistik zeigt dir mit der Zeit deine eigenen Durchschnittsmengen je Stufe. Vegetative Zeichen: Gänsehaut, Schwitzen, Hitzegefühl oder Kopfschmerz als Füllungssignale erfassen, optional mit Blutdruck. Beides ersetzt keine ärztliche Diagnose.")
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
            Button {
                showFirstRunSheet = true
            } label: {
                Label(String(localized: "firstrun_replay"), systemImage: "arrow.counterclockwise")
            }
            .sheet(isPresented: $showFirstRunSheet, onDismiss: {
                // Erstfrage schreibt direkt in den Speicher — lokale Kopien nachziehen,
                // sonst zeigen die Toggles einen veralteten Stand (Bestand nicht korrigierbar)
                catheter = CatheterStock.load()
                uti = UtiSettings.load()
                palp = PalpationSettings.load()
                ad = AdSettings.load()
            }) { FirstRunSetupView() }

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
                // Direkter Sprung ins Bewertungsformular — requestReview ist von
                // Apple gedrosselt und zeigt oft schlicht nichts an.
                if let url = URL(string: "https://apps.apple.com/app/id6792282103?action=write-review") {
                    UIApplication.shared.open(url)
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
        var csv = "Datum;Uhrzeit;Urin_ml;Getrunken_ml;Stuhlgang;Notiz;Symptome;Tastbefund;AD_Zeichen;RR_syst;Stuhlmenge;Kathetersorte\n"
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"

        for e in store.entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            let note = e.note.replacingOccurrences(of: ";", with: ",")
            let syms = (e.symptoms ?? []).map(\.rawValue).joined(separator: ", ")
            let adS = (e.adSigns ?? []).map(\.rawValue).joined(separator: ", ")
            let bpS = e.systolicBp.map(String.init) ?? ""
            csv += "\(df.string(from: e.timestamp));\(tf.string(from: e.timestamp));\(e.urineMl);\(e.drinkMl ?? 0);\(e.bowel ? "Ja" : "Nein");\(note);\(syms);\(e.palpation?.rawValue ?? "");\(adS);\(bpS);\(e.stoolAmount?.rawValue ?? "");\(e.catheterSort ?? "")\n"
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
        let symptomIdx = columns.firstIndex(where: { $0.contains("symptom") })
        let palpIdx = columns.firstIndex(where: { $0.contains("tastbefund") })
        let adIdx = columns.firstIndex(where: { $0.contains("ad_zeichen") })
        let bpIdx = columns.firstIndex(where: { $0.contains("rr_syst") })
        let stoolIdx = columns.firstIndex(where: { $0.contains("stuhlmenge") })
        let cathIdx = columns.firstIndex(where: { $0.contains("kathetersorte") })

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

            var syms: [UtiSymptom]? = nil
            if let yi = symptomIdx, yi < fields.count, !fields[yi].isEmpty {
                let parsed = fields[yi].split(separator: ",").compactMap { UtiSymptom(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
                if !parsed.isEmpty { syms = parsed }
            }

            var palpVal: PalpationFinding? = nil
            if let pi = palpIdx, pi < fields.count, !fields[pi].isEmpty {
                palpVal = PalpationFinding(rawValue: fields[pi].trimmingCharacters(in: .whitespaces))
            }
            var adVals: [AdSign]? = nil
            if let ai = adIdx, ai < fields.count, !fields[ai].isEmpty {
                let parsed = fields[ai].split(separator: ",").compactMap { AdSign(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
                if !parsed.isEmpty { adVals = parsed }
            }
            var bpVal: Int? = nil
            if let bi = bpIdx, bi < fields.count, let v = Int(fields[bi].trimmingCharacters(in: .whitespaces)), (60...300).contains(v) {
                bpVal = v
            }

            var stoolVal: StoolAmount? = nil
            if let si = stoolIdx, si < fields.count, !fields[si].isEmpty {
                stoolVal = StoolAmount(rawValue: fields[si].trimmingCharacters(in: .whitespaces))
            }

            var cathVal: String? = nil
            if let ci = cathIdx, ci < fields.count {
                let s = fields[ci].trimmingCharacters(in: .whitespaces)
                if !s.isEmpty { cathVal = s }
            }

            let entry = ToiletEntry(timestamp: date, urineMl: ml, bowel: bowel, note: note, drinkMl: drinkVal, symptoms: syms, palpation: palpVal, adSigns: adVals, systolicBp: bpVal, stoolAmount: stoolVal, catheterSort: cathVal)
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
