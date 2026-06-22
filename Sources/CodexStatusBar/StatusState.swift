import Foundation

enum CodexStatus: String, Codable, CaseIterable {
    case idle
    case thinking
    case runningCommand = "running_command"
    case editing
    case reading
    case usingTool = "using_tool"
    case waitingPermission = "waiting_permission"
    case complete
    case error

    var defaultLabel: String {
        switch self {
        case .idle: return "Idle"
        case .thinking: return "Thinking"
        case .runningCommand: return "Running command"
        case .editing: return "Editing files"
        case .reading: return "Reading files"
        case .usingTool: return "Using tool"
        case .waitingPermission: return "Waiting for permission"
        case .complete: return "Turn complete"
        case .error: return "Error"
        }
    }

    var isActive: Bool {
        [.thinking, .runningCommand, .editing, .reading, .usingTool].contains(self)
    }
}

struct StatusState: Codable, Equatable {
    var version: Int = 1
    var status: CodexStatus = .idle
    var label: String = "Idle"
    var sessionID: String?
    var turnID: String?
    var cwd: String?
    var toolName: String?
    var startedAt: Date?
    var updatedAt: Date = Date()
    var completedAt: Date?
    var lastMessage: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case version, status, label, cwd, error
        case sessionID = "session_id"
        case turnID = "turn_id"
        case toolName = "tool_name"
        case startedAt = "started_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
        case lastMessage = "last_message"
    }

    static let idle = StatusState()

    var displayLabel: String { label.isEmpty ? status.defaultLabel : label }
    var isStale: Bool { Date().timeIntervalSince(updatedAt) > 30 * 60 }
}
