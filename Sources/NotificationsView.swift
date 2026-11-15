import SwiftUI

struct NotificationsView: View {
    @StateObject private var model = NotificationsViewModel()

    var body: some View {
        List {
            if model.notifications.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "Inga notiser ännu",
                    systemImage: "bell",
                    description: Text("Här visas aviseringar som skapats på den här enheten.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(model.notifications) { notification in
                    Button {
                        Task { await model.markRead(notification) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: symbol(for: notification.eventType))
                                .font(.title3)
                                .foregroundStyle(FamiljenTheme.navy)
                                .frame(width: 34, height: 34)
                                .background(FamiljenTheme.sand.opacity(0.55), in: Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(notification.title)
                                        .font(.subheadline.weight(notification.isRead ? .medium : .bold))
                                        .foregroundStyle(FamiljenTheme.ink)
                                    Spacer()
                                    if !notification.isRead {
                                        Circle().fill(FamiljenTheme.champagne).frame(width: 8, height: 8)
                                    }
                                }
                                Text(notification.body)
                                    .font(.subheadline)
                                    .foregroundStyle(FamiljenTheme.muted)
                                Text(notification.createdAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                    .font(.caption2)
                                    .foregroundStyle(FamiljenTheme.muted)
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = model.errorMessage {
                Section { Text(error).font(.footnote).foregroundStyle(.red) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(FamiljenTheme.paper)
        .navigationTitle("Notiser")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if model.isLoading && model.notifications.isEmpty {
                ProgressView("Hämtar notiser …")
            }
        }
        .refreshable { await model.load() }
        .task { await model.startListening() }
        .onDisappear { Task { await model.stopListening() } }
    }

    private func symbol(for type: String) -> String {
        switch type {
        case "calendar_item_added", "calendar_item_updated", "calendar_item_deleted": return "calendar"
        case "shopping_item_added", "shopping_item_checked", "shopping_item_deleted": return "basket"
        case "member_joined": return "person.2"
        default: return "bell"
        }
    }
}
