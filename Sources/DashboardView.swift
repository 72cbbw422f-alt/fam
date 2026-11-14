import SwiftUI

struct DashboardView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(FamiljenTheme.muted)
                        Text("Familjen")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(FamiljenTheme.ink)
                        Text("En gemensam plats för allt som hör er till.")
                            .font(.subheadline)
                            .foregroundStyle(FamiljenTheme.muted)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("NÄSTA BOKNING")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(FamiljenTheme.champagne)
                        Text("Här börjar familjens planering")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Lägg till läkarbesök, tandläkartider och andra bokningar.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FamiljenTheme.navy, in: RoundedRectangle(cornerRadius: 22))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Familjens överblick").font(.title3.weight(.semibold)).foregroundStyle(FamiljenTheme.ink)
                        Text("Det viktigaste, samlat på ett ställe").font(.caption).foregroundStyle(FamiljenTheme.muted)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        overviewCard("Födelsedagar", detail: "Kommande firanden", symbol: "gift")
                        overviewCard("Evenemang", detail: "Saker på gång", symbol: "sparkles")
                        overviewCard("Hälsa", detail: "Vårdbesök och tider", symbol: "heart.text.square")
                        overviewCard("Inköpslista", detail: "Gemensam lista", symbol: "basket")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Den här veckan").font(.title3.weight(.semibold)).foregroundStyle(FamiljenTheme.ink)
                        Text("Här visas familjens kommande aktiviteter när de lagts till.")
                            .font(.subheadline).foregroundStyle(FamiljenTheme.muted)
                    }
                }
                .padding(20)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func overviewCard(_ title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(FamiljenTheme.navy)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(FamiljenTheme.ink)
                Text(detail).font(.caption).foregroundStyle(FamiljenTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}
