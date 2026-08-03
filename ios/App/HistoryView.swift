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
        .padding(.vertical, 2)
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
                        .environment(\.locale, Locale(identifier: "de_DE"))
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
                                    Text(color.rawValue).font(.system(size: 9)).lineLimit(1)
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
        store.update(updated)
        dismiss()
    }
}

#Preview {
    HistoryView()
        .environment(DataStore())
}
