import SwiftUI

struct BirthdayGiftListView: View {
    let member: FamilyMember
    let birthday: FamilyItem

    @StateObject private var store = FamilyStore.shared
    @State private var showingEditor = false
    @State private var editingIdea: GiftIdea?
    @State private var title = ""
    @State private var note = ""

    private var ideas: [GiftIdea] {
        store.giftIdeas
            .filter { $0.memberID == member.id && $0.birthdayItemID == birthday.id }
            .sorted {
                if $0.isOrdered != $1.isOrdered { return !$0.isOrdered }
                return $0.createdAt < $1.createdAt
            }
    }

    private var openCount: Int { ideas.filter { !$0.isOrdered }.count }
    private var orderedCount: Int { ideas.filter(\.isOrdered).count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                if ideas.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Presentidéer")
                                .font(.system(size: 21, weight: .semibold, design: .serif))
                                .foregroundStyle(FamiljenTheme.ink)
                            Spacer()
                            Text("\(openCount) kvar")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FamiljenTheme.muted)
                        }
                        VStack(spacing: 0) {
                            ForEach(ideas) { idea in
                                giftRow(idea)
                                if idea.id != ideas.last?.id {
                                    Divider().overlay(FamiljenTheme.sand).padding(.leading, 52)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(FamiljenTheme.sand.opacity(0.7), lineWidth: 1))
                    }
                }
                if orderedCount > 0 {
                    Label("\(orderedCount) presenter ordnade", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FamiljenTheme.champagneDeep)
                }
                Text("Listan är personlig och sparas separat från familjens vanliga inköpslista.")
                    .font(.system(size: 12))
                    .foregroundStyle(FamiljenTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(FamiljenTheme.paper.ignoresSafeArea())
        .navigationTitle("Presentlista")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { startNewIdea() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.navy)
                }
                .accessibilityLabel("Lägg till presentidé")
            }
        }
        .sheet(isPresented: $showingEditor) {
            giftEditor
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(FamiljenTheme.champagne.opacity(0.2))
                    .frame(width: 58, height: 58)
                Image(systemName: "gift")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(FamiljenTheme.champagneDeep)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Till \(member.displayName)")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(FamiljenTheme.ink)
                Text(birthday.startsAt.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "sv_SE"))).capitalized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FamiljenTheme.navy)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(FamiljenTheme.sand.opacity(0.7), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: "gift")
                .font(.system(size: 27))
                .foregroundStyle(FamiljenTheme.champagneDeep)
            Text("Inga presentidéer ännu")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(FamiljenTheme.ink)
            Text("Skriv upp sådant \(member.displayName) önskar sig eller idéer ni vill komma ihåg.")
                .font(.system(size: 14))
                .foregroundStyle(FamiljenTheme.muted)
            Button { startNewIdea() } label: {
                Label("Lägg till första idén", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(FamiljenTheme.navy, in: Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func giftRow(_ idea: GiftIdea) -> some View {
        HStack(spacing: 11) {
            Button {
                var updated = idea
                updated.isOrdered.toggle()
                store.updateGiftIdea(updated)
            } label: {
                Image(systemName: idea.isOrdered ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(idea.isOrdered ? FamiljenTheme.champagneDeep : FamiljenTheme.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(idea.isOrdered ? "Markera som inte ordnad" : "Markera som ordnad")

            Button {
                editingIdea = idea
                title = idea.title
                note = idea.note ?? ""
                showingEditor = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(idea.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(idea.isOrdered ? FamiljenTheme.muted : FamiljenTheme.ink)
                        .strikethrough(idea.isOrdered)
                    if let note = idea.note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 13))
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                    if idea.isOrdered {
                        Text("Ordnad")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FamiljenTheme.champagneDeep)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .swipeActions {
            Button(role: .destructive) {
                store.deleteGiftIdea(idea.id)
            } label: {
                Label("Radera", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                editingIdea = idea
                title = idea.title
                note = idea.note ?? ""
                showingEditor = true
            } label: {
                Label("Redigera", systemImage: "pencil")
            }
            Button(role: .destructive) {
                store.deleteGiftIdea(idea.id)
            } label: {
                Label("Radera", systemImage: "trash")
            }
        }
    }

    private var giftEditor: some View {
        NavigationStack {
            Form {
                Section("Presentidé") {
                    TextField("Vad är presenten?", text: $title)
                        .textInputAutocapitalization(.sentences)
                    TextField("Anteckning (valfritt)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(editingIdea == nil ? "Ny presentidé" : "Redigera presentidé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { showingEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { saveIdea() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 160)
                }
            }
        }
        .tint(FamiljenTheme.navy)
    }

    private func startNewIdea() {
        editingIdea = nil
        title = ""
        note = ""
        showingEditor = true
    }

    private func saveIdea() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        if var idea = editingIdea {
            idea.title = cleanTitle
            idea.note = cleanNote.isEmpty ? nil : cleanNote
            store.updateGiftIdea(idea)
        } else {
            store.addGiftIdea(memberID: member.id, birthdayItemID: birthday.id,
                              title: cleanTitle, note: cleanNote.isEmpty ? nil : cleanNote)
        }
        showingEditor = false
    }
}
