import Foundation
import BPCore

/// Opt-in only. Sends weekly anonymized aggregates (see `ResearchAggregate` in BPCore) once per ISO week.
/// There is no user id, device id or timestamp finer than the week in the payload.
enum ResearchDonationService {
    /// Set when the EticaLabs intake endpoint is live. Nil means the toggle collects nothing and sends nothing.
    static let endpoint: URL? = nil

    static func donateIfDue(samples: [BPSample], settings: AppSettings) async {
        guard settings.researchDonationEnabled, let endpoint else { return }
        let cal = Calendar(identifier: .iso8601)
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let thisWeek = "\(comps.yearForWeekOfYear ?? 0)-\(comps.weekOfYear ?? 0)"
        guard settings.lastResearchDonationISOWeek != thisWeek else { return }

        // Only completed weeks, never the current one.
        let completed = samples.filter { s in
            let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: s.date)
            return "\(c.yearForWeekOfYear ?? 0)-\(c.weekOfYear ?? 0)" != thisWeek
        }
        let aggregates = ResearchAggregate.build(from: completed)
        guard !aggregates.isEmpty, let body = try? JSONEncoder().encode(aggregates) else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        if let (_, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
            settings.lastResearchDonationISOWeek = thisWeek
        }
    }
}
