import SwiftUI

// MARK: - Timer-Karte (Design v4: der Timer ist der Grund für die App und steht vorn)

struct TimerCard: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            card(now: context.date)
        }
    }

    @ViewBuilder
    private func card(now: Date) -> some View {
        let s = store.settings
        VStack(alignment: .leading, spacing: 6) {
            if !s.reminderEnabled {
                Label(String(localized: "timer_off"), systemImage: "bell.slash")
                    .font(.subheadline)
                    .foregroundStyle(Color.subtleText)
            } else if s.fixedTimesEnabled {
                // Wecker-Modus: feste Uhrzeiten
                if let next = AppSettings.nextFixedDue(after: now, times: s.sortedFixedTimes) {
                    countdown(to: next, now: now)
                }
            } else if let last = store.lastBladderEntry {
                let due = last.timestamp.addingTimeInterval(TimeInterval(s.intervalMinutes * 60))
                countdown(to: due, now: now)
                Text(String(format: String(localized: "timer_interval_fmt"),
                            intervalLabel(s.intervalMinutes),
                            last.timestamp.formatted(date: .omitted, time: .shortened)))
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)
            } else {
                Text(String(localized: "timer_no_entry"))
                    .font(.subheadline)
                    .foregroundStyle(Color.subtleText)
            }
            if s.reminderEnabled, s.quietHoursEnabled, s.isInQuietHours {
                Label(String(format: String(localized: "timer_quiet_fmt"), String(format: "%02d:00", s.quietTo)), systemImage: "moon.fill")
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardBg, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
    }

    @ViewBuilder
    private func countdown(to due: Date, now: Date) -> some View {
        let remaining = due.timeIntervalSince(now)
        if remaining > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(clock(remaining))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(String(localized: "timer_remaining"))
                    .font(.subheadline)
                    .foregroundStyle(Color.subtleText)
            }
            Text(String(format: String(localized: "timer_next_at_fmt"),
                        due.formatted(date: .omitted, time: .shortened)))
                .font(.caption)
                .foregroundStyle(Color.subtleText)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(clock(-remaining))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.red)
                Text(String(localized: "timer_overdue"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }
            Text(String(format: String(localized: "timer_due_was_fmt"),
                        due.formatted(date: .omitted, time: .shortened)))
                .font(.caption)
                .foregroundStyle(Color.subtleText)
        }
    }

    private func clock(_ s: TimeInterval) -> String {
        let total = Int(s)
        let h = total / 3600, m = (total % 3600) / 60, sec = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    private func intervalLabel(_ minutes: Int) -> String {
        AppSettings.intervals.first(where: { $0.minutes == minutes })?.label
            ?? "\(minutes) min"
    }
}

// MARK: - Schnellerfassung (Design v4: "Ein Tipp sichert")

struct QuickCaptureCard: View {
    let quickValues: [Int]
    let drinkEnabled: Bool
    let drinkAmount: Int
    let onUrine: (Int) -> Void
    let onBowel: () -> Void
    let onDrink: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 74), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "quick_title"))
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(String(localized: "quick_hint"))
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(quickValues, id: \.self) { val in
                    Button { onUrine(val) } label: {
                        VStack(spacing: 1) {
                            Text("\(val)").font(.body.weight(.bold)).monospacedDigit()
                            Text("ml").font(.caption2).foregroundStyle(Color.subtleText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.pillBg, in: .rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onBowel) {
                    VStack(spacing: 1) {
                        Text("💩").font(.body)
                        Text(String(localized: "quick_bowel")).font(.caption2).foregroundStyle(Color.subtleText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.pillBg, in: .rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                if drinkEnabled {
                    Button { onDrink(drinkAmount) } label: {
                        VStack(spacing: 1) {
                            Text("🥤").font(.body)
                            Text("+\(drinkAmount) ml").font(.caption2).foregroundStyle(Color.subtleText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.pillBg, in: .rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.cardBg, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
    }
}

// MARK: - Toast nach dem Ein-Tipp-Speichern (Ergänzen / Rückgängig)

struct QuickToast: View {
    let message: String
    let onAddDetails: () -> Void
    let onUndo: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button(action: onAddDetails) {
                    Text(String(localized: "quick_add_details"))
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accent, in: .rect(cornerRadius: 8))
                        .foregroundStyle(Color.pillActiveText)
                }
                Button(action: onUndo) {
                    Text(String(localized: "quick_undo"))
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.pillBg, in: .rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.cardBg, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pillBorder, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .padding(.horizontal, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Erstfrage (Design v4: eine Frage statt versteckter Module)

struct FirstRunSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("bb_firstrun_done") private var firstRunDone = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "firstrun_kicker"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accent)
                        .textCase(.uppercase)
                    Text(String(localized: "firstrun_title"))
                        .font(.title2.weight(.bold))
                    Text(String(localized: "firstrun_body"))
                        .font(.subheadline)
                        .foregroundStyle(Color.subtleText)

                    optionButton(title: String(localized: "firstrun_isk_title"),
                                 detail: String(localized: "firstrun_isk_detail")) {
                        apply(uti: true, palpation: true, ad: true, catheter: true)
                    }
                    optionButton(title: String(localized: "firstrun_spont_title"),
                                 detail: String(localized: "firstrun_spont_detail")) {
                        apply(uti: false, palpation: false, ad: false, catheter: false)
                    }
                    optionButton(title: String(localized: "firstrun_bowel_title"),
                                 detail: String(localized: "firstrun_bowel_detail")) {
                        apply(uti: false, palpation: false, ad: false, catheter: false)
                    }

                    Text(String(localized: "firstrun_note"))
                        .font(.caption)
                        .foregroundStyle(Color.subtleText)
                }
                .padding(20)
            }
            .background(Color.pageBg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "firstrun_skip")) {
                        firstRunDone = true
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(false)
    }

    private func optionButton(title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.bold))
                    .multilineTextAlignment(.leading)
                Text(detail).font(.caption).foregroundStyle(Color.subtleText)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.cardBg, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    /// Setzt nur die Modul-Schalter. Bestehende Detail-Einstellungen
    /// (Grenzen, Presets, Bestandszahlen) bleiben unangetastet.
    private func apply(uti: Bool, palpation: Bool, ad: Bool, catheter: Bool) {
        var u = UtiSettings.load(); u.enabled = uti; u.save()
        var p = PalpationSettings.load(); p.enabled = palpation; p.save()
        var a = AdSettings.load(); a.enabled = ad; a.save()
        var c = CatheterStock.load(); c.enabled = catheter; c.save()
        firstRunDone = true
        dismiss()
    }
}
