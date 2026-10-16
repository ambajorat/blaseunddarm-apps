import SwiftUI

/// „Abstände nach Tageszeit“ — rechnet aus den eigenen Einträgen der letzten
/// 30 Tage die Füllrate je Tagesfenster aus und schlägt passende Abstände bzw.
/// feste Erinnerungszeiten vor. Nichts wird automatisch übernommen.
struct IntervalPlanView: View {
    @Environment(DataStore.self) private var store
    @State private var showApplyConfirm = false

    private var target: Int { store.settings.targetVolumeMl ?? SuggestionEngine.defaultTargetMl }

    var body: some View {
        let plan = SuggestionEngine.intervalPlan(entries: store.entries, targetMl: target)
        List {
            Section {
                Stepper(value: Binding(
                    get: { target },
                    set: { store.settings.targetVolumeMl = $0 }
                ), in: 250...500, step: 25) {
                    HStack {
                        Text("Zielmenge")
                        Spacer()
                        Text("\(target) ml")
                            .foregroundStyle(Color.accentBlue)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                }
            } footer: {
                Text("Die Menge, die pro Entleerung möglichst nicht überschritten werden soll. Für die Katheterisierung werden häufig 400–500 ml als Obergrenze genannt — stimme den Wert mit deiner urologischen Praxis ab.")
            }

            if let plan {
                Section {
                    ForEach(plan.slots) { slot in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: "\(slot.label) · \(slot.rangeText)")
                                    .font(.subheadline.weight(.medium))
                                Text(slot.usesFallback
                                     ? String(localized: "Füllrate bis \(slot.rateMlPerHour) ml/Std (Tageswert)")
                                     : String(localized: "Füllrate bis \(slot.rateMlPerHour) ml/Std · \(slot.samples) Abstände"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                if slot.overTarget > 0 {
                                    Text(String(localized: "Bisher \(slot.overTarget)× über \(plan.targetMl) ml"))
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            Text(Self.formatInterval(slot.suggestedMinutes))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.accentBlue)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Vorgeschlagener Abstand je Tageszeit")
                } footer: {
                    Text("Füllrate = Menge geteilt durch die Zeit seit der letzten Entleerung. Gerechnet wird mit einem eher hohen Wert (drei von vier Abständen lagen darunter), damit die Zielmenge meistens nicht erreicht wird.")
                }

                Section {
                    LabeledContent(String(localized: "Über der Zielmenge")) {
                        Text(String(localized: "\(plan.overTarget) von \(plan.volumes)"))
                            .monospacedDigit()
                    }
                    if let morning = plan.morningMedianMl {
                        LabeledContent(String(localized: "Erste Menge am Morgen")) {
                            Text(String(localized: "Median \(morning) ml"))
                                .monospacedDigit()
                        }
                        if plan.morningOverTarget > 0 {
                            Text(String(localized: "Nach der Nacht lag die erste Menge \(plan.morningOverTarget) von \(plan.morningSamples) Mal über \(plan.targetMl) ml. Die Nacht deckt der Vorschlag nicht ab — sprich das bei Bedarf in deiner Praxis an."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Letzte 30 Tage")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 8)], spacing: 8) {
                        ForEach(plan.times, id: \.self) { m in
                            Text(Self.clock(m))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.accentBlue.opacity(0.12), in: .rect(cornerRadius: 8))
                                .foregroundStyle(Color.accentBlue)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(plan.times.map(Self.clock).joined(separator: ", "))

                    Toggle(isOn: Binding(
                        get: { store.settings.anchorsToFirstVoid },
                        set: { store.setAnchorToFirstVoid($0) }
                    )) {
                        Text("An Entleerungen ausrichten")
                            .font(.subheadline)
                    }

                    if store.settings.fixedTimesEnabled && store.settings.fixedTemplate == plan.times {
                        Label(String(localized: "Als feste Zeiten aktiv"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Button {
                            showApplyConfirm = true
                        } label: {
                            Label(String(localized: "Als feste Zeiten übernehmen"), systemImage: "alarm")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                } header: {
                    Text("Vorgeschlagene feste Zeiten")
                } footer: {
                    Text(String(localized: "Von \(Self.clock(plan.wakeMinutes)) (deine übliche erste Entleerung) bis \(Self.clock(plan.bedMinutes)) (deine übliche letzte vor der Nacht). Übernehmen ersetzt deine bisherigen festen Zeiten — jede Zeit lässt sich danach in den Einstellungen anpassen.") + (store.settings.anchorsToFirstVoid ? " " + String(localized: "Mit Ausrichtung richtet sich der Plan nach deinen tatsächlichen Entleerungen: Der Tag beginnt mit der ersten am Morgen, und nach jeder Entleerung startet der Abstand neu.") : ""))
                }
                .confirmationDialog(
                    String(localized: "Feste Zeiten ersetzen?"),
                    isPresented: $showApplyConfirm,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "Als feste Zeiten übernehmen")) { apply(plan.times) }
                    Button(String(localized: "Abbrechen"), role: .cancel) {}
                } message: {
                    Text("Die Erinnerungsart wird auf „Feste Zeiten“ gestellt.")
                }
            } else {
                Section {
                    Text("Für einen Vorschlag braucht es Urin-Einträge an mindestens 7 Tagen in den letzten 30 Tagen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
            } footer: {
                Text("Alle Werte beschreiben nur deine eigenen Einträge der letzten 30 Tage. Sie sind keine medizinische Empfehlung und ersetzen keine ärztliche Beratung.")
            }
        }
        .navigationTitle(String(localized: "Abstände nach Tageszeit"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func apply(_ times: [Int]) {
        store.settings.useFixedTimes = true
        store.settings.reminderEnabled = true
        // Grundplan setzen; bei Ausrichtung sofort auf heute verschieben.
        store.setFixedTemplate(times)
        // Wecker-Modus plant über die eingebaute Weiche neu (räumt Intervall-Erinnerung ab)
        NotificationManager.rescheduleReminder(
            afterMinutes: store.settings.intervalMinutes,
            settings: store.settings
        )
    }

    static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    static func formatInterval(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return String(localized: "\(m) Min") }
        if m == 0 { return String(localized: "\(h) Std") }
        if m == 30 { return String(localized: "\(h),5 Std") }
        return String(localized: "\(h) Std \(m) Min")
    }
}

/// Kompakte Statistik-Karte mit Füllrate je Tageszeit und Sprung in den Vorschlag.
struct FillRateCard: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        let target = store.settings.targetVolumeMl ?? SuggestionEngine.defaultTargetMl
        if let plan = SuggestionEngine.intervalPlan(entries: store.entries, targetMl: target) {
            let maxRate = max(plan.slots.map(\.rateMlPerHour).max() ?? 1, 1)
            NavigationLink {
                IntervalPlanView()
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.subheadline)
                            .foregroundStyle(Color.accent)
                        Text("Füllrate nach Tageszeit")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    ForEach(plan.slots) { slot in
                        HStack(spacing: 8) {
                            Text(slot.label)
                                .font(.caption)
                                .frame(width: 92, alignment: .leading)
                            GeometryReader { geo in
                                Capsule()
                                    .fill(Color.accentBlue.opacity(0.7))
                                    .frame(width: max(4, geo.size.width * CGFloat(slot.rateMlPerHour) / CGFloat(maxRate)))
                            }
                            .frame(height: 8)
                            Text(IntervalPlanView.formatInterval(slot.suggestedMinutes))
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .frame(width: 84, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(localized: "\(slot.label): Füllrate bis \(slot.rateMlPerHour) ml pro Stunde, Abstand \(IntervalPlanView.formatInterval(slot.suggestedMinutes))"))
                    }
                    Text(String(localized: "Vorgeschlagene Abstände für höchstens \(plan.targetMl) ml — aus deinen letzten 30 Tagen."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color.cardBg, in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }
}
