import MapKit
import SwiftUI

struct HealthRecordNotificationDetailView: View {
    @ObservedObject var store: FamilyStore
    let entry: HealthCenterEntry

    private var record: HealthRecord? {
        guard entry.id.hasPrefix("health-record-") else { return nil }
        let rawID = String(entry.id.dropFirst("health-record-".count))
        guard let id = UUID(uuidString: rawID) else { return nil }
        return store.healthRecords.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let record {
                        recordContent(record)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(entry.title, systemImage: entry.symbol)
                                .font(.system(size: 23, weight: .semibold, design: .serif))
                                .foregroundStyle(FamiljenTheme.ink)
                            Text(entry.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(FamiljenTheme.muted)
                            Label(entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute().locale(Locale(identifier: "sv_SE"))), systemImage: "calendar")
                                .font(.subheadline)
                            Text("Det här är en neutral sammanfattning. Öppna Hälsa för att hantera de registrerade uppgifterna.")
                                .font(.footnote)
                                .foregroundStyle(FamiljenTheme.muted)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .navigationTitle("Aktivitetsdetaljer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klart") { dismiss() }
                }
                if let record {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            HealthRecordEditorView(store: store, record: record)
                        } label: {
                            Text("Redigera")
                        }
                    }
                }
            }
        }
        .tint(FamiljenTheme.navy)
    }

    @Environment(\.dismiss) private var dismiss

    @ViewBuilder
    private func recordContent(_ record: HealthRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 13) {
                CategoryIcon(kind: record.type == .appointment ? .healthVisit : .event, size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.type.title.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.3)
                        .foregroundStyle(FamiljenTheme.champagneDeep)
                    Text(record.title)
                        .font(.system(size: 25, weight: .semibold, design: .serif))
                        .foregroundStyle(FamiljenTheme.ink)
                    Text("\(record.status.title) · \(memberName(record.memberID))")
                        .font(.subheadline)
                        .foregroundStyle(FamiljenTheme.muted)
                }
            }

            detailCard("Datum och tid", value: record.startsAt.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute().locale(Locale(identifier: "sv_SE"))), symbol: "calendar")
            if let provider = nonEmpty(record.provider) {
                detailCard("Vårdgivare", value: provider, symbol: "person")
            }
            if let clinic = nonEmpty(record.clinic) {
                detailCard("Mottagning", value: clinic, symbol: "cross.case")
            }
            if let location = nonEmpty(record.location) {
                detailCard("Plats", value: location, symbol: "mappin.and.ellipse")
            }
            if let address = nonEmpty(record.address) {
                detailCard("Adress", value: address, symbol: "location")
            }
            if let latitude = record.latitude, let longitude = record.longitude {
                mapSection(latitude: latitude, longitude: longitude, title: record.location ?? record.clinic ?? record.title)
            }
            if let notes = nonEmpty(record.notes) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Anteckningar", systemImage: "text.alignleft")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FamiljenTheme.champagneDeep)
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(FamiljenTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(15)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
            if !record.reminderOffsets.isEmpty {
                detailCard("Påminnelser", value: reminderSummary(record.reminderOffsets), symbol: "bell")
            }
        }
    }

    private func detailCard(_ title: String, value: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(FamiljenTheme.champagneDeep)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(FamiljenTheme.muted)
                Text(value).font(.body.weight(.medium)).foregroundStyle(FamiljenTheme.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func mapSection(latitude: Double, longitude: Double, title: String) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 850,
            longitudinalMeters: 850
        )
        return VStack(alignment: .leading, spacing: 10) {
            Label("Karta", systemImage: "map")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FamiljenTheme.champagneDeep)
            Map(initialPosition: .region(region)) {
                Marker(title, coordinate: coordinate)
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            Button {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                item.name = title
                item.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } label: {
                Label("Öppna vägbeskrivning i Apple Kartor", systemImage: "arrow.triangle.turn.up.right.diamond")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(FamiljenTheme.navy, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func memberName(_ id: UUID) -> String {
        store.members.first(where: { $0.id == id })?.displayName ?? "Familjemedlem"
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func reminderSummary(_ offsets: [Int]) -> String {
        offsets.sorted(by: >).map { offset in
            switch offset {
            case 0: return "Samma dag"
            case 86_400: return "En dag före"
            case 604_800: return "En vecka före"
            default: return "\(offset / 86_400) dagar före"
            }
        }.joined(separator: ", ")
    }
}
