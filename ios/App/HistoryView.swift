import SwiftUI

struct HistoryView: View {
    @Environment(DataStore.self) private var store
    @State private var editingEntry: ToiletEntry?

    private var grouped: [DaySummary] {
        store.entries.grouped()
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.entries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Verlauf")
            .sheet(item: $editingEntry) { entry in
                EditEntryView(entry: entry)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("Noch keine Einträge")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var entryList: some View {
        List {
            ForEach(grouped) { day in
                Section {
                    ForEach(day.entries) { entry in
                        EntryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingEntry = entry
                            }
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            store.delete(day.entries[i])
                        }
                    }
                } header: {
                    HStack {
                        Text(dayLabel(day.date))
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(day.totalMl) ml · \(day.bowelCount)× Stuhl · \(day.count) Eintr.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Heute" }
        if Calendar.current.isDateInYesterday(date) { return "Gestern" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.twoDigits))
    }
}

// MARK: - Entry Row

struct EntryRow: View {
    let entry: ToiletEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 12) {
            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            if entry.urineMl > 0 {
                Label("\(entry.urineMl) ml", systemImage: "drop.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.urine)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.urine.opacity(0.12), in: .rect(cornerRadius: 6))
            }

            if entry.urineColor != .none {
                Text(entry.urineColor.emoji)
                    .font(.caption)
            }

            if let drink = entry.drinkMl, drink > 0 {
                Label("\(drink) ml", systemImage: "cup.and.saucer.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.teal.opacity(0.12), in: .rect(cornerRadius: 6))
            }

            if entry.bowel {
                HStack(spacing: 3) {
                    Label("Stuhl", systemImage: "checkmark.circle.fill")
                    if entry.bristolType != .none {
                        Text(entry.bristolType.emoji)
                    }
                }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.bowel)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.bowel.opacity(0.12), in: .rect(cornerRadius: 6))
            }

            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "pencil")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }

            if let details = detailLine {
                Text(details)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 60)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    /// Zweite Zeile mit ISK-Details — nur wenn der Eintrag welche hat.
    private var detailLine: String? {
        var parts: [String] = []
        if let palp = entry.palpation { parts.append(String(localized: "Tastbefund: \(palp.label)")) }
        if let syms = entry.symptoms, !syms.isEmpty { parts.append(String(localized: "Auffällig: \(syms.map(\.label).joined(separator: ", "))")) }
        if let ad = entry.adSigns, !ad.isEmpty { parts.append(String(localized: "Vegetativ: \(ad.map(\.label).joined(separator: ", "))")) }
        if let bp = entry.systolicBp { parts.append(String(localized: "RR \(bp)")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Edit Entry Sheet

struct EditEntryView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let entry: ToiletEntry

    @State private var timestamp: Date
    @State private var urineMl: String
    @State private var urineColor: UrineColor
    @State private var bowel: Bool
    @State private var bristolType: BristolType
    @State private var note: String
    @State private var drinkText: String
    @State private var symptoms: Set<UtiSymptom>
    @State private var palpation: PalpationFinding?
    @State private var adSigns: Set<AdSign>
    @State private var bpText: String
    private let drinkSettings = DrinkSettings.load()
    private let utiSettings = UtiSettings.load()
    private let palpSettings = PalpationSettings.load()
    private let adSettings = AdSettings.load()
    @State private var showDeleteConfirm = false
    @State private var showBristolInfo = false

    init(entry: ToiletEntry) {
        self.entry = entry
        _timestamp = State(initialValue: entry.timestamp)
        _urineMl = State(initialValue: entry.urineMl > 0 ? String(entry.urineMl) : "")
        _urineColor = State(initialValue: entry.urineColor)
        _bowel = State(initialValue: entry.bowel)
        _bristolType = State(initialValue: entry.bristolType)
        _note = State(initialValue: entry.note)
        _drinkText = State(initialValue: (entry.drinkMl ?? 0) > 0 ? String(entry.drinkMl ?? 0) : "")
        _symptoms = State(initialValue: Set(entry.symptoms ?? []))
        _palpation = State(initialValue: entry.palpation)
        _adSigns = State(initialValue: Set(entry.adSigns ?? []))
        _bpText = State(initialValue: entry.systolicBp.map(String.init) ?? "")
    }

    private var quickValues: [Int] {
        // Fallback quick values if store isn't available yet
        [100, 200, 300, 400, 500]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Zeitpunkt") {
                    DatePicker("Datum & Uhrzeit", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Urin-Menge (ml)") {
                    TextField("ml eingeben", text: $urineMl)
                        .keyboardType(.numberPad)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.settings.quickValues, id: \.self) { val in
                                Button(String(val)) {
                                    urineMl = String(val)
                                }
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(urineMl == String(val) ? Color.urine.opacity(0.15) : Color(.systemGroupedBackground),
                                           in: .rect(cornerRadius: 8))
                                .foregroundStyle(urineMl == String(val) ? Color.urine : .secondary)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Farbe des Urins") {
                    HStack(spacing: 8) {
                        ForEach(UrineColor.allCases.filter { $0 != .none }) { color in
                            Button {
                                urineColor = urineColor == color ? .none : color
                            } label: {
                                VStack(spacing: 3) {
                                    Text(color.emoji).font(.title3)
                                    Text(color.label).font(.system(size: 9)).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(urineColor == color ? Color.accent.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(urineColor == color ? Color.accent : .secondary)
                        }
                    }
                }

                if palpSettings.enabled || palpation != nil {
                    Section("Tastbefund") {
                        HStack(spacing: 8) {
                            ForEach(PalpationFinding.allCases) { f in
                                Button {
                                    palpation = (palpation == f) ? nil : f
                                } label: {
                                    Text(f.label)
                                        .font(.system(size: 11))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .minimumScaleFactor(0.75)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(palpation == f ? Color.accent.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(palpation == f ? Color.accent : .secondary)
                            }
                        }
                    }
                }

                if utiSettings.enabled || !symptoms.isEmpty {
                    Section("Auffälligkeiten") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(UtiSymptom.allCases) { sym in
                                Button {
                                    if symptoms.contains(sym) { symptoms.remove(sym) } else { symptoms.insert(sym) }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: symptoms.contains(sym) ? "checkmark.circle.fill" : "circle")
                                            .font(.caption)
                                        Text(sym.label)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 6)
                                    .background(symptoms.contains(sym) ? Color.accent.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(symptoms.contains(sym) ? Color.accent : .secondary)
                            }
                        }
                    }
                }

                if adSettings.enabled || !adSigns.isEmpty || !bpText.isEmpty {
                    Section("Vegetative Zeichen") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(AdSign.allCases) { z in
                                Button {
                                    if adSigns.contains(z) { adSigns.remove(z) } else { adSigns.insert(z) }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: adSigns.contains(z) ? "checkmark.circle.fill" : "circle")
                                            .font(.caption)
                                        Text(z.label)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 6)
                                    .background(adSigns.contains(z) ? Color.accent.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(adSigns.contains(z) ? Color.accent : .secondary)
                            }
                        }
                        if adSettings.bpEnabled || !bpText.isEmpty {
                            HStack {
                                Text("RR systolisch (mmHg)")
                                Spacer()
                                TextField("optional", text: $bpText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 100)
                            }
                        }
                    }
                }

                if drinkSettings.enabled || !drinkText.isEmpty {
                    Section("Getrunken (ml)") {
                        TextField("ml eingeben", text: $drinkText)
                            .keyboardType(.numberPad)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(drinkSettings.presets, id: \.self) { val in
                                    Button(String(val)) {
                                        drinkText = String(val)
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(drinkText == String(val) ? Color.teal.opacity(0.15) : Color(.systemGroupedBackground),
                                               in: .rect(cornerRadius: 8))
                                    .foregroundStyle(drinkText == String(val) ? Color.teal : .secondary)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                Section {
                    Toggle(isOn: $bowel) {
                        Label("Stuhlgang", systemImage: bowel ? "checkmark.circle.fill" : "circle")
                    }
                    .tint(Color.bowel)
                    .onChange(of: bowel) { _, newVal in
                        if !newVal { bristolType = .none }
                    }
                }

                if bowel {
                    Section {
                        HStack {
                            Text("Bristol-Skala")
                                .font(.subheadline)
                            Spacer()
                            Button {
                                showBristolInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(Color.accent)
                            }
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(BristolType.allCases.filter { $0 != .none }) { type in
                                Button {
                                    bristolType = bristolType == type ? .none : type
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(type.emoji).font(.title3)
                                        Text(type.label).font(.system(size: 9))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(bristolType == type ? Color.bowel.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 8))
                                    .foregroundStyle(bristolType == type ? Color.bowel : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .sheet(isPresented: $showBristolInfo) {
                        BristolInfoView()
                    }
                }

                Section("Notiz") {
                    TextField("Optional", text: $note)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Eintrag löschen", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        saveChanges()
                    }
                    .fontWeight(.bold)
                }
            }
            .alert("Eintrag löschen?", isPresented: $showDeleteConfirm) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    store.delete(entry)
                    dismiss()
                }
            }
        }
    }

    private func saveChanges() {
        var updated = entry
        updated.timestamp = timestamp
        updated.urineMl = Int(urineMl) ?? 0
        updated.urineColor = urineColor
        updated.bowel = bowel
        updated.bristolType = bristolType
        updated.note = note
        let drinkVal = Int(drinkText) ?? 0
        updated.drinkMl = drinkVal > 0 ? drinkVal : nil
        updated.symptoms = symptoms.isEmpty ? nil : Array(symptoms)
        updated.palpation = palpation
        updated.adSigns = adSigns.isEmpty ? nil : Array(adSigns)
        updated.systolicBp = {
            guard let v = Int(bpText), (60...300).contains(v) else { return nil }
            return v
        }()
        store.update(updated)
        dismiss()
    }
}

#Preview {
    HistoryView()
        .environment(DataStore())
}
