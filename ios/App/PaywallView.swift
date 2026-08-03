import SwiftUI

// Premium wurde entfernt. Diese Ansicht wird nicht mehr angezeigt
// (alle Funktionen sind kostenlos), bleibt aber als kompilierbarer
// Platzhalter erhalten, damit vorhandene .sheet { PaywallView() }-Aufrufe
// in SettingsView, LogView und PremiumGate weiter gültig sind.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text("Alle Funktionen sind kostenlos.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }
}

#Preview { PaywallView() }
