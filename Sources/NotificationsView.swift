import SwiftUI

struct NotificationsView: View {
    @StateObject private var model = NotificationsViewModel()
    @State private var selectedHealthEntry: HealthCenterEntry?

    var body: some View {
        List {
            if !model.upcomingHealthEntries.isEmpty {
                Section("Kommande hälsa") {
                    ForEach(model.upcomingHealthEntries) { entry in
                        Button {
                            selectedHealthEntry = entry
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: entry.symbol)
                                    .font(.title3)
                                    .foregroundStyle(FamiljenTheme.navy)
                                    .frame(width: 34, height: 34)
                                    .background(FamiljenTheme.sand.opacity(0.55), in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(FamiljenTheme.ink)
                                    Text(entry.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(FamiljenTheme.muted)
                                    Text(entry.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                        .font(.caption2)
                                        .foregroundStyle(FamiljenTheme.muted)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(FamiljenTheme.muted)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Visa sammanfattning av hälsoärendet")
                    }
                }
            }

            if model.notifications.isEmpty && model.upcomingHealthEntries.isEmpty && !model.isLoading {
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
        .sheet(item: $selectedHealthEntry) { entry in
            HealthCenterEntryDetail(entry: entry)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
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


private struct HealthCenterEntryDetail: View {
    @Environment(\.dismiss) private var dismiss
    let entry: HealthCenterEntry

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: entry.symbol)
                        .font(.title2)
                        .foregroundStyle(FamiljenTheme.navy)
                        .frame(width: 48, height: 48)
                        .background(FamiljenTheme.sand.opacity(0.55), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.headline)
                            .foregroundStyle(FamiljenTheme.ink)
                        Text(entry.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                }
                Divider().overlay(FamiljenTheme.sand)
                Label(entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute()), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(FamiljenTheme.ink)
                Text("Det här är en delad sammanfattning. Öppna Hälsa för att se och hantera registrerade uppgifter.")
                    .font(.footnote)
                    .foregroundStyle(FamiljenTheme.muted)
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .navigationTitle("Hälsoärende")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klart") { dismiss() }
                }
            }
        }
        .tint(FamiljenTheme.navy)
    }
}
