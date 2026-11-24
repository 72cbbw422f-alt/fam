import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import ImageIO

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
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImageType: String?
    @State private var attachmentError: String?
    @State private var messagePendingDeletion: FamilyMessage?
    @State private var viewingImageData: Data?
    @State private var isImageViewerPresented = false
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
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadSelectedPhoto(item) }
        }
        .fullScreenCover(isPresented: $isImageViewerPresented, onDismiss: { viewingImageData = nil }) {
            if let viewingImageData, let image = UIImage(data: viewingImageData) {
                FamilyMessageImageViewer(image: image)
            }
        }
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
                ForEach(message.attachments ?? []) { attachment in
                    Button {
                        guard let imageData = try? FamilyMessageAttachmentStore.applicationStore().data(for: attachment) else {
                            return
                        }
                        viewingImageData = imageData
                        isImageViewerPresented = true
                    } label: {
                        FamilyMessageThumbnail(attachment: attachment)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Visa bild i helskärm")
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
        VStack(alignment: .leading, spacing: 8) {
            if let selectedImageData, let image = UIImage(data: selectedImageData) {
                HStack(spacing: 10) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("Bild bifogas")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FamiljenTheme.ink)
                    Spacer()
                    Button {
                        self.selectedImageData = nil
                        selectedImageType = nil
                        selectedPhoto = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                    .accessibilityLabel("Ta bort vald bild")
                }
                .padding(.horizontal, 13)
            }
            if let attachmentError {
                Text(attachmentError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 13)
            }
            HStack(alignment: .bottom, spacing: 9) {
                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "photo")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(FamiljenTheme.navy)
                        .frame(width: 42, height: 43)
                }
                .accessibilityLabel("Välj bild")
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
        }
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .top) { Rectangle().fill(FamiljenTheme.sand).frame(height: 1) }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil
    }

    @MainActor
    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        attachmentError = nil
        guard let type = item.supportedContentTypes.first(where: {
            ["public.jpeg", "public.png", "public.heic", "public.heif"].contains($0.identifier)
        }) else {
            selectedImageData = nil
            selectedImageType = nil
            attachmentError = "Bildformatet stöds inte."
            return
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw FamilyMessageAttachmentStoreError.emptyFile
            }
            guard data.count <= FamilyMessageAttachmentStore.maximumFileSize else {
                throw FamilyMessageAttachmentStoreError.fileTooLarge
            }
            selectedImageData = data
            selectedImageType = type.identifier
        } catch {
            selectedImageData = nil
            selectedImageType = nil
            attachmentError = "Bilden kunde inte läsas in. Försök igen."
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedImageData != nil else { return }
        var attachment: FamilyMessageAttachment?
        if let selectedImageData, let selectedImageType {
            do {
                attachment = try FamilyMessageAttachmentStore.applicationStore().save(
                    data: selectedImageData,
                    filename: "Bild",
                    contentType: selectedImageType,
                    messageID: UUID()
                )
            } catch {
                attachmentError = "Bilden kunde inte sparas på enheten."
                return
            }
        }
        if store.sendMessage(text, conversationID: conversationID, kind: kind, attachment: attachment) {
            draft = ""
            selectedImageData = nil
            selectedImageType = nil
            selectedPhoto = nil
            attachmentError = nil
        } else {
            attachmentError = "Meddelandet kunde inte sparas. Försök igen."
        }
    }
}


private struct FamilyMessageImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .accessibilityLabel("Stäng bildvisning")
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .statusBarHidden()
    }
}


/// Decodes a bounded thumbnail instead of allocating a full-resolution UIImage
/// every time SwiftUI reevaluates a chat bubble.
private struct FamilyMessageThumbnail: View {
    private static let cache = NSCache<NSString, UIImage>()
    let attachment: FamilyMessageAttachment

    var body: some View {
        Group {
            if let image = Self.thumbnail(for: attachment) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(FamiljenTheme.sand.opacity(0.55))
                    .frame(width: 160, height: 100)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(FamiljenTheme.muted)
                    }
            }
        }
    }

    private static func thumbnail(for attachment: FamilyMessageAttachment) -> UIImage? {
        let key = attachment.relativePath as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard attachment.isValid,
              let directory = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
              ).first else { return nil }
        let root = directory.standardizedFileURL
        let url = root.appendingPathComponent(attachment.relativePath).standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(rootPath),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 640,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ] as CFDictionary
              ) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}
