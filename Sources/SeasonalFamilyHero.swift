import SwiftUI
import UIKit

/// A locally rendered seasonal illustration. It changes automatically with the
/// device calendar and remains available offline.
struct SeasonalFamilyHero: View {
    let familyName: String

    @Environment(\.scenePhase) private var scenePhase
    @State private var currentDate = Date.now

    private var scene: SeasonalScene {
        SeasonalSceneResolver.scene(for: currentDate)
    }

    private var adventLitCount: Int {
        SeasonalSceneResolver.adventLitCount(for: currentDate)
    }

    private var sceneTitle: String {
        switch scene {
        case .autumn: return "En plats för allt som hör er till"
        case .advent: return "Vi tänder ett ljus i advent"
        case .lucia: return "Ljus i vintermörkret"
        case .christmas: return "En riktigt god jul"
        case .winter: return "Värme i vintertid"
        case .spring: return "Ljuset är på väg tillbaka"
        case .summer: return "Tid för ljusa dagar"
        }
    }

    private var palette: [Color] {
        switch scene {
        case .autumn:
            return [Color(red: 0.20, green: 0.30, blue: 0.35), Color(red: 0.49, green: 0.39, blue: 0.30), Color(red: 0.76, green: 0.57, blue: 0.36)]
        case .advent:
            return [Color(red: 0.10, green: 0.17, blue: 0.25), Color(red: 0.22, green: 0.31, blue: 0.34), Color(red: 0.58, green: 0.43, blue: 0.30)]
        case .lucia:
            return [Color(red: 0.13, green: 0.20, blue: 0.30), Color(red: 0.34, green: 0.38, blue: 0.43), Color(red: 0.78, green: 0.67, blue: 0.49)]
        case .christmas:
            return [Color(red: 0.12, green: 0.27, blue: 0.25), Color(red: 0.22, green: 0.39, blue: 0.34), Color(red: 0.66, green: 0.47, blue: 0.31)]
        case .winter:
            return [Color(red: 0.22, green: 0.34, blue: 0.45), Color(red: 0.43, green: 0.52, blue: 0.59), Color(red: 0.76, green: 0.78, blue: 0.75)]
        case .spring:
            return [Color(red: 0.27, green: 0.43, blue: 0.40), Color(red: 0.48, green: 0.59, blue: 0.49), Color(red: 0.82, green: 0.72, blue: 0.56)]
        case .summer:
            return [Color(red: 0.22, green: 0.43, blue: 0.52), Color(red: 0.42, green: 0.62, blue: 0.61), Color(red: 0.85, green: 0.73, blue: 0.52)]
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 142, height: 142)
                    .blur(radius: 1)
                    .position(x: width * 0.84, y: height * 0.15)

                Circle()
                    .fill(FamiljenTheme.champagne.opacity(0.18))
                    .frame(width: 172, height: 172)
                    .blur(radius: 13)
                    .position(x: width * 0.89, y: height * 0.76)

                seasonalArtwork
                    .frame(width: 190, height: 145)
                    .position(x: width * 0.78, y: height * 0.54)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(currentDate.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "sv_SE"))).capitalized)
                    Text("·").foregroundStyle(.white.opacity(0.7))
                    Text("v. \(Calendar(identifier: .iso8601).component(.weekOfYear, from: currentDate))")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))

                Text(familyName)
                    .font(.system(size: 29, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(sceneTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
            }
            .padding(19)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 174)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: FamiljenTheme.navy.opacity(0.10), radius: 13, x: 0, y: 7)
        .accessibilityElement(children: .combine)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshSeasonalDate()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshSeasonalDate()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshSeasonalDate()
            }
        }
    }

    private func refreshSeasonalDate() {
        currentDate = .now
    }

    @ViewBuilder
    private var seasonalArtwork: some View {
        switch scene {
        case .advent:
            AdventCandlesArtwork(litCount: adventLitCount)
        case .lucia:
            LuciaArtwork()
        case .christmas:
            ChristmasArtwork()
        case .winter:
            WinterArtwork()
        case .spring:
            SeasonalSymbolArtwork(symbol: "leaf.fill", secondary: "sparkles")
        case .summer:
            SeasonalSymbolArtwork(symbol: "sun.max.fill", secondary: "water.waves")
        case .autumn:
            SeasonalSymbolArtwork(symbol: "leaf.fill", secondary: "wind")
        }
    }


}

enum SeasonalScene: Equatable {
    case autumn, advent, lucia, christmas, winter, spring, summer
}

enum SeasonalSceneResolver {
    static func scene(for date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> SeasonalScene {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let year = calendar.component(.year, from: date)
        let today = calendar.startOfDay(for: date)
        let firstAdvent = calendar.startOfDay(for: firstSundayOnOrAfterNovember27(year: year, calendar: calendar))
        let christmasEve = makeDate(year: year, month: 12, day: 24, calendar: calendar) ?? firstAdvent

        if month == 12 && day == 13 { return .lucia }
        if today >= firstAdvent && today < christmasEve { return .advent }
        if (month == 12 && day >= 24) || (month == 1 && day <= 6) { return .christmas }

        switch month {
        case 11, 12, 1, 2: return .winter
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        default: return .autumn
        }
    }

    static func adventLitCount(for date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Int {
        let year = calendar.component(.year, from: date)
        let first = calendar.startOfDay(for: firstSundayOnOrAfterNovember27(year: year, calendar: calendar))
        let today = calendar.startOfDay(for: date)
        guard today >= first else { return 0 }
        let days = calendar.dateComponents([.day], from: first, to: today).day ?? 0
        return min(4, max(1, days / 7 + 1))
    }

    private static func firstSundayOnOrAfterNovember27(year: Int, calendar: Calendar) -> Date {
        let start = makeDate(year: year, month: 11, day: 27, calendar: calendar) ?? .now
        let weekday = calendar.component(.weekday, from: start)
        let daysUntilSunday = (8 - weekday) % 7
        return calendar.date(byAdding: .day, value: daysUntilSunday, to: start) ?? start
    }

    private static func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }
}

private struct AdventCandlesArtwork: View {
    let litCount: Int

    var body: some View {
        ZStack {
            Ellipse().fill(Color.black.opacity(0.16)).frame(width: 166, height: 20).offset(y: 47)
            HStack(alignment: .bottom, spacing: 10) {
                candle(height: 66, lit: litCount >= 1)
                candle(height: 78, lit: litCount >= 2)
                candle(height: 70, lit: litCount >= 3)
                candle(height: 60, lit: litCount >= 4)
            }
            .offset(y: 15)
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(Color(red: 0.25, green: 0.42, blue: 0.32))
                        .frame(width: 28, height: 18)
                        .rotationEffect(.degrees(Double(index) * 18 - 25))
                }
            }
            .offset(y: 48)
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.48))
                .offset(x: -72, y: -45)
        }
    }

    private func candle(height: CGFloat, lit: Bool) -> some View {
        VStack(spacing: 0) {
            if lit {
                Ellipse()
                    .fill(Color(red: 1.0, green: 0.78, blue: 0.35).opacity(0.35))
                    .frame(width: 28, height: 38)
                    .overlay {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(Color(red: 1.0, green: 0.83, blue: 0.48))
                    }
                    .shadow(color: .orange.opacity(0.55), radius: 12)
            } else {
                Ellipse().fill(Color.white.opacity(0.08)).frame(width: 24, height: 30)
            }
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(colors: [Color(red: 0.96, green: 0.89, blue: 0.72), Color(red: 0.78, green: 0.67, blue: 0.48)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 19, height: height)
                .overlay(alignment: .top) {
                    Capsule().fill(Color.white.opacity(0.65)).frame(width: 2, height: 8).offset(x: -5, y: 7)
                }
        }
    }
}

private struct LuciaArtwork: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                VStack(spacing: 3) {
                    Circle().fill(Color(red: 0.91, green: 0.82, blue: 0.69)).frame(width: 23, height: 23)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(index == 1 ? Color(red: 0.93, green: 0.90, blue: 0.80) : Color(red: 0.78, green: 0.81, blue: 0.82))
                        .frame(width: 27, height: 62)
                    if index == 1 {
                        HStack(spacing: 3) {
                            ForEach(0..<5, id: \.self) { _ in
                                Capsule().fill(Color(red: 1.0, green: 0.78, blue: 0.35)).frame(width: 3, height: 9)
                            }
                        }
                        .offset(y: -68)
                    }
                }
                .offset(x: CGFloat(index - 1) * 48, y: CGFloat(index == 1 ? -5 : 9))
            }
            HStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "sparkle")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.55))
                }
            }
            .offset(y: -62)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 5)
    }
}

private struct ChristmasArtwork: View {
    var body: some View {
        ZStack {
            Image(systemName: "tree.fill")
                .font(.system(size: 112, weight: .light))
                .foregroundStyle(Color(red: 0.13, green: 0.31, blue: 0.25))
                .shadow(color: .black.opacity(0.15), radius: 7, x: 0, y: 5)
            Image(systemName: "star.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.48))
                .offset(y: -62)
            HStack(spacing: 20) {
                Circle().fill(Color(red: 0.84, green: 0.42, blue: 0.34)).frame(width: 9, height: 9)
                Circle().fill(Color(red: 1.0, green: 0.82, blue: 0.48)).frame(width: 9, height: 9)
                Circle().fill(Color(red: 0.84, green: 0.42, blue: 0.34)).frame(width: 9, height: 9)
            }
            .offset(y: 3)
        }
    }
}

private struct WinterArtwork: View {
    var body: some View {
        ZStack {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 70, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.82))
                .offset(x: 43, y: -37)

            HStack(alignment: .bottom, spacing: -12) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 76, weight: .ultraLight))
                    .foregroundStyle(Color(red: 0.76, green: 0.84, blue: 0.83).opacity(0.78))
                Image(systemName: "tree.fill")
                    .font(.system(size: 112, weight: .ultraLight))
                    .foregroundStyle(Color(red: 0.91, green: 0.94, blue: 0.91).opacity(0.92))
                Image(systemName: "tree.fill")
                    .font(.system(size: 86, weight: .ultraLight))
                    .foregroundStyle(Color(red: 0.70, green: 0.80, blue: 0.81).opacity(0.82))
            }
            .offset(x: 8, y: 38)

            ForEach(0..<8, id: \.self) { index in
                Image(systemName: "snowflake")
                    .font(.system(size: CGFloat(8 + index % 3 * 3), weight: .light))
                    .foregroundStyle(.white.opacity(0.82))
                    .offset(x: CGFloat((index % 4) * 42 - 66), y: CGFloat((index / 4) * 54 - 46))
            }
        }
    }
}

private struct SeasonalSymbolArtwork: View {
    let symbol: String
    let secondary: String

    var body: some View {
        ZStack {
            Image(systemName: symbol)
                .font(.system(size: 88, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.78))
                .offset(x: 15, y: -5)
            Image(systemName: secondary)
                .font(.system(size: 35, weight: .light))
                .foregroundStyle(FamiljenTheme.champagne.opacity(0.9))
                .offset(x: -45, y: 42)
        }
    }
}
