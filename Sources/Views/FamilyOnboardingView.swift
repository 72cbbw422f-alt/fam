import SwiftUI

struct FamilyOnboardingView: View {
    @State private var familyName = ""
    @State private var displayName = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, family
    }

    private var canCreate: Bool {
        !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            brandMark
                            Spacer()
                            Text("VÄLKOMMEN")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(2.2)
                                .foregroundStyle(FamiljenTheme.muted)
                        }
                        .padding(.bottom, 34)

                        Text("Allt som hör\ner till. På ett ställe.")
                            .font(.system(size: 34, weight: .semibold, design: .serif))
                            .tracking(-0.8)
                            .lineSpacing(1)
                            .foregroundStyle(FamiljenTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Skapa ert privata familjeutrymme och samla vardagens planer, viktiga datum och listor.")
                            .font(.system(size: 15, weight: .regular))
                            .lineSpacing(4)
                            .foregroundStyle(FamiljenTheme.muted)
                            .padding(.top, 12)
                            .padding(.bottom, 30)

                        VStack(alignment: .leading, spacing: 17) {
                            inputField("DITT NAMN", placeholder: "Förnamn", text: $displayName, field: .name)
                            inputField("FAMILJENS NAMN", placeholder: "Exempelvis Familjen", text: $familyName, field: .family)
                        }

                        Button {
                            LocalFamilyStore.shared.createFamily(name: familyName, ownerName: displayName)
                        } label: {
                            HStack {
                                Text("Skapa familj")
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .background(canCreate ? FamiljenTheme.navy : FamiljenTheme.navy.opacity(0.38),
                                        in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        }
                        .disabled(!canCreate)
                        .padding(.top, 24)

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(FamiljenTheme.champagneDeep)
                                .frame(width: 36, height: 36)
                                .background(FamiljenTheme.champagne.opacity(0.18), in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Privat från första stund")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(FamiljenTheme.ink)
                                Text("Uppgifterna sparas på den här iPhonen. Delning mellan familjens telefoner kommer i ett senare steg.")
                                    .font(.system(size: 12))
                                    .lineSpacing(3)
                                    .foregroundStyle(FamiljenTheme.muted)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(FamiljenTheme.sand.opacity(0.8), lineWidth: 1)
                        }
                        .padding(.top, 22)

                        Spacer(minLength: 24)
                        Text("FAMILJEN  ·  VARDAGENS GEMENSAMMA PLATS")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(FamiljenTheme.muted.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 28)
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, max(geometry.safeAreaInsets.top + 18, 28))
                    .padding(.bottom, 28)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .background(FamiljenTheme.paper.ignoresSafeArea())
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(FamiljenTheme.navy)
    }

    private var brandMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FamiljenTheme.navy)
                .frame(width: 48, height: 48)
            Image(systemName: "house.and.flag")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(FamiljenTheme.champagne)
        }
        .accessibilityLabel("Familjen")
    }

    private func inputField(_ title: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(FamiljenTheme.muted)
            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FamiljenTheme.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .submitLabel(field == .name ? .next : .done)
                .onSubmit {
                    focusedField = field == .name ? .family : nil
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(focusedField == field ? FamiljenTheme.champagne : FamiljenTheme.sand.opacity(0.8),
                                lineWidth: focusedField == field ? 1.5 : 1)
                }
        }
    }
}
