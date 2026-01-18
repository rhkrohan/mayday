import Foundation
import CoreLocation
import Combine

// MARK: - Simulated Peer

struct SimulatedPeer: Identifiable, Equatable {
    let id: String
    var name: String
    var location: CLLocationCoordinate2D
    var batteryLevel: Int
    var isGateway: Bool
    var hops: Int
    var isMoving: Bool
    var movementSpeed: Double
    var movementDirection: Double
    var role: UserRole
    var dutyStatus: DutyStatus?
    var skills: [UserSkill]

    init(
        id: String,
        name: String,
        location: CLLocationCoordinate2D,
        batteryLevel: Int,
        isGateway: Bool,
        hops: Int,
        isMoving: Bool,
        movementSpeed: Double,
        movementDirection: Double,
        role: UserRole = .civilian,
        dutyStatus: DutyStatus? = nil,
        skills: [UserSkill] = []
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.batteryLevel = batteryLevel
        self.isGateway = isGateway
        self.hops = hops
        self.isMoving = isMoving
        self.movementSpeed = movementSpeed
        self.movementDirection = movementDirection
        self.role = role
        self.dutyStatus = dutyStatus
        self.skills = skills
    }

    static func == (lhs: SimulatedPeer, rhs: SimulatedPeer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Simulation Service

class SimulationService: ObservableObject {
    static let shared = SimulationService()

    @Published private(set) var isRunning = false
    @Published private(set) var simulatedPeers: [SimulatedPeer] = []
    @Published private(set) var simulatedMessages: [MeshMessage] = []

    private var updateTimer: Timer?
    private var messageTimer: Timer?
    private var baseLocation: CLLocationCoordinate2D?

    var peerCount: Int = 8
    var spreadRadius: Double = 0.01
    var updateInterval: TimeInterval = 2.0
    var messageInterval: TimeInterval = 10.0

    // Philly-themed names for security
    private let securityNames = [
        "Officer Davis", "Officer Martinez", "Guard Thompson",
        "Officer Patel", "Guard Wilson", "Officer Kim"
    ]

    private let civilianNames = [
        "Alex", "Jordan", "Sam", "Riley", "Casey",
        "Morgan", "Quinn", "Avery", "Blake", "Drew",
        "Ellis", "Finley", "Gray", "Harper", "Indigo",
        "Jules", "Kai", "Lane", "Marley", "Nico"
    ]

    // Philadelphia locations
    private let scenarioLocations: [(name: String, coord: CLLocationCoordinate2D)] = [
        ("Drexel University", CLLocationCoordinate2D(latitude: 39.9566, longitude: -75.1899)),
        ("UPenn Campus", CLLocationCoordinate2D(latitude: 39.9522, longitude: -75.1932)),
        ("Temple University", CLLocationCoordinate2D(latitude: 39.9812, longitude: -75.1553)),
        ("SEPTA City Hall", CLLocationCoordinate2D(latitude: 39.9526, longitude: -75.1635)),
        ("SEPTA 30th St", CLLocationCoordinate2D(latitude: 39.9557, longitude: -75.1822)),
        ("Rittenhouse Square", CLLocationCoordinate2D(latitude: 39.9496, longitude: -75.1718)),
        ("Philadelphia Museum", CLLocationCoordinate2D(latitude: 39.9656, longitude: -75.1810)),
        ("South Street", CLLocationCoordinate2D(latitude: 39.9429, longitude: -75.1499))
    ]

    private init() {}

    // MARK: - Public Methods

    func start(around location: CLLocationCoordinate2D? = nil, scenario: SimulationScenario = .normal) {
        guard !isRunning else { return }

        // Default to Drexel University area
        baseLocation = location ?? CLLocationCoordinate2D(latitude: 39.9566, longitude: -75.1899)

        isRunning = true
        generatePeers(scenario: scenario)
        startUpdateTimer()
        startMessageTimer(scenario: scenario)

        print("Simulation started with \(simulatedPeers.count) peers around \(baseLocation!)")
    }

    func stop() {
        isRunning = false
        updateTimer?.invalidate()
        updateTimer = nil
        messageTimer?.invalidate()
        messageTimer = nil
        simulatedPeers.removeAll()
        simulatedMessages.removeAll()
        print("Simulation stopped")
    }

    func setScenario(_ scenario: SimulationScenario) {
        let wasRunning = isRunning
        let location = baseLocation

        if wasRunning { stop() }
        if wasRunning { start(around: location, scenario: scenario) }
    }

    // MARK: - Peer Generation

    private func generatePeers(scenario: SimulationScenario) {
        simulatedPeers.removeAll()
        guard let base = baseLocation else { return }

        let count: Int
        let gatewayCount: Int
        let securityCount: Int

        switch scenario {
        case .normal:
            count = 10; gatewayCount = 2; securityCount = 2
        case .disaster:
            count = 15; gatewayCount = 1; securityCount = 3
        case .dense:
            count = 25; gatewayCount = 5; securityCount = 5
        case .sparse:
            count = 4; gatewayCount = 1; securityCount = 1
        case .noInternet:
            count = 10; gatewayCount = 0; securityCount = 2
        case .campusSafety:
            count = 20; gatewayCount = 3; securityCount = 6
        case .septaUnderground:
            count = 15; gatewayCount = 1; securityCount = 4
        }

        for i in 0..<count {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = Double.random(in: 0.001...spreadRadius)
            let lat = base.latitude + (distance * cos(angle))
            let lng = base.longitude + (distance * sin(angle))

            let isSecurity = i < securityCount
            let name: String
            let role: UserRole
            let dutyStatus: DutyStatus?
            var skills: [UserSkill] = []

            if isSecurity {
                name = securityNames[i % securityNames.count]
                role = .security
                dutyStatus = .onDuty
                skills = [.security, .firstAid]
                if Bool.random() { skills.append(.cpr) }
            } else {
                name = civilianNames[(i - securityCount) % civilianNames.count]
                role = .civilian
                dutyStatus = nil
                // Some civilians have skills
                if Double.random(in: 0...1) < 0.15 {
                    skills = [.cpr]
                }
            }

            let peer = SimulatedPeer(
                id: "SIM-\(UUID().uuidString.prefix(8))",
                name: name,
                location: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                batteryLevel: Int.random(in: 15...100),
                isGateway: i >= securityCount && (i - securityCount) < gatewayCount,
                hops: min(i / 3 + 1, 5),
                isMoving: isSecurity ? true : Bool.random(), // Security always patrolling
                movementSpeed: isSecurity ? Double.random(in: 0.0002...0.0004) : Double.random(in: 0.0001...0.0005),
                movementDirection: Double.random(in: 0...(2 * .pi)),
                role: role,
                dutyStatus: dutyStatus,
                skills: skills
            )

            simulatedPeers.append(peer)
        }
    }

    // MARK: - Movement Updates

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updatePeerPositions()
        }
    }

    private func updatePeerPositions() {
        guard let base = baseLocation else { return }

        for i in 0..<simulatedPeers.count {
            guard simulatedPeers[i].isMoving else { continue }

            var peer = simulatedPeers[i]

            let newLat = peer.location.latitude + (peer.movementSpeed * cos(peer.movementDirection))
            let newLng = peer.location.longitude + (peer.movementSpeed * sin(peer.movementDirection))

            let distFromBase = sqrt(pow(newLat - base.latitude, 2) + pow(newLng - base.longitude, 2))
            if distFromBase > spreadRadius {
                peer.movementDirection = atan2(base.longitude - newLng, base.latitude - newLat)
            } else {
                if Double.random(in: 0...1) < 0.1 {
                    peer.movementDirection += Double.random(in: -0.5...0.5)
                }
            }

            peer.location = CLLocationCoordinate2D(latitude: newLat, longitude: newLng)

            if Double.random(in: 0...1) < 0.05 && peer.batteryLevel > 1 {
                peer.batteryLevel -= 1
            }

            simulatedPeers[i] = peer
        }

        if Double.random(in: 0...1) < 0.02 {
            let idx = Int.random(in: 0..<simulatedPeers.count)
            // Don't stop security from moving
            if simulatedPeers[idx].role != .security {
                simulatedPeers[idx].isMoving.toggle()
            }
        }
    }

    // MARK: - Message Generation

    private func startMessageTimer(scenario: SimulationScenario) {
        let interval: TimeInterval
        switch scenario {
        case .disaster: interval = 5.0
        case .dense, .campusSafety: interval = 3.0
        case .septaUnderground: interval = 6.0
        default: interval = messageInterval
        }

        messageTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.generateRandomMessage(scenario: scenario)
        }
    }

    private func generateRandomMessage(scenario: SimulationScenario) {
        guard !simulatedPeers.isEmpty else { return }

        // Pick civilian senders for panic/incident, security for responses
        let civilians = simulatedPeers.filter { $0.role == .civilian }
        let security = simulatedPeers.filter { $0.role == .security }

        let messageType: MessageType
        let sender: SimulatedPeer

        switch scenario {
        case .campusSafety:
            let roll = Double.random(in: 0...1)
            if roll < 0.25 {
                messageType = .panic
                sender = civilians.randomElement() ?? simulatedPeers.randomElement()!
            } else if roll < 0.4 {
                messageType = .incidentReport
                sender = civilians.randomElement() ?? simulatedPeers.randomElement()!
            } else if roll < 0.55 {
                messageType = .witnessConfirm
                sender = civilians.randomElement() ?? simulatedPeers.randomElement()!
            } else if roll < 0.7 {
                messageType = .securityResponse
                sender = security.randomElement() ?? simulatedPeers.randomElement()!
            } else {
                messageType = .broadcast
                sender = simulatedPeers.randomElement()!
            }

        case .septaUnderground:
            let roll = Double.random(in: 0...1)
            if roll < 0.3 {
                messageType = .panic
                sender = civilians.randomElement() ?? simulatedPeers.randomElement()!
            } else if roll < 0.5 {
                messageType = .incidentReport
                sender = civilians.randomElement() ?? simulatedPeers.randomElement()!
            } else if roll < 0.65 {
                messageType = .securityResponse
                sender = security.randomElement() ?? simulatedPeers.randomElement()!
            } else {
                messageType = .broadcast
                sender = simulatedPeers.randomElement()!
            }

        case .disaster:
            let roll = Double.random(in: 0...1)
            if roll < 0.3 { messageType = .panic }
            else if roll < 0.5 { messageType = .triage }
            else if roll < 0.7 { messageType = .incidentReport }
            else { messageType = .broadcast }
            sender = simulatedPeers.randomElement()!

        case .noInternet:
            messageType = Double.random(in: 0...1) < 0.4 ? .panic : .broadcast
            sender = simulatedPeers.randomElement()!

        default:
            let types: [MessageType] = [.broadcast, .panic, .incidentReport, .witnessConfirm]
            messageType = types.randomElement()!
            sender = simulatedPeers.randomElement()!
        }

        let message = createMessage(type: messageType, from: sender)
        simulatedMessages.insert(message, at: 0)

        if simulatedMessages.count > 50 {
            simulatedMessages = Array(simulatedMessages.prefix(50))
        }
    }

    private func createMessage(type: MessageType, from sender: SimulatedPeer) -> MeshMessage {
        var data = MessageData()
        data.latitude = sender.location.latitude
        data.longitude = sender.location.longitude

        switch type {
        case .panic:
            let emergencies: [(type: String, desc: String)] = [
                ("robbery", "Being robbed near the parking garage"),
                ("assault", "Someone is being attacked on the street"),
                ("suspicious", "Suspicious person following me"),
                ("harassment", "Being harassed at the bus stop"),
                ("medical", "Person collapsed on the sidewalk"),
                ("theft", "Someone just stole my bag")
            ]
            let emergency = emergencies.randomElement()!
            data.emergencyType = emergency.type
            data.description = emergency.desc
            data.batteryLevel = sender.batteryLevel
            data.panicId = UUID().uuidString
            data.severityScore = IncidentType(rawValue: emergency.type)?.baseSeverity ?? 5
            data.urgency = ["medium", "high", "critical"].randomElement()!

        case .incidentReport:
            let incidents: [(type: String, desc: String, people: Int?, weapon: Bool)] = [
                ("robbery", "Robbery in progress at Market St", 2, false),
                ("car_break_in", "Multiple car windows smashed on Chestnut", nil, false),
                ("assault", "Fight outside the bar", 3, false),
                ("harassment", "Group harassing students near campus", 4, false),
                ("suspicious_activity", "Person looking into car windows", 1, false),
                ("theft", "Shoplifting in progress at CVS", 1, false)
            ]
            let incident = incidents.randomElement()!
            data.incidentType = incident.type
            data.description = incident.desc
            data.numberOfPeople = incident.people
            data.weaponsMentioned = incident.weapon
            data.severityScore = IncidentType(rawValue: incident.type)?.baseSeverity ?? 5

        case .witnessConfirm:
            data.confirmedPanicId = UUID().uuidString
            data.witnessNote = ["I can see it happening", "Confirmed, I'm nearby", "Yes, there's a commotion", "I heard shouting"].randomElement()

        case .securityResponse:
            data.respondingToPanicId = UUID().uuidString
            data.estimatedArrival = ["\(Int.random(in: 1...5)) min", "< 2 min", "On my way"].randomElement()
            data.isOnDuty = true

        case .sos:
            let emergencies = ["Medical emergency", "Trapped in building", "Injured, need help", "Vehicle accident"]
            data.description = emergencies.randomElement()!
            data.batteryLevel = sender.batteryLevel

        case .triage:
            let conditions = ["green", "yellow", "red", "black"]
            let injuryList = ["Minor cuts", "Broken arm", "Smoke inhalation", "Dehydration", "Head injury"]
            data.patientName = "Patient P-\(Int.random(in: 100...999))"
            data.condition = conditions.randomElement()!
            data.injuries = injuryList.randomElement()!

        case .shelter:
            let shelterNames = ["Drexel Recreation Center", "UPenn Houston Hall", "Temple Student Center", "City Hall Safe Zone"]
            data.shelterName = shelterNames.randomElement()!
            data.capacity = Int.random(in: 20...200)
            data.currentOccupancy = Int.random(in: 0...150)

        case .missingPerson:
            let names = ["John D.", "Jane S.", "Mike J.", "Sarah W.", "Tom B."]
            let descriptions = ["Male, 30s, blue jacket", "Female, 20s, red hat", "Child, 10, green backpack"]
            data.personName = names.randomElement()!
            data.lastSeenLocation = "Near \(["Drexel campus", "30th St Station", "Rittenhouse", "City Hall"].randomElement()!)"
            data.physicalDescription = descriptions.randomElement()!

        case .broadcast:
            let broadcasts = [
                "SEPTA service disruption on Market-Frankford Line",
                "Campus security advisory: stay alert near 34th St",
                "Free safety escort available — call Campus Police",
                "Safe walk path updated — avoid Lancaster Ave after dark",
                "Emergency phones activated on Drexel walkway",
                "Security patrol increased in University City tonight"
            ]
            data.title = broadcasts.randomElement()!
            data.message = data.title

        default:
            data.content = "Test message"
        }

        return MeshMessage(
            type: type,
            data: data,
            senderId: sender.id,
            senderName: sender.name,
            senderRole: sender.role
        )
    }
}

// MARK: - Simulation Scenarios

enum SimulationScenario: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case disaster = "Disaster Response"
    case dense = "Dense Urban"
    case sparse = "Rural/Sparse"
    case noInternet = "No Internet"
    case campusSafety = "Campus Safety"
    case septaUnderground = "SEPTA Underground"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .normal: return "10 peers, 2 guards, regular activity"
        case .disaster: return "15 peers, 3 guards, high alert activity"
        case .dense: return "25 peers, 5 guards, frequent messages"
        case .sparse: return "4 peers, 1 guard, spread out"
        case .noInternet: return "10 peers, no gateways, mesh only"
        case .campusSafety: return "20 peers, 6 guards, university campus"
        case .septaUnderground: return "15 peers, 4 guards, underground station"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "person.3"
        case .disaster: return "exclamationmark.triangle"
        case .dense: return "building.2"
        case .sparse: return "leaf"
        case .noInternet: return "wifi.slash"
        case .campusSafety: return "building.columns"
        case .septaUnderground: return "tram.fill"
        }
    }
}
