import Foundation
import Vision

struct AppointmentImageReadResult {
    let text: String
    let title: String?
    let date: Date?
    let isHealthVisit: Bool
    let member: FamilyMember?
}

enum AppointmentImageReader {
    static func read(data: Data, familyMembers: [FamilyMember]) async throws -> AppointmentImageReadResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["sv-SE", "en-US"]
        let handler = VNImageRequestHandler(data: data)
        try handler.perform([request])

        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReaderError.noText
        }

        let lower = text.lowercased()
        let healthTerms = ["läkare", "läkar", "tandläk", "folktandvård", "vårdcentral", "sjukhus", "mottagning", "bvc", "specialist"]
        let isHealthVisit = healthTerms.contains { lower.contains($0) }
        let title: String?
        if lower.contains("tandläk") || lower.contains("folktandvård") {
            title = "Tandläkare"
        } else if lower.contains("vårdcentral") || lower.contains("läkare") || lower.contains("läkarbesök") {
            title = "Läkarbesök"
        } else if lower.contains("bvc") {
            title = "BVC"
        } else if lower.contains("sjukhus") || lower.contains("mottagning") {
            title = "Vårdbesök"
        } else {
            title = nil
        }

        let member = familyMembers.first {
            lower.range(of: $0.displayName.lowercased(), options: .caseInsensitive) != nil
        }
        return AppointmentImageReadResult(
            text: text,
            title: title,
            date: parseDate(in: text),
            isHealthVisit: isHealthVisit,
            member: member
        )
    }

    private static func parseDate(in text: String) -> Date? {
        let patterns = [
            #"(?<!\\d)(\\d{1,2})[./-](\\d{1,2})[./-](\\d{4})(?!\\d)"#,
            #"(?<!\\d)(\\d{4})-(\\d{1,2})-(\\d{1,2})(?!\\d)"#
        ]
        var dateComponents: DateComponents?
        for (index, pattern) in patterns.enumerated() {
            guard let match = firstMatch(pattern, in: text), match.numberOfRanges == 4,
                  let a = Int(capture(match, 1, in: text)),
                  let b = Int(capture(match, 2, in: text)),
                  let c = Int(capture(match, 3, in: text)) else { continue }
            if index == 0 {
                dateComponents = DateComponents(year: c, month: b, day: a)
            } else {
                dateComponents = DateComponents(year: a, month: b, day: c)
            }
            break
        }

        if dateComponents == nil {
            let monthNames = "(januari|februari|mars|april|maj|juni|juli|augusti|september|oktober|november|december)"
            let pattern = #"(?i)(\\d{1,2})\\s+"# + monthNames + #"(?:\\s+(\\d{4}))?"#
            if let match = firstMatch(pattern, in: text),
               let day = Int(capture(match, 1, in: text)),
               let monthName = capture(match, 2, in: text).lowercased().nilIfEmpty {
                let months = ["januari": 1, "februari": 2, "mars": 3, "april": 4, "maj": 5, "juni": 6,
                              "juli": 7, "augusti": 8, "september": 9, "oktober": 10, "november": 11, "december": 12]
                let year = Int(capture(match, 3, in: text)) ?? Calendar.current.component(.year, from: .now)
                if let month = months[monthName] { dateComponents = DateComponents(year: year, month: month, day: day) }
            }
        }
        // Only suggest a date when an explicit clock time was also found.
        // Never invent a default time for a medical appointment.
        guard var components = dateComponents,
              let timeMatch = firstMatch(#"(?<!\d)([01]?\d|2[0-3])[:.]([0-5]\d)(?!\d)"#, in: text) else {
            return nil
        }
        components.hour = Int(capture(timeMatch, 1, in: text))
        components.minute = Int(capture(timeMatch, 2, in: text))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let date = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == components.year, check.month == components.month, check.day == components.day else { return nil }
        return date
    }

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func capture(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String {
        guard index < match.numberOfRanges, let range = Range(match.range(at: index), in: text) else { return "" }
        return String(text[range])
    }

    private enum ReaderError: Error {
        case noText
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
