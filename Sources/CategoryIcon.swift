import SwiftUI

/// Familjen's bespoke category tile: softly bevelled, tinted and consistent across the app.
struct CategoryIcon: View {
    let kind: FamilyItemKind
    var size: CGFloat = 46

    private var tint: Color {
        switch kind {
        case .birthday, .appointment: return Color(red: 0.72, green: 0.56, blue: 0.36)
        case .healthVisit, .dentist: return Color(red: 0.37, green: 0.49, blue: 0.61)
        case .medication: return Color(red: 0.64, green: 0.39, blue: 0.34)
        case .school: return Color(red: 0.43, green: 0.52, blue: 0.40)
        case .activity: return Color(red: 0.55, green: 0.58, blue: 0.39)
        case .trip: return Color(red: 0.34, green: 0.45, blue: 0.57)
        case .celebration: return Color(red: 0.70, green: 0.43, blue: 0.37)
        case .family: return FamiljenTheme.navy
        case .work: return Color(red: 0.48, green: 0.37, blue: 0.31)
        case .shopping: return Color(red: 0.72, green: 0.56, blue: 0.36)
        case .event: return Color(red: 0.53, green: 0.48, blue: 0.59)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.76), tint], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .stroke(.white.opacity(0.52), lineWidth: 1.2)
            if kind == .dentist {
                Text("🦷")
                    .font(.system(size: size * 0.48))
            } else {
                Image(systemName: kind.symbol)
                    .font(.system(size: size * 0.48, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.99, green: 0.96, blue: 0.89))
                    .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 0.5)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.22), radius: size * 0.10, x: 0, y: size * 0.06)
        .accessibilityLabel(kind.displayName)
    }
}