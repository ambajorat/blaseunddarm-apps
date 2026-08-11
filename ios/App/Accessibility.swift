import SwiftUI

// MARK: - Accessibility Helpers

extension View {
    /// Ensures minimum tap target of 44x44 points (Apple HIG)
    func accessibleTapTarget() -> some View {
        self.frame(minWidth: 44, minHeight: 44)
    }

    /// Adds accessibility label and hint for buttons
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }

    /// Groups child elements for VoiceOver
    func accessibleGroup(label: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
    }
}

// MARK: - Large Button Style (for motor impairments)

struct LargeButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(configuration.isPressed ? color.opacity(0.8) : color, in: .rect(cornerRadius: 12))
            .foregroundStyle(Color.pillActiveText)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Accessible Quick Value Button

struct AccessibleQuickValueButton: View {
    let value: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isSelected ? Color.pillActiveBg : Color.clear, in: .capsule)
                .foregroundStyle(isSelected ? Color.pillActiveText : .primary)
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.pillBorder, lineWidth: 1))
        }
        .accessibilityLabel("\(value) Milliliter")
        .accessibilityHint(isSelected ? "Ausgewählt" : "Doppeltippen um auszuwählen")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Accessible Color Picker

struct AccessibleColorButton: View {
    let color: UrineColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(color.emoji).font(.title3)
                Text(color.localizedName).font(.system(size: 9)).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.pillActiveBg : Color.clear, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.clear : Color.pillBorder, lineWidth: 1))
            .foregroundStyle(isSelected ? Color.pillActiveText : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Urinfarbe \(color.localizedName)")
        .accessibilityHint(isSelected ? "Ausgewählt. Doppeltippen zum Abwählen" : "Doppeltippen zum Auswählen")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Accessible Bristol Button

struct AccessibleBristolButton: View {
    let type: BristolType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(type.emoji).font(.title3)
                Text(type.label).font(.system(size: 9))
                Text(type.shortDesc).font(.system(size: 7)).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.bowel.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.bowel.opacity(0.4) : Color.pillBorder, lineWidth: 1))
            .foregroundStyle(isSelected ? Color.bowel : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(type.label): \(type.shortDesc). \(type.category)")
        .accessibilityHint(isSelected ? "Ausgewählt. Doppeltippen zum Abwählen" : "Doppeltippen zum Auswählen")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Timer Accessibility

struct AccessibleTimerView: View {
    let timeRemaining: TimeInterval
    let isOverdue: Bool
    let overdueMinutes: Int

    var body: some View {
        if isOverdue {
            let hours = overdueMinutes / 60
            let mins = overdueMinutes % 60
            let text = hours > 0
                ? "Überfällig seit \(hours) Stunden und \(mins) Minuten"
                : "Überfällig seit \(mins) Minuten"
            EmptyView()
                .accessibilityLabel("Toiletten-Erinnerung: \(text)")
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            let mins = Int(timeRemaining) / 60
            EmptyView()
                .accessibilityLabel("Nächste Erinnerung in \(mins) Minuten")
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

// MARK: - Summary Accessibility

extension View {
    func accessibleSummary(ml: Int, bowel: Int, count: Int) -> some View {
        self.accessibilityElement(children: .ignore)
            .accessibilityLabel("Tagesübersicht: \(ml) Milliliter Urin, \(bowel) mal Stuhlgang, \(count) Einträge")
    }
}
