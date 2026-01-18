import Foundation

enum MessageType: String, Codable, CaseIterable {
    // Emergency & Safety
    case panic = "panic"                        // Panic button alert (replaces SOS)
    case incidentReport = "incident-report"     // Detailed incident report (robbery, assault, etc.)
    case witnessRequest = "witness-request"      // Prompt nearby users to confirm an incident
    case witnessConfirm = "witness-confirm"      // Confirmation from a witness

    // Security Personnel
    case securityStatus = "security-status"      // Guard broadcasts duty status & location
    case securityResponse = "security-response"  // Guard claims/responds to an incident

    // Legacy / General
    case sos = "sos"                            // Legacy SOS (kept for compatibility)
    case triage = "triage"
    case shelter = "shelter"
    case missingPerson = "missing-person"
    case broadcast = "broadcast"
    case ping = "ping"
    case pong = "pong"
    case direct = "direct"
    case discovery = "discovery"
    case discoveryReply = "discovery-reply"
    case deliveryReceipt = "delivery-receipt"
    case gatewayStatus = "gateway-status"

    var displayName: String {
        switch self {
        case .panic: return "Panic Alert"
        case .incidentReport: return "Incident Report"
        case .witnessRequest: return "Witness Request"
        case .witnessConfirm: return "Witness Confirmed"
        case .securityStatus: return "Security Status"
        case .securityResponse: return "Security Responding"
        case .sos: return "SOS Emergency"
        case .triage: return "Medical Triage"
        case .shelter: return "Safe Zone"
        case .missingPerson: return "Missing Person"
        case .broadcast: return "Broadcast"
        case .ping: return "Ping"
        case .pong: return "Pong"
        case .direct: return "Direct Message"
        case .discovery: return "Discovery"
        case .discoveryReply: return "Discovery Reply"
        case .deliveryReceipt: return "Delivery Receipt"
        case .gatewayStatus: return "Gateway Status"
        }
    }

    var icon: String {
        switch self {
        case .panic: return "light.beacon.max.fill"
        case .incidentReport: return "exclamationmark.shield.fill"
        case .witnessRequest: return "eye.fill"
        case .witnessConfirm: return "checkmark.shield.fill"
        case .securityStatus: return "shield.checkered"
        case .securityResponse: return "figure.run"
        case .sos: return "exclamationmark.triangle.fill"
        case .triage: return "cross.case.fill"
        case .shelter: return "shield.lefthalf.filled"
        case .missingPerson: return "person.fill.questionmark"
        case .broadcast: return "megaphone.fill"
        case .ping, .pong: return "wave.3.right"
        case .direct: return "envelope.fill"
        case .discovery, .discoveryReply: return "network"
        case .deliveryReceipt: return "checkmark.circle.fill"
        case .gatewayStatus: return "wifi"
        }
    }

    /// Whether this message type is user-facing (shown in feeds)
    var isUserFacing: Bool {
        switch self {
        case .panic, .incidentReport, .witnessConfirm, .securityResponse,
             .sos, .triage, .shelter, .missingPerson, .broadcast:
            return true
        default:
            return false
        }
    }

    /// Whether this is a safety-critical alert
    var isCritical: Bool {
        switch self {
        case .panic, .sos, .incidentReport: return true
        default: return false
        }
    }
}
