import Foundation
import Combine

class MessageStore: ObservableObject {
    static let shared = MessageStore()

    @Published private(set) var messages: [MeshMessage] = []
    @Published private(set) var seenMessageIds: Set<UUID> = []

    private let messagesKey = "CapsuleMesh.Messages"
    private let maxMessages = MeshConstants.messageQueueSize

    private init() {
        loadMessages()
    }

    func addMessage(_ message: MeshMessage) -> Bool {
        // Deduplication check
        guard !seenMessageIds.contains(message.id) else {
            return false
        }

        seenMessageIds.insert(message.id)
        messages.insert(message, at: 0)

        // Trim if exceeds max
        if messages.count > maxMessages {
            messages = Array(messages.prefix(maxMessages))
        }

        saveMessages()
        return true
    }

    func hasSeenMessage(_ messageId: UUID) -> Bool {
        seenMessageIds.contains(messageId)
    }

    func clearMessages() {
        messages.removeAll()
        seenMessageIds.removeAll()
        saveMessages()
    }

    func messagesOfType(_ type: MessageType) -> [MeshMessage] {
        messages.filter { $0.type == type }
    }

    private func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(encoded, forKey: messagesKey)
        }
    }

    private func loadMessages() {
        if let data = UserDefaults.standard.data(forKey: messagesKey),
           let decoded = try? JSONDecoder().decode([MeshMessage].self, from: data) {
            messages = decoded
            seenMessageIds = Set(decoded.map { $0.id })
        }
    }
}
