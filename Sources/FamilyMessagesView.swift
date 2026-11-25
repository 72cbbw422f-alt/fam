import SwiftUI

struct FamilyMessagesView: View {
    @StateObject private var store = FamilyStore.shared

    private var ownerID: UUID? { store.members.first(where: { $0.role == .owner })?.id }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introCard
                VStack(alignment: .leading, spacing: 8) {
                    Text("Familjen")
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                        .foregroundStyle(FamiljenTheme.ink)
                    conversationRow(title: store.family?.name ?? "Familjechatten",
                                    subtitle: latestText(for: "family") ?? "Skriv något till hela familjen",
                                    symbol: "house.fill", conversationID: "family",
                                    kind: .family, unread: unreadCount(for: "family"))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privata meddelanden")
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                        .foregroundStyle(FamiljenTheme.ink)
                    ForEach(store.members.filter { $0.id != ownerID }) { member in
                        conversationRow(title: member.displayName,
                                        subtitle: latestText(for: member.id.uuidString) ?? "Starta en privat konversation",
                                        symbol: "person.crop.circle.fill",
                                        conversationID: member.id.uuidString,
                                        kind: .direct, unread: unreadCount(for: member.id.uuidString))
                    }
                    if store.members.filter({ $0.id != ownerID }).isEmpty {
                        Text("Lägg till familjemedlemmar under Mer för att kunna skapa privata konversationer.")
                            .font(.system(size: 15))
                            .foregroundStyle(FamiljenTheme.muted)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                }
            }
            .padding(18)
        }
        .background(FamiljenTheme.paper.ignoresSafeArea())
        .navigationTitle("Meddelanden")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var introCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 23))
                .foregroundStyle(FamiljenTheme.champagneDeep)
                .frame(width: 46, height: 46)
                .background(FamiljenTheme.sand.opacity(0.65), in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
                Text("Håll kontakten")
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .foregroundStyle(FamiljenTheme.ink)
                Text("Samla familjens små meddelanden på ett ställe.")
                    .font(.system(size: 15))
                    .foregroundStyle(FamiljenTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(FamiljenTheme.sand.opacity(0.7), lineWidth: 1))
    }

    private func conversationRow(title: String, subtitle: String, symbol: String,
                                 conversationID: String, kind: FamilyConversationKind,
                                 unread: Int) -> some View {
        NavigationLink {
            FamilyChatView(title: title, conversationID: conversationID, kind: kind)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(FamiljenTheme.navy)
                    .frame(width: 49, height: 49)
                    .background(FamiljenTheme.sand.opacity(0.55), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(FamiljenTheme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 23, minHeight: 23)
                        .background(FamiljenTheme.champagneDeep, in: Circle())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.muted.opacity(0.7))
                }
            }
            .padding(13)
            .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func latestText(for id: String) -> String? {
        store.messages.filter { $0.conversationID == id }.max { $0.sentAt < $1.sentAt }?.text
    }

    private func unreadCount(for id: String) -> Int {
        store.messages.filter { $0.conversationID == id && $0.readAt == nil && $0.senderID != ownerID }.count
    }
}

private struct FamilyChatView: View {
    @StateObject private var store = FamilyStore.shared
    @State private var draft = ""
    @State private var messagePendingDeletion: FamilyMessage?
    @FocusState private var composerFocused: Bool

    let title: String
    let conversationID: String
    let kind: FamilyConversationKind

    private var conversationMessages: [FamilyMessage] {
        store.messages.filter { $0.conversationID == conversationID }.sorted { $0.sentAt < $1.sentAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            localOnlyNotice
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if conversationMessages.isEmpty {
                            emptyConversation
                        }
                        ForEach(conversationMessages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: conversationMessages.count) { _, _ in
                    if let last = conversationMessages.last {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
        .background(FamiljenTheme.paper.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .confirmationDialog(
            "Radera meddelandet?",
            isPresented: Binding(
                get: { messagePendingDeletion != nil },
                set: { if !$0 { messagePendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Radera", role: .destructive) {
                guard let message = messagePendingDeletion else { return }
                store.deleteMessage(message.id)
                messagePendingDeletion = nil
            }
            Button("Avbryt", role: .cancel) {
                messagePendingDeletion = nil
            }
        } message: {
            Text("Meddelandet tas bort från den här enheten.")
        }
        .onAppear { store.markConversationRead(conversationID) }
    }

    private var localOnlyNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone")
            Text("Lokal testchatt – synkronisering mellan telefoner aktiveras senare")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(FamiljenTheme.champagneDeep)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(FamiljenTheme.sand.opacity(0.48))
    }

    private var emptyConversation: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 34))
                .foregroundStyle(FamiljenTheme.champagneDeep)
            Text("Börja samtalet")
                .font(.system(size: 19, weight: .semibold, design: .serif))
                .foregroundStyle(FamiljenTheme.ink)
            Text("Skriv det första meddelandet här.")
                .font(.system(size: 15))
                .foregroundStyle(FamiljenTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    private func messageBubble(_ message: FamilyMessage) -> some View {
        let isMine = message.senderID == store.members.first(where: { $0.role == .owner })?.id
        return HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 5) {
                if kind == .family {
                    Text(store.members.first(where: { $0.id == message.senderID })?.displayName ?? "Familjemedlem")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isMine ? .white.opacity(0.8) : FamiljenTheme.champagneDeep)
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 16))
                        .foregroundStyle(isMine ? .white : FamiljenTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(message.sentAt.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 11))
                    .foregroundStyle(isMine ? .white.opacity(0.72) : FamiljenTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isMine ? FamiljenTheme.navy : .white,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if !isMine {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(FamiljenTheme.sand.opacity(0.8), lineWidth: 1)
                }
            }
            if !isMine { Spacer(minLength: 48) }
        }
        .contextMenu {
            if isMine {
                Button(role: .destructive) {
                    messagePendingDeletion = message
                } label: {
                    Label("Radera meddelande", systemImage: "trash")
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField("Skriv ett meddelande …", text: $draft, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(FamiljenTheme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(FamiljenTheme.sand, lineWidth: 1))
                .focused($composerFocused)
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 43, height: 43)
                    .background(canSend ? FamiljenTheme.navy : FamiljenTheme.muted, in: Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("Skicka meddelande")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .top) { Rectangle().fill(FamiljenTheme.sand).frame(height: 1) }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if store.sendMessage(text, conversationID: conversationID, kind: kind) {
            draft = ""
        }
    }
}
