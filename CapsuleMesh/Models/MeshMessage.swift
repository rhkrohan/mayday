import Foundation
import CoreLocation

struct MeshMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let type: MessageType
    let data: MessageData
    let senderId: String
    let senderName: String
    let timestamp: Date
    var hops: [String]
    var hopCount: Int
    var targetDeviceId: String?  // For direct messages
    var senderRole: UserRole?    // Role of the sender

    init(
        type: MessageType,
        data: MessageData,
        senderId: String,
        senderName: String,
        targetDeviceId: String? = nil,
        senderRole: UserRole? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.data = data
        self.senderId = senderId
        self.senderName = senderName
        self.timestamp = Date()
        self.hops = [senderId]
        self.hopCount = 0
        self.targetDeviceId = targetDeviceId
        self.senderRole = senderRole
    }

    mutating func addHop(deviceId: String) {
        hops.append(deviceId)
        hopCount += 1
    }

    static func == (lhs: MeshMessage, rhs: MeshMessage) -> Bool {
        lhs.id == rhs.id
    }

    /// The panic ID this message is related to (for grouping)
    var relatedPanicId: String? {
        data.panicId ?? data.confirmedPanicId ?? data.respondingToPanicId
    }

    /// GPS coordinate if available
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = data.latitude, let lon = data.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct MessageData: Codable {
    // GPS Coordinates
    var latitude: Double? = nil
    var longitude: Double? = nil

    // SOS / Panic
    var location: String? = nil
    var description: String? = nil
    var urgency: String? = nil
    var batteryLevel: Int? = nil

    // Panic-specific
    var emergencyType: String? = nil        // "robbery", "assault", "medical", "suspicious", "other"
    var severityScore: Int? = nil           // 1-10 AI-assigned severity
    var audioTranscript: String? = nil      // Speech-to-text result
    var audioBase64: String? = nil          // Base64-encoded audio for server-side transcription
    var panicId: String? = nil              // Links witness confirmations to this panic

    // Incident Report
    var incidentType: String? = nil         // "robbery", "assault", "carBreakIn", "harassment", "suspicious", "medical", "other"
    var numberOfPeople: Int? = nil
    var weaponsMentioned: Bool? = nil
    var suspectDescription: String? = nil

    // Witness
    var confirmedPanicId: String? = nil     // The panic alert ID being confirmed
    var witnessCount: Int? = nil            // Running count of confirmations
    var witnessNote: String? = nil          // Optional note from witness

    // Security Personnel
    var isOnDuty: Bool? = nil
    var securityRole: String? = nil         // "security_guard", "campus_police", "off_duty_emt", etc.
    var respondingToPanicId: String? = nil  // Which panic they're responding to
    var estimatedArrival: String? = nil     // ETA to incident
    var skills: [String]? = nil             // ["cpr", "first_aid", "armed", "emt"]

    // Triage
    var patientName: String? = nil
    var age: Int? = nil
    var condition: String? = nil
    var injuries: String? = nil
    var conscious: Bool? = nil
    var breathing: Bool? = nil

    // Shelter / Safe Zone
    var shelterName: String? = nil
    var capacity: Int? = nil
    var currentOccupancy: Int? = nil
    var supplies: [String]? = nil
    var acceptingMore: Bool? = nil

    // Missing Person
    var personName: String? = nil
    var lastSeenLocation: String? = nil
    var lastSeenTime: String? = nil
    var physicalDescription: String? = nil
    var contactInfo: String? = nil
    var photoBase64: String? = nil

    // Broadcast
    var title: String? = nil
    var message: String? = nil
    var priority: String? = nil

    // Direct Message
    var content: String? = nil

    // Ping/Pong
    var originalSenderId: String? = nil
    var originalTimestamp: Date? = nil

    // Discovery
    var connectedPeers: [String]? = nil
    var requestId: String? = nil

    // Delivery Receipt
    var originalMessageId: String? = nil
    var deliveredAt: Date? = nil

    // Gateway Status
    var isGateway: Bool? = nil
    var gatewayDeviceId: String? = nil
    var gatewayDeviceName: String? = nil
    var syncedCount: Int? = nil
}
