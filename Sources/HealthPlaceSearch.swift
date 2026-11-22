import MapKit
import SwiftUI

@MainActor
private final class HealthPlaceSearchModel: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published private(set) var completions: [MKLocalSearchCompletion] = []
    @Published var isResolving = false
    @Published var errorMessage: String?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            completions = []
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = trimmed
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = Array(completer.results.prefix(6))
        errorMessage = nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
        errorMessage = "Platsförslag kunde inte hämtas. Du kan fortfarande ange adressen manuellt."
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        isResolving = true
        defer { isResolving = false }
        do {
            let request = MKLocalSearch.Request(completion: completion)
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.first
        } catch {
            errorMessage = "Platsen kunde inte hämtas. Prova ett annat förslag eller skriv adressen manuellt."
            return nil
        }
    }

    func clearResults() {
        completions = []
    }
}

struct HealthPlaceSearchField: View {
    @Binding var location: String
    @Binding var address: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    @StateObject private var model = HealthPlaceSearchModel()
    @FocusState private var isFocused: Bool
    @State private var isApplyingSelection = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Sök mottagning eller plats", text: $location)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isFocused)
                .onChange(of: location) { _, value in
                    // Typing a new place invalidates the old pin; choosing a result does not.
                    if !isApplyingSelection {
                        address = ""
                        latitude = nil
                        longitude = nil
                    }
                    model.update(query: value)
                }

            if !model.completions.isEmpty && isFocused {
                VStack(spacing: 0) {
                    ForEach(Array(model.completions.enumerated()), id: \.offset) { element in
                        let completion = element.element
                        Button {
                            Task {
                                guard let item = await model.resolve(completion) else { return }
                                isApplyingSelection = true
                                location = item.name ?? completion.title
                                address = Self.formattedAddress(for: item.placemark)
                                latitude = item.placemark.coordinate.latitude
                                longitude = item.placemark.coordinate.longitude
                                model.clearResults()
                                isFocused = false
                                Task { @MainActor in
                                    await Task.yield()
                                    isApplyingSelection = false
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(completion.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isResolving)
                        if element.offset < model.completions.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 9)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }

            if model.isResolving {
                ProgressView("Hämtar plats …")
                    .font(.caption)
            }
            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if latitude != nil && longitude != nil {
                Label("Kartposition sparas för den valda platsen", systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: address) { _, _ in
            // Manual address edits intentionally keep the selected coordinates;
            // the user may be correcting formatting without changing the place.
        }
    }

    private static func formattedAddress(for placemark: MKPlacemark) -> String {
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        let locality = [placemark.postalCode, placemark.locality]
            .compactMap { $0 }
            .joined(separator: " ")
        let parts = [street, locality, placemark.country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }
}
