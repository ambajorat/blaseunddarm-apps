import SwiftUI

extension Color {
    // blaseunddarm.de Palette: Dark + Orange
    static let accent = Color(light: .init(red: 0.85, green: 0.53, blue: 0.18),
                               dark: .init(red: 0.91, green: 0.57, blue: 0.23))

    static let accentBlue = accent // alias for existing references

    static let urine = Color(light: .init(red: 0.80, green: 0.60, blue: 0.15),
                              dark: .init(red: 0.91, green: 0.57, blue: 0.23))

    static let bowel = Color(light: .init(red: 0.55, green: 0.40, blue: 0.70),
                              dark: .init(red: 0.70, green: 0.55, blue: 0.85))

    static let pageBg = Color(light: .init(red: 0.97, green: 0.96, blue: 0.94),
                               dark: .init(red: 0.08, green: 0.08, blue: 0.08))

    static let cardBg = Color(light: .white,
                               dark: .init(red: 0.13, green: 0.13, blue: 0.13))

    static let subtleText = Color(light: .init(red: 0.45, green: 0.43, blue: 0.40),
                                   dark: .init(red: 0.60, green: 0.58, blue: 0.55))

    static let pillBg = Color(light: .init(red: 0.92, green: 0.91, blue: 0.89),
                               dark: .init(red: 0.18, green: 0.18, blue: 0.17))

    static let pillBorder = Color(light: .init(red: 0.80, green: 0.78, blue: 0.75),
                                   dark: .init(red: 0.35, green: 0.33, blue: 0.30))

    static let pillActiveBg = Color(light: .init(red: 0.85, green: 0.53, blue: 0.18),
                                     dark: .init(red: 0.91, green: 0.57, blue: 0.23))

    static let pillActiveText = Color(light: .white,
                                       dark: .init(red: 0.08, green: 0.08, blue: 0.08))
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
            ? UIColor(dark)
            : UIColor(light)
        })
    }
}
