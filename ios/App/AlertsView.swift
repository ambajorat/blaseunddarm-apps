import SwiftUI

struct AlertsView: View {
    @Environment(DataStore.self) private var store
    @State private var alerts = AlertSettings.load()

    var body: some View {
        NavigationStack {
            List {
                todaySection
                singleSection
                daySection
                countSection
                baselineSection
                suggestionSection
                footerSection
            }
            .navigationTitle("Hinweise")
            .onChange(of: alerts) { _, new in
                new.save()
            }
        }
    }

    // MARK: - Heute-Ampel

    private var todaySection: some View {
        Section {
            let statuses = AlertEngine.statusList(entries: store.entries, settings: alerts)
            if statuses.isEmpty {
                Text("Keine Regel aktiv. Schalte unten ein, worauf die App achten soll.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(statuses) { status in
                    HStack(spacing: 10) {
                        Image(systemName: icon(for: status.state))
                            .foregroundStyle(color(for: status.state))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(status.title).font(.subheadline.weight(.medium))
                            Text(status.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Heute")
        }
    }

    private func icon(for state: RuleState) -> String {
        switch state {
        case .ok: "checkmark.circle.fill"
        case .warn: "exclamationmark.triangle.fill"
        case .waiting: "clock"
        case .noData: "chart.line.uptrend.xyaxis"
        }
    }

    private func color(for state: RuleState) -> Color {
        switch state {
        case .ok: .green
        case .warn: .orange
        case .waiting: .secondary
        case .noData: .secondary
        }
    }

    // MARK: - Einzelmenge

    private var singleSection: some View {
        Section {
            Toggle(isOn: $alerts.singleOverEnabled) {
                Label("Einzelmenge über Grenze", systemImage: "drop.triangle.fill")
            }
            if alerts.singleOverEnabled {
                Stepper(value: $alerts.singleOverMl, in: 100...1000, step: 25) {
                    HStack {
                        Text("Grenze")
                        Spacer()
                        Text("\(alerts.singleOverMl) ml")
                            .foregroundStyle(Color.accent)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                }
            }
        } header: {
            Text("Einzelmenge")
        } footer: {
            Text("Warnt sofort beim Speichern, wenn ein einzelner Eintrag die Grenze erreicht.")
                .font(.caption)
        }
    }

    // MARK: - Tagesmenge

    private var daySection: some View {
        Section {
            Toggle(isOn: $alerts.dayOverEnabled) {
                Label("Tagesmenge über Grenze", systemImage: "arrow.up.circle")
            }
            if alerts.dayOverEnabled {
                Stepper(value: $alerts.dayOverMl, in: 1000...5000, step: 100) {
                    HStack {
                        Text("Grenze")
                        Spacer()
                        Text("\(alerts.dayOverMl) ml")
                            .foregroundStyle(Color.accent).fontWeight(.bold).monospacedDigit()
                    }
                }
            }
            Toggle(isOn: $alerts.dayUnderEnabled) {
                Label("Tagesmenge unter Grenze", systemImage: "arrow.down.circle")
            }
            if alerts.dayUnderEnabled {
                Stepper(value: $alerts.dayUnderMl, in: 250...3000, step: 100) {
                    HStack {
                        Text("Grenze")
                        Spacer()
                        Text("\(alerts.dayUnderMl) ml")
                            .foregroundStyle(Color.accent).fontWeight(.bold).monospacedDigit()
                    }
                }
            }
        } header: {
            Text("Tagesmenge")
        }
    }

    // MARK: - Häufigkeit

    private var countSection: some View {
        Section {
            Toggle(isOn: $alerts.countOverEnabled) {
                Label("Mehr Gänge als Grenze", systemImage: "arrow.up.circle")
            }
            if alerts.countOverEnabled {
                Stepper(value: $alerts.countOverLimit, in: 2...30) {
                    HStack {
                        Text("Grenze")
                        Spacer()
                        Text("\(alerts.countOverLimit) Gänge")
                            .foregroundStyle(Color.accent).fontWeight(.bold).monospacedDigit()
                    }
                }
            }
            Toggle(isOn: $alerts.countUnderEnabled) {
                Label("Weniger Gänge als Grenze", systemImage: "arrow.down.circle")
            }
            if alerts.countUnderEnabled {
                Stepper(value: $alerts.countUnderLimit, in: 1...15) {
                    HStack {
                        Text("Grenze")
                        Spacer()
                        Text("\(alerts.countUnderLimit) Gänge")
                            .foregroundStyle(Color.accent).fontWeight(.bold).monospacedDigit()
                    }
                }
            }
        } header: {
            Text("Häufigkeit")
        }
    }

    // MARK: - Persönliche Baseline

    private var baselineSection: some View {
        Section {
            Toggle(isOn: $alerts.baselineEnabled) {
                Label("Abweichung vom eigenen Schnitt", systemImage: "person.crop.circle.badge.exclamationmark")
            }
            if alerts.baselineEnabled {
                Stepper(value: $alerts.baselineDeviationPercent, in: 10...100, step: 5) {
                    HStack {
                        Text("Ab Abweichung von")
                        Spacer()
                        Text("±\(alerts.baselineDeviationPercent) %")
                            .foregroundStyle(Color.accent).fontWeight(.bold).monospacedDigit()
                    }
                }
                if let base = AlertEngine.baseline(entries: store.entries) {
                    HStack {
                        Text("Dein Schnitt (\(base.days) Tage)")
                        Spacer()
                        Text("\(base.avgMl) ml · \(String(format: "%.0f", base.avgCount)) Gänge")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } else {
                    Text("Noch nicht genug Daten — es braucht mindestens 5 Tage mit Einträgen in den letzten 14 Tagen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Persönlicher Schnitt")
        } footer: {
            Text("Vergleicht den heutigen Tag mit dem Durchschnitt deiner letzten 14 Tage — ganz ohne feste Grenzwerte.")
                .font(.caption)
        }
    }

    // MARK: - Footer

    // MARK: - Vorschläge aus den eigenen Daten

    @ViewBuilder
    private var suggestionSection: some View {
        if let sug = SuggestionEngine.compute(entries: store.entries), !sug.isEmpty {
            Section {
                if let v = sug.singleOverMl {
                    suggestionRow(String(localized: "Einzelmenge"),
                                  value: String(localized: "\(v) ml") + (sug.singleCapped ? String(localized: " (gedeckelt)") : "")) {
                        alerts.singleOverMl = v
                    }
                }
                if let v = sug.dayOverMl {
                    suggestionRow(String(localized: "Tagesmenge oben"), value: String(localized: "\(v) ml")) { alerts.dayOverMl = v }
                }
                if let v = sug.dayUnderMl {
                    suggestionRow(String(localized: "Tagesmenge unten"), value: String(localized: "\(v) ml")) { alerts.dayUnderMl = v }
                }
                if let v = sug.countOver {
                    suggestionRow(String(localized: "Gänge oben"), value: String(localized: "\(v) pro Tag")) { alerts.countOverLimit = v }
                }
                if let v = sug.countUnder {
                    suggestionRow(String(localized: "Gänge unten"), value: String(localized: "\(v) pro Tag")) { alerts.countUnderLimit = v }
                }
            } header: {
                Text("Vorschläge aus deinen Daten")
            } footer: {
                Text(sug.singleCapped
                     ? String(localized: "Beschreibt dein Muster der letzten 30 Tage — keine medizinische Empfehlung. Bei der Einzelmenge schlägt die App bewusst nie mehr als 500 ml vor.")
                     : String(localized: "Beschreibt dein Muster der letzten 30 Tage — keine medizinische Empfehlung."))
                    .font(.caption)
            }
        }
    }

    private func suggestionRow(_ title: String, value: String, apply: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(String(localized: "Übernehmen")) { apply() }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
        }
    }

    private var footerSection: some View {
        Section {
        } footer: {
            Text("Grenzen nach unten und Abweichungen unter den Schnitt prüft die App ab \(AlertEngine.underCheckHour) Uhr — vorher wäre jeder Morgen automatisch \u{201E}zu wenig\u{201C}. Geprüft wird bei jedem Eintrag und beim Öffnen der App.\n\nDiese Hinweise ersetzen keine ärztliche Beratung.")
                .font(.caption)
        }
    }
}

#Preview {
    AlertsView()
        .environment(DataStore())
}
