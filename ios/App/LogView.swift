import SwiftUI

struct LogView: View {
    @Environment(DataStore.self) private var store
    @Environment(NotificationManager.self) private var notifications
    @Environment(StoreManager.self) private var storeManager

    @State private var urineMl: String = ""
    @State private var urineColor: UrineColor = .none
    @State private var bowel = false
    @State private var bristolType: BristolType = .none
    @State private var stoolAmount: StoolAmount? = nil
    @State private var showBristolInfo = false
    @State private var note = ""
    @State private var drinkText = ""
    @State private var drinkSettings = DrinkSettings.load()
    @State private var utiSettings = UtiSettings.load()
    @State private var symptoms: Set<UtiSymptom> = []
    @State private var palpSettings = PalpationSettings.load()
    @State private var palpation: PalpationFinding? = nil
    @State private var adSettings = AdSettings.load()
    @State private var adSigns: Set<AdSign> = []
    @State private var bpText = ""
    @State private var entryTime: Date = .now
    @State private var showSaved = false

    /// Ziffernblock hat keine Return-Taste — Fokus-Steuerung + Fertig-Leiste
    private enum NumField: Hashable { case urine, bp, drink }
    @FocusState private var numFocus: NumField?

    @State private var timer: Timer?
    @State private var timeRemaining: TimeInterval = 0
    @Environment(\.scenePhase) private var scenePhase

    private var quickValues: [Int] { store.settings.quickValues }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerArea
                    reminderBanner
                    todaySummary
                    entryForm
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.pageBg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "done")) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear {
                entryTime = .now
                drinkSettings = DrinkSettings.load()
                utiSettings = UtiSettings.load()
                palpSettings = PalpationSettings.load()
                adSettings = AdSettings.load()
                startTimer()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    entryTime = .now
                    drinkSettings = DrinkSettings.load()
                    utiSettings = UtiSettings.load()
                palpSettings = PalpationSettings.load()
                adSettings = AdSettings.load()
                }
            }
            .onDisappear { timer?.invalidate() }
            .overlay {
                if notifications.alarmFiring {
                    alarmOverlay
                }
            }
        }
    }

    private var alarmOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accent)
                .symbolRenderingMode(.multicolor)
            Text(String(localized: "reminder_alert"))
                .font(.title2.weight(.bold))
            Button {
                notifications.dismissAlarm()
            } label: {
                Text("OK")
                    .font(.body.weight(.bold))
                    .frame(width: 200)
                    .padding(.vertical, 14)
                    .background(Color.accent, in: .rect(cornerRadius: 10))
                    .foregroundStyle(Color.pillActiveText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private var headerArea: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "app_title"))
                    .font(.system(size: 22, weight: .bold, design: .serif))
                Text(String(localized: "app_subtitle"))
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)
            }
            Spacer()
            // Timer inline in header
            if store.settings.reminderEnabled && store.lastBladderEntry != nil {
                if store.settings.quietHoursEnabled && store.settings.isInQuietHours {
                    Label("Ruhezeit", systemImage: "moon.fill")
                        .font(.caption)
                        .foregroundStyle(Color.subtleText)
                } else if timeRemaining <= 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        let overdue = overdueMinutes(since: store.lastBladderEntry!.timestamp)
                        Text(formatTime(Double(overdue * 60)))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                        Text("überfällig")
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(formatTime(timeRemaining))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.accent)
                        Text("nächste Erinnerung")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.subtleText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var reminderBanner: some View {
        // Only show overdue alert as separate banner (timer is now in header)
        if store.settings.reminderEnabled && timeRemaining <= 0 && store.lastBladderEntry != nil {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body)
                    .foregroundStyle(Color.accent)
                Text(String(localized: "reminder_alert"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.accent.opacity(0.12), in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accent.opacity(0.3)))
        }
    }

    private var todaySummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "today"))
                .font(.subheadline.weight(.bold))
            HStack(spacing: 0) {
                summaryItem(value: "\(store.todayMl)", unit: "ml", label: String(localized: "urine"), color: Color.accent)
                Rectangle().fill(Color.pillBorder).frame(width: 0.5, height: 30)
                summaryItem(value: "\(store.todayBowel)×", unit: nil, label: String(localized: "stool"), color: Color.bowel)
                Rectangle().fill(Color.pillBorder).frame(width: 0.5, height: 30)
                if drinkSettings.enabled {
                    summaryItem(value: "\(store.todayDrink)", unit: "ml", label: "Getrunken", color: Color.teal)
                    Rectangle().fill(Color.pillBorder).frame(width: 0.5, height: 30)
                }
                summaryItem(value: "\(store.todayCount)", unit: nil, label: String(localized: "entries"), color: Color.subtleText)
            }
            .padding(.vertical, 12)
            .background(Color.cardBg, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
        }
        .accessibleSummary(ml: store.todayMl, bowel: store.todayBowel, count: store.todayCount)
    }

    private func summaryItem(value: String, unit: String?, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title3.weight(.bold)).foregroundStyle(color)
                if let unit { Text(unit).font(.caption2).foregroundStyle(color.opacity(0.7)) }
            }
            Text(label).font(.caption2).foregroundStyle(Color.subtleText)
        }
        .frame(maxWidth: .infinity)
    }

    @ToolbarContentBuilder
    private var doneToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button(String(localized: "Fertig")) { numFocus = nil }
        }
    }

    /// RR-Eingabe sichtbar validieren statt still verwerfen
    private var bpInvalid: Bool {
        guard !bpText.isEmpty else { return false }
        guard let v = Int(bpText) else { return true }
        if v > 300 { return true }                       // kann nie mehr gültig werden -> sofort
        if v < 60 && numFocus != .bp { return true }     // zu klein -> erst nach Verlassen des Felds
        return false
    }

    @AppStorage("iskHintDismissed") private var iskHintDismissed = false

    /// Einmaliger Hinweis auf die ISK-Module — sie sind Opt-in und sonst unsichtbar
    @ViewBuilder
    private var iskHintCard: some View {
        let anyOn = CatheterStock.load().enabled || UtiSettings.load().enabled
            || PalpationSettings.load().enabled || AdSettings.load().enabled
        if !iskHintDismissed && !anyOn {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(Color.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Nutzt du ISK?"))
                        .font(.subheadline.weight(.semibold))
                    Text(String(localized: "Katheterbestand, HWI-Frühwarnung, Tastbefund und vegetative Zeichen kannst du in den Einstellungen dazuschalten."))
                        .font(.caption)
                        .foregroundStyle(Color.subtleText)
                }
                Spacer()
                Button {
                    withAnimation { iskHintDismissed = true }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Hinweis ausblenden"))
            }
            .padding(12)
            .background(Color.cardBg, in: .rect(cornerRadius: 12))
        }
    }

    private var entryForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            iskHintCard

            Text(String(localized: "new_entry"))
                .font(.subheadline.weight(.bold))

            DatePicker(String(localized: "time"), selection: $entryTime, displayedComponents: [.date, .hourAndMinute])
                .font(.subheadline)

            // Urine ml
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "urine_amount"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.subtleText)
                TextField("ml", text: $urineMl)
                    .focused($numFocus, equals: .urine)
                    .toolbar { doneToolbar }
                    .keyboardType(.numberPad)
                    .font(.body)
                    .padding(10)
                    .background(Color.pageBg, in: .rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], spacing: 6) {
                    ForEach(quickValues, id: \.self) { val in
                        AccessibleQuickValueButton(value: val, isSelected: urineMl == String(val)) {
                            urineMl = String(val)
                        }
                    }
                }
            }

            // Urine color (jetzt immer verfügbar)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "urine_color"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.subtleText)
                HStack(spacing: 6) {
                    ForEach(UrineColor.allCases.filter { $0 != .none }) { color in
                        AccessibleColorButton(color: color, isSelected: urineColor == color) {
                            urineColor = urineColor == color ? .none : color
                        }
                    }
                }
            }

            // Tastbefund (optional, per Einstellungen aktivierbar)
            if palpSettings.enabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tastbefund")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.subtleText)
                    HStack(spacing: 6) {
                        ForEach(PalpationFinding.allCases) { f in
                            Button {
                                palpation = (palpation == f) ? nil : f
                            } label: {
                                Text(f.label)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8).padding(.horizontal, 4)
                                    .background(palpation == f ? Color.pillActiveBg : Color.pageBg, in: .rect(cornerRadius: 8))
                                    .foregroundStyle(palpation == f ? Color.pillActiveText : .primary)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(palpation == f ? .isSelected : [])
                        }
                    }
                }
            }

            // Auffälligkeiten (HWI-Frühwarnung, optional)
            if utiSettings.enabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auffälligkeiten")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.subtleText)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(UtiSymptom.allCases) { s in
                            Button {
                                if symptoms.contains(s) { symptoms.remove(s) } else { symptoms.insert(s) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: symptoms.contains(s) ? "checkmark.circle.fill" : "circle")
                                        .font(.caption)
                                    Text(s.label)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 8).padding(.horizontal, 10)
                                .background(symptoms.contains(s) ? Color.pillActiveBg : Color.pageBg, in: .rect(cornerRadius: 8))
                                .foregroundStyle(symptoms.contains(s) ? Color.pillActiveText : .primary)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(symptoms.contains(s) ? .isSelected : [])
                        }
                    }
                }
            }

            // Vegetative Zeichen / AD (optional, per Einstellungen aktivierbar)
            if adSettings.enabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vegetative Zeichen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.subtleText)
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
                                .padding(.vertical, 8).padding(.horizontal, 10)
                                .background(adSigns.contains(z) ? Color.pillActiveBg : Color.pageBg, in: .rect(cornerRadius: 8))
                                .foregroundStyle(adSigns.contains(z) ? Color.pillActiveText : .primary)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(adSigns.contains(z) ? .isSelected : [])
                        }
                    }
                    if adSettings.bpEnabled {
                        HStack {
                            Text("RR systolisch")
                                .font(.caption)
                                .foregroundStyle(Color.subtleText)
                            TextField("mmHg", text: $bpText)
                                .focused($numFocus, equals: .bp)
                                .toolbar { doneToolbar }
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(bpInvalid ? Color.red : Color.clear, lineWidth: 1))
                        }
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(Color.pageBg, in: .rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))
                        if bpInvalid {
                            Text(String(localized: "Gültig sind 60–300 mmHg — der Wert wird sonst nicht gespeichert."))
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            // Getrunken (optional, per Einstellungen aktivierbar)
            if drinkSettings.enabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Getrunken (ml)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.subtleText)
                    TextField("ml", text: $drinkText)
                        .focused($numFocus, equals: .drink)
                        .toolbar { doneToolbar }
                        .keyboardType(.numberPad)
                        .font(.body)
                        .padding(10)
                        .background(Color.pageBg, in: .rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], spacing: 6) {
                        ForEach(drinkSettings.presets, id: \.self) { val in
                            AccessibleQuickValueButton(value: val, isSelected: drinkText == String(val)) {
                                drinkText = String(val)
                            }
                        }
                    }
                }
            }

            // Bowel
            Button {
                bowel.toggle()
                if !bowel { bristolType = .none; stoolAmount = nil }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: bowel ? "checkmark.circle.fill" : "circle")
                    Text(String(localized: "bowel")).font(.subheadline.weight(.medium))
                    Spacer()
                }
                .padding(14)
                .background(bowel ? Color.bowel.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(bowel ? Color.bowel.opacity(0.4) : Color.pillBorder, lineWidth: 1))
            }
            .foregroundStyle(bowel ? Color.bowel : Color.subtleText)
            .accessibilityLabel(String(localized: "bowel"))
            .accessibilityHint(bowel ? "Aktiviert. Doppeltippen zum Deaktivieren" : "Doppeltippen zum Aktivieren")
            .accessibilityAddTraits(bowel ? [.isButton, .isSelected] : .isButton)

            // Stuhlmenge (nur wenn Stuhlgang aktiv)
            if bowel {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stuhlmenge")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.subtleText)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 6)], spacing: 6) {
                        ForEach(StoolAmount.allCases) { amount in
                            Button {
                                stoolAmount = stoolAmount == amount ? nil : amount
                            } label: {
                                VStack(spacing: 2) {
                                    Text(amount.emoji).font(.title3)
                                    Text(amount.label)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(stoolAmount == amount ? Color.bowel.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 8))
                                .foregroundStyle(stoolAmount == amount ? Color.bowel : .secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(stoolAmount == amount ? .isSelected : [])
                        }
                    }
                }
            }

            // Bristol (jetzt immer verfügbar, wenn Stuhlgang aktiv)
            if bowel {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "bristol_scale"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.subtleText)
                        Spacer()
                        Button { showBristolInfo = true } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "info.circle")
                                Text(String(localized: "bristol_whatis"))
                            }.font(.caption2).foregroundStyle(Color.accent)
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
                                    Text(type.shortDesc).font(.system(size: 7)).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(bristolType == type ? Color.bowel.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(bristolType == type ? Color.bowel.opacity(0.4) : Color.pillBorder, lineWidth: 1))
                                .foregroundStyle(bristolType == type ? Color.bowel : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .sheet(isPresented: $showBristolInfo) { BristolInfoView() }
            }

            // Note
            TextField(String(localized: "note_optional"), text: $note)
                .font(.subheadline)
                .padding(10)
                .background(Color.pageBg, in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))

            // Save
            Button(action: saveEntry) {
                Text(showSaved ? "✓ \(String(localized: "saved"))" : String(localized: "save"))
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(canSave ? Color.accent : Color.pillBg, in: .rect(cornerRadius: 8))
                    .foregroundStyle(canSave ? Color.pillActiveText : Color.subtleText)
            }
            .disabled(!canSave)
            .sensoryFeedback(.success, trigger: showSaved)
        }
        .padding(18)
        .background(Color.cardBg, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
    }

    private var canSave: Bool { (Int(urineMl) ?? 0) > 0 || bowel || (Int(drinkText) ?? 0) > 0 }

    private func saveEntry() {
        guard canSave else { return }
        let drinkVal = Int(drinkText).flatMap { $0 > 0 ? $0 : nil }
        store.add(ToiletEntry(
            timestamp: entryTime,
            urineMl: Int(urineMl) ?? 0,
            bowel: bowel,
            bristolType: bristolType,
            urineColor: urineColor,
            note: note,
            drinkMl: drinkVal,
            symptoms: symptoms.isEmpty ? nil : Array(symptoms),
            palpation: palpSettings.enabled ? palpation : nil,
            adSigns: adSigns.isEmpty ? nil : Array(adSigns),
            systolicBp: {
                guard adSettings.enabled, adSettings.bpEnabled, let v = Int(bpText), (60...300).contains(v) else { return nil }
                return v
            }(),
            stoolAmount: bowel ? stoolAmount : nil
        ))
        // store.add(...) startet die Live Activity bereits selbst.
        // Erinnerung nur neu takten, wenn wirklich die Blase entleert wurde —
        // reine Stuhl-/Trink-/Symptom-Einträge lassen den Rhythmus unberührt.
        if store.settings.reminderEnabled, (Int(urineMl) ?? 0) > 0 {
            notifications.scheduleReminder(afterMinutes: store.settings.intervalMinutes, settings: store.settings)
        }
        urineMl = ""; urineColor = .none; bowel = false; bristolType = .none; note = ""; drinkText = ""; symptoms = []; palpation = nil; adSigns = []; bpText = ""; stoolAmount = nil; entryTime = .now; showSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSaved = false }
    }

    private func startTimer() {
        timer?.invalidate(); updateTimeRemaining()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in updateTimeRemaining() }
    }

    private func updateTimeRemaining() {
        guard let last = store.lastBladderEntry else { timeRemaining = 0; return }
        timeRemaining = max(0, TimeInterval(store.settings.intervalMinutes * 60) - Date.now.timeIntervalSince(last.timestamp))
    }

    private func formatTime(_ s: TimeInterval) -> String {
        let total = Int(s)
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }

    private func overdueMinutes(since lastEntry: Date) -> Int {
        let intervalSeconds = store.settings.intervalMinutes * 60
        var dueDate = lastEntry.addingTimeInterval(TimeInterval(intervalSeconds))

        // If due during quiet hours, push to end of quiet hours
        if store.settings.quietHoursEnabled {
            let cal = Calendar.current
            let quietFrom = store.settings.quietFrom
            let quietTo = store.settings.quietTo
            let dueHour = cal.component(.hour, from: dueDate)

            let inQuiet: Bool
            if quietFrom < quietTo {
                inQuiet = dueHour >= quietFrom && dueHour < quietTo
            } else {
                inQuiet = dueHour >= quietFrom || dueHour < quietTo
            }

            if inQuiet {
                // Push due date to quietTo
                var components = cal.dateComponents([.year, .month, .day], from: dueDate)
                components.hour = quietTo
                components.minute = 0
                components.second = 0
                if let quietEnd = cal.date(from: components) {
                    dueDate = quietEnd <= dueDate
                        ? cal.date(byAdding: .day, value: 1, to: quietEnd)!
                        : quietEnd
                }
            }
        }

        let overdue = Int(Date.now.timeIntervalSince(dueDate)) / 60
        return Swift.max(0, overdue)
    }
}

#Preview { LogView().environment(DataStore()).environment(NotificationManager()).environment(StoreManager()).environment(CloudBackupManager()) }
