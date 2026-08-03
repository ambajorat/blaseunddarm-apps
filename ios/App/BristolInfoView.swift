import SwiftUI

struct BristolInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bristol-Stuhlformen-Skala")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                        Text("Die Bristol-Skala wurde 1997 an der Universität Bristol entwickelt und ist ein medizinisches Hilfsmittel zur Klassifikation der Stuhlform. Sie hilft bei der Beurteilung der Darmgesundheit und Transitzeit.")
                            .font(.subheadline)
                            .foregroundStyle(Color.subtleText)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Types
                    ForEach(BristolType.allCases.filter { $0 != .none }) { type in
                        bristolCard(type)
                    }
                    .padding(.horizontal, 20)

                    // Legend
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bedeutung")
                            .font(.subheadline.weight(.bold))

                        legendRow(color: .orange, label: "Typ 1–2", desc: "Verstopfung — zu wenig Flüssigkeit oder Ballaststoffe, lange Transitzeit")
                        legendRow(color: .green, label: "Typ 3–4", desc: "Normal — ideale Stuhlform, gesunde Verdauung")
                        legendRow(color: .red, label: "Typ 5–7", desc: "Durchfall — zu schnelle Passage, mögliche Infektion oder Unverträglichkeit")
                    }
                    .padding(18)
                    .background(Color.cardBg, in: .rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
                    .padding(.horizontal, 20)

                    // Disclaimer
                    Text("Diese Informationen dienen der Selbstbeobachtung und ersetzen keine ärztliche Beratung. Bei anhaltenden Veränderungen der Stuhlform sprich bitte mit deinem Arzt.")
                        .font(.caption)
                        .foregroundStyle(Color.subtleText)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
            .background(Color.pageBg)
            .navigationTitle("Bristol-Skala")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func bristolCard(_ type: BristolType) -> some View {
        HStack(spacing: 14) {
            Text(type.emoji)
                .font(.system(size: 32))
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(type.label)
                        .font(.subheadline.weight(.bold))
                    Text("— \(type.category)")
                        .font(.caption)
                        .foregroundStyle(categoryColor(type))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(categoryColor(type).opacity(0.12), in: .capsule)
                }
                Text(type.detail)
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBg, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
    }

    private func legendRow(color: Color, label: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.bold))
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)
            }
        }
    }

    private func categoryColor(_ type: BristolType) -> Color {
        switch type.category {
        case "Verstopfung": .orange
        case "Normal": .green
        case "Durchfall": .red
        default: .secondary
        }
    }
}

#Preview {
    BristolInfoView()
}
