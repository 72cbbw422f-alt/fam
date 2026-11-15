import SwiftUI

struct FamilyOnboardingView: View {
    @State private var familyName = ""
    @State private var displayName = ""
    private var canCreate: Bool {
        !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Välkommen till Familjen").font(.largeTitle.weight(.semibold)).foregroundStyle(FamiljenTheme.ink)
                        Text("Skapa familjens lokala utrymme på den här iPhone-enheten.").foregroundStyle(FamiljenTheme.muted)
                    }
                    field("Ditt namn", text: $displayName, placeholder: "Förnamn")
                    field("Familjens namn", text: $familyName, placeholder: "Exempelvis Familjen")
                    Button { LocalFamilyStore.shared.createFamily(name: familyName, ownerName: displayName) } label: {
                        Text("Skapa familj").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .foregroundStyle(.white).background(FamiljenTheme.navy, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canCreate).opacity(canCreate ? 1 : 0.5)
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Sparas lokalt på den här enheten", systemImage: "iphone").font(.subheadline.weight(.semibold))
                        Text("Testversionen synkar inte mellan telefoner. Varje iPhone har sin egen familjedata. iCloud-delning kommer senare.")
                            .font(.footnote).foregroundStyle(FamiljenTheme.muted)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }.padding(20)
            }.background(FamiljenTheme.paper.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        }
    }
    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(FamiljenTheme.ink)
            TextField(placeholder, text: text).textFieldStyle(.plain).padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
