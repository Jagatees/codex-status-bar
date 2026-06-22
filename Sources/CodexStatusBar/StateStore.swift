import Foundation

final class StateStore {
    let stateURL: URL
    private let decoder: JSONDecoder
    private var lastModificationDate = Date.distantPast
    private(set) var lastReadError: String?

    init(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        stateURL = homeURL.appendingPathComponent(".codex/statusbar/state.json")
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
        }
    }

    func readIfChanged() -> StatusState? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: stateURL.path),
              let modified = attributes[.modificationDate] as? Date else {
            lastReadError = nil
            return lastModificationDate == .distantPast ? .idle : nil
        }
        guard modified != lastModificationDate else { return nil }
        lastModificationDate = modified

        do {
            let data = try Data(contentsOf: stateURL)
            let state = try decoder.decode(StatusState.self, from: data)
            lastReadError = nil
            return state
        } catch {
            lastReadError = "Invalid state file: \(error.localizedDescription)"
            var state = StatusState.idle
            state.status = .error
            state.label = "State error"
            state.error = lastReadError
            return state
        }
    }
}
