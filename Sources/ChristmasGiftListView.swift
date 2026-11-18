import SwiftUI

struct ChristmasGiftListView: View {
    @StateObject private var store = FamilyStore.shared
    @State private var showingEditor = false
    @State private var editingGift: ChristmasGift?
    @State private var recipient = ""
    @State private var title = ""
    @State private var note = ""
    @State private var responsibleMemberID: UUID?

    private var sortedGifts: [ChristmasGift] {
        store.christmasGifts.sorted {
            if $0.status != $1.status { return $0.status.rawValue < $1.status.rawValue }
            if $0.recipient.localizedCaseInsensitiveCompare($1.recipient) != .orderedSame {
                return $0.recipient.localizedCaseInsensitiveCompare($1.recipient) == .orderedAscending
            }
            return $0.createdAt < $1.createdAt
        }
    }
    private var purchasedCount: Int { store.christmasGifts.filter { $0.status == .purchased }.count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                intro
                HStack(spacing: 10) {
                    summaryCard(value: "\(store.christmasGifts.count)", label: "Presenter", symbol: "gift")
                    summaryCard(value: "\(purchasedCount)", label: "Inköpta", symbol: "checkmark.circle")
                    summaryCard(value: "\(store.christmasGifts.count - purchasedCount)", label: "Kvar", symbol: "list.bullet")
                }
                if sortedGifts.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(sortedGifts) { gift in
                            giftRow(gift)
                            if gift.id != sortedGifts.last?.id {
                                Divider().overlay(FamiljenTheme.sand).padding(.leading, 54)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 19).stroke(FamiljenTheme.sand.opacity(0.7), lineWidth: 1))
                }
                Label("Listan sparas lokalt på den här iPhonen. Gemensam uppdatering mellan två telefoner kräver att iCloud-delning aktiveras.", systemImage: "iphone")
                    .font(.system(size: 12))
                    .foregroundStyle(FamiljenTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(FamiljenTheme.paper.ignoresSafeArea())
        .navigationTitle("Julklappslista")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { startNewGift() } label: {
                    Image(systemName: "plus").font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel("Lägg till julklapp")
            }
        }
        .sheet(isPresented: $showingEditor) { editor }
    }

    private var intro: some View {
        HStack(spacing: 14) {
            Image(systemName: "gift.fill")
                .font(.system(size: 27))
                .foregroundStyle(FamiljenTheme.champagneDeep)
                .frame(width: 58, height: 58)
                .background(FamiljenTheme.champagne.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text("Jul utan dubbelköp")
                    .font(.system(size: 21, weight: .semibold, design: .serif))
                    .foregroundStyle(FamiljenTheme.ink)
                Text("Samla idéer, mottagare och ansvar på ett ställe.")
                    .font(.system(size: 14))
                    .foregroundStyle(FamiljenTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(FamiljenTheme.sand.opacity(0.7), lineWidth: 1))
    }

    private func summaryCard(value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: symbol).foregroundStyle(FamiljenTheme.champagneDeep)
            Text(value).font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(FamiljenTheme.ink)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(FamiljenTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 15))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Julklappslistan är tom")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(FamiljenTheme.ink)
            Text("Lägg till första presenten och välj vem som ska få den och vem som ordnar inköpet.")
                .font(.system(size: 14))
                .foregroundStyle(FamiljenTheme.muted)
            Button { startNewGift() } label: {
                Label("Lägg till första julklappen", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func giftRow(_ gift: ChristmasGift) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Button {
                var updated = gift
                updated.status = gift.status == .purchased ? .planned : .purchased
                store.updateChristmasGift(updated)
            } label: {
                Image(systemName: gift.status == .purchased ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(gift.status == .purchased ? FamiljenTheme.champagneDeep : FamiljenTheme.muted)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text(gift.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(gift.status == .purchased ? FamiljenTheme.muted : FamiljenTheme.ink)
                    .strikethrough(gift.status == .purchased)
                Text("Till: \(gift.recipient)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FamiljenTheme.navy)
                HStack(spacing: 5) {
                    Text(gift.responsibleMemberID.flatMap { id in store.members.first { $0.id == id }?.displayName } ?? "Ingen ansvarig")
                    Text("·")
                    Text(gift.status.title)
                }
                .font(.system(size: 12))
                .foregroundStyle(FamiljenTheme.muted)
                if let note = gift.note, !note.isEmpty {
                    Text(note).font(.system(size: 12)).foregroundStyle(FamiljenTheme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button("Redigera", systemImage: "pencil") { edit(gift) }
                Button(gift.status == .purchased ? "Markera ej inköpt" : "Markera inköpt", systemImage: "checkmark") {
                    var updated = gift
                    updated.status = gift.status == .purchased ? .planned : .purchased
                    store.updateChristmasGift(updated)
                }
                Button("Ta bort", systemImage: "trash", role: .destructive) { store.deleteChristmasGift(gift.id) }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 17, weight: .semibold)).foregroundStyle(FamiljenTheme.muted).padding(7)
            }
        }
        .padding(.vertical, 13)
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section("Presenten") {
                    TextField("Vad ska köpas?", text: $title)
                    TextField("Vem ska få den?", text: $recipient)
                        .textInputAutocapitalization(.words)
                    if !store.members.isEmpty {
                        Text("Snabbval")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.members) { member in
                                    Button(member.displayName) { recipient = member.displayName }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
                Section("Ansvar") {
                    Picker("Vem ordnar den?", selection: $responsibleMemberID) {
                        Text("Inte bestämt").tag(UUID?.none)
                        ForEach(store.members.filter { $0.role != .child }) { member in
                            Text(member.displayName).tag(Optional(member.id))
                        }
                    }
                    if editingGift != nil {
                        Picker("Status", selection: Binding(
                            get: { editingGift?.status ?? .idea },
                            set: { editingGift?.status = $0 }
                        )) {
                            ForEach(ChristmasGiftStatus.allCases) { status in
                                Text(status.title).tag(status)
                            }
                        }
                    }
                }
                Section("Anteckning") {
                    TextField("Storlek, länk eller annan information", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(editingGift == nil ? "Ny julklapp" : "Redigera julklapp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { showingEditor = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { saveGift() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(FamiljenTheme.navy)
    }

    private func startNewGift() {
        editingGift = nil
        title = ""
        recipient = ""
        note = ""
        responsibleMemberID = nil
        showingEditor = true
    }

    private func edit(_ gift: ChristmasGift) {
        editingGift = gift
        title = gift.title
        recipient = gift.recipient
        note = gift.note ?? ""
        responsibleMemberID = gift.responsibleMemberID
        showingEditor = true
    }

    private func saveGift() {
        let cleanRecipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRecipient.isEmpty, !cleanTitle.isEmpty else { return }
        if var gift = editingGift {
            gift.recipient = cleanRecipient
            gift.title = cleanTitle
            gift.note = cleanNote.isEmpty ? nil : cleanNote
            gift.responsibleMemberID = responsibleMemberID
            store.updateChristmasGift(gift)
        } else {
            store.addChristmasGift(recipient: cleanRecipient, title: cleanTitle,
                note: cleanNote.isEmpty ? nil : cleanNote, responsibleMemberID: responsibleMemberID)
        }
        showingEditor = false
    }
}
