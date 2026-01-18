import Foundation
import MultipeerConnectivity

struct Peer: Identifiable, Hashable {
    let id: MCPeerID
    var displayName: String { id.displayName }
    var isConnected: Bool
    var lastSeen: Date
    var hopDistance: Int
    var role: UserRole
    var dutyStatus: DutyStatus?
    var skills: [UserSkill]
    var organization: Organization?
    var securityOrg: SecurityOrganization?

    init(peerID: MCPeerID, isConnected: Bool = false, hopDistance: Int = 1, role: UserRole = .civilian, dutyStatus: DutyStatus? = nil, skills: [UserSkill] = [], organization: Organization? = nil, securityOrg: SecurityOrganization? = nil) {
        self.id = peerID
        self.isConnected = isConnected
        self.lastSeen = Date()
        self.hopDistance = hopDistance
        self.role = role
        self.dutyStatus = dutyStatus
        self.skills = skills
        self.organization = organization
        self.securityOrg = securityOrg
    }

    /// Whether this peer is an on-duty security guard
    var isOnDutySecurity: Bool {
        role == .security && dutyStatus == .onDuty
    }

    /// Whether this peer is actively responding to an incident
    var isResponding: Bool {
        dutyStatus == .responding
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Peer, rhs: Peer) -> Bool {
        lhs.id == rhs.id
    }
}
