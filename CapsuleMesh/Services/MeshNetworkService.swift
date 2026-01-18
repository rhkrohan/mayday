import Foundation
import MultipeerConnectivity
import Combine
import os.log
import UIKit
import CoreLocation

class MeshNetworkService: NSObject, ObservableObject {
    static let shared = MeshNetworkService()

    // MARK: - Published Properties
    @Published private(set) var isAdvertising = false
    @Published private(set) var isBrowsing = false
    @Published private(set) var connectedPeers: [Peer] = []
    @Published private(set) var discoveredPeers: [Peer] = []
    @Published private(set) var knownDevices: [String: Int] = [:] // deviceId: hopDistance
    @Published private(set) var networkStatus: NetworkStatus = .offline
    @Published private(set) var knownGateways: [KnownGateway] = []
    @Published private(set) var knownSecurityPersonnel: [SecurityNode] = []  // Tracked security guards
    @Published private(set) var activePanics: [ActivePanic] = []            // Active panic alerts
    @Published private(set) var pendingWitnessRequests: [WitnessRequest] = [] // Prompts for this user

    enum NetworkStatus {
        case offline
        case connecting
        case online
    }

    struct KnownGateway: Identifiable, Equatable {
        let id: String
        let name: String
        var hops: Int
        var lastSeen: Date
        var syncedCount: Int

        var isStale: Bool {
            Date().timeIntervalSince(lastSeen) > 120
        }
    }

    // MARK: - Security Personnel Tracking

    struct SecurityNode: Identifiable, Equatable {
        let id: String          // deviceId
        let name: String
        var hops: Int
        var lastSeen: Date
        var dutyStatus: DutyStatus
        var skills: [String]
        var latitude: Double?
        var longitude: Double?
        var respondingTo: String? // panicId they're responding to

        var isStale: Bool {
            Date().timeIntervalSince(lastSeen) > 60 // 1 min staleness for security
        }

        var isAvailable: Bool {
            !isStale && dutyStatus == .onDuty
        }
    }

    // MARK: - Active Panic Tracking

    struct ActivePanic: Identifiable, Equatable {
        let id: String          // panicId
        let senderId: String
        let senderName: String
        var timestamp: Date
        var latitude: Double?
        var longitude: Double?
        var emergencyType: String?
        var severityScore: Int
        var witnessCount: Int
        var respondingGuards: [String]  // deviceIds of responding guards
        var description: String?

        static func == (lhs: ActivePanic, rhs: ActivePanic) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Witness Request

    struct WitnessRequest: Identifiable, Equatable {
        let id: String          // panicId
        let senderName: String
        var timestamp: Date
        var emergencyType: String?
        var distance: Int       // hops away

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > MeshConstants.witnessCooldown
        }
    }

    // MARK: - Simulation Support

    var allPeersForDisplay: [SimulatedPeer] {
        var peers: [SimulatedPeer] = []

        for peer in connectedPeers {
            peers.append(SimulatedPeer(
                id: peer.id.displayName,
                name: peer.displayName,
                location: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                batteryLevel: -1,
                isGateway: knownGateways.contains { $0.id == peer.id.displayName },
                hops: 1,
                isMoving: false,
                movementSpeed: 0,
                movementDirection: 0,
                role: peer.role,
                dutyStatus: peer.dutyStatus
            ))
        }

        if SimulationService.shared.isRunning {
            peers.append(contentsOf: SimulationService.shared.simulatedPeers)
        }

        return peers
    }

    var allKnownDevicesForDisplay: [String: Int] {
        var devices = knownDevices

        if SimulationService.shared.isRunning {
            for peer in SimulationService.shared.simulatedPeers {
                devices[peer.id] = peer.hops
            }
        }

        return devices
    }

    var allGatewaysForDisplay: [KnownGateway] {
        var gateways = knownGateways

        if SimulationService.shared.isRunning {
            for peer in SimulationService.shared.simulatedPeers where peer.isGateway {
                gateways.append(KnownGateway(
                    id: peer.id,
                    name: peer.name,
                    hops: peer.hops,
                    lastSeen: Date(),
                    syncedCount: Int.random(in: 5...50)
                ))
            }
        }

        return gateways
    }

    /// All security personnel (real + simulated)
    var allSecurityForDisplay: [SecurityNode] {
        var security = knownSecurityPersonnel.filter { !$0.isStale }

        if SimulationService.shared.isRunning {
            for peer in SimulationService.shared.simulatedPeers where peer.role == .security {
                security.append(SecurityNode(
                    id: peer.id,
                    name: peer.name,
                    hops: peer.hops,
                    lastSeen: Date(),
                    dutyStatus: peer.dutyStatus ?? .onDuty,
                    skills: ["security"],
                    latitude: peer.location.latitude,
                    longitude: peer.location.longitude,
                    respondingTo: nil
                ))
            }
        }

        return security
    }

    /// Nearest available (on-duty, not responding) security guard
    var nearestAvailableGuard: SecurityNode? {
        allSecurityForDisplay
            .filter { $0.isAvailable && $0.respondingTo == nil }
            .min { $0.hops < $1.hops }
    }

    /// Count of on-duty security on the mesh
    var onDutySecurityCount: Int {
        allSecurityForDisplay.filter { $0.dutyStatus == .onDuty || $0.dutyStatus == .responding }.count
    }

    // MARK: - Private Properties
    private let serviceType = MeshConstants.serviceType
    private let myPeerId: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    private let logger = Logger(subsystem: "CapsuleMesh", category: "MeshNetwork")
    private var cancellables = Set<AnyCancellable>()

    private let messageStore = MessageStore.shared
    private let identity = DeviceIdentity.shared

    private var pendingReceipts: [UUID: (targetId: String, timestamp: Date)] = [:]
    private var autoConnectTimer: Timer?
    private var securityBroadcastTimer: Timer?

    // MARK: - Initialization
    private override init() {
        self.myPeerId = MCPeerID(displayName: DeviceIdentity.shared.deviceName)
        super.init()
        setupSession()
    }

    private func setupSession() {
        session = MCSession(
            peer: myPeerId,
            securityIdentity: nil,
            encryptionPreference: .none
        )
        session.delegate = self

        var discoveryInfo = [
            "deviceId": identity.deviceId,
            "role": identity.userRole.rawValue,
            "org": identity.organization.rawValue
        ]
        if let secOrg = identity.securityOrganization {
            discoveryInfo["secOrg"] = secOrg.rawValue
        }

        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerId,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser.delegate = self

        browser = MCNearbyServiceBrowser(
            peer: myPeerId,
            serviceType: serviceType
        )
        browser.delegate = self
    }

    // MARK: - Public Methods
    func start() {
        startAdvertising()
        startBrowsing()
        networkStatus = .connecting
        logger.info("Mesh network started")
        startAutoConnectTimer()

        // If security, start broadcasting duty status
        if identity.isSecurity && identity.isOnDuty {
            startSecurityBroadcast()
        }
    }

    func stop() {
        stopAdvertising()
        stopBrowsing()
        stopAutoConnectTimer()
        stopSecurityBroadcast()
        session.disconnect()
        connectedPeers.removeAll()
        discoveredPeers.removeAll()
        networkStatus = .offline
        logger.info("Mesh network stopped")
    }

    private func startAutoConnectTimer() {
        autoConnectTimer?.invalidate()
        autoConnectTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.connectToAllDiscoveredPeers()
        }
    }

    private func stopAutoConnectTimer() {
        autoConnectTimer?.invalidate()
        autoConnectTimer = nil
    }

    func startAdvertising() {
        advertiser.startAdvertisingPeer()
        isAdvertising = true
        logger.info("Started advertising")
    }

    func stopAdvertising() {
        advertiser.stopAdvertisingPeer()
        isAdvertising = false
        logger.info("Stopped advertising")
    }

    func startBrowsing() {
        browser.startBrowsingForPeers()
        isBrowsing = true
        logger.info("Started browsing")
    }

    func stopBrowsing() {
        browser.stopBrowsingForPeers()
        isBrowsing = false
        logger.info("Stopped browsing")
    }

    func connectToAllDiscoveredPeers() {
        logger.info("Attempting to connect to \(self.discoveredPeers.count) discovered peers")
        for peer in self.discoveredPeers {
            if !self.connectedPeers.contains(where: { $0.id == peer.id }) {
                logger.info("Inviting peer: \(peer.displayName)")
                browser.invitePeer(peer.id, to: session, withContext: nil, timeout: 30)
            }
        }
    }

    func refreshAndConnect() {
        logger.info("Refreshing network and connecting to all peers")
        connectToAllDiscoveredPeers()
        stopBrowsing()
        stopAdvertising()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startBrowsing()
            self?.startAdvertising()
            self?.discoverNetwork()
        }
    }

    // MARK: - Security Broadcasting

    func startSecurityBroadcast() {
        guard identity.isSecurity else { return }
        stopSecurityBroadcast()

        securityBroadcastTimer = Timer.scheduledTimer(withTimeInterval: MeshConstants.securityBroadcastInterval, repeats: true) { [weak self] _ in
            self?.broadcastSecurityStatus()
        }
        // Immediate broadcast
        broadcastSecurityStatus()
    }

    func stopSecurityBroadcast() {
        securityBroadcastTimer?.invalidate()
        securityBroadcastTimer = nil
    }

    func broadcastSecurityStatus() {
        let coords = LocationService.shared.getCurrentLocation()
        let data = MessageData(
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            isOnDuty: identity.dutyStatus == .onDuty || identity.dutyStatus == .responding,
            securityRole: identity.userRole.rawValue,
            skills: identity.userSkills.map { $0.rawValue }
        )
        let message = MeshMessage(
            type: .securityStatus,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            senderRole: identity.userRole
        )
        sendMessage(message)
    }

    // MARK: - Panic System

    func sendPanic(description: String, emergencyType: String, urgency: String = "high", existingPanicId: String? = nil) {
        let coords = LocationService.shared.getCurrentLocation()
        let batteryLevel = getBatteryLevel()
        let panicId = existingPanicId ?? UUID().uuidString

        // Calculate severity score based on emergency type and urgency
        let incidentType = IncidentType(rawValue: emergencyType)
        var severity = incidentType?.baseSeverity ?? 5
        if urgency == "critical" { severity = min(severity + 2, 10) }
        else if urgency == "high" { severity = min(severity + 1, 10) }

        let data = MessageData(
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            location: LocationService.shared.locationString ?? "GPS unavailable",
            description: description.isEmpty ? "Panic alert" : description,
            urgency: urgency,
            batteryLevel: batteryLevel,
            emergencyType: emergencyType,
            severityScore: severity,
            panicId: panicId
        )

        let message = MeshMessage(
            type: .panic,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            senderRole: identity.userRole
        )
        sendMessage(message)

        // Track locally
        let panic = ActivePanic(
            id: panicId,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            timestamp: Date(),
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            emergencyType: emergencyType,
            severityScore: severity,
            witnessCount: 0,
            respondingGuards: [],
            description: description
        )
        DispatchQueue.main.async {
            self.activePanics.insert(panic, at: 0)
        }
    }

    func sendIncidentReport(
        incidentType: String,
        description: String,
        numberOfPeople: Int?,
        weaponsMentioned: Bool,
        suspectDescription: String?,
        audioTranscript: String? = nil,
        panicId: String? = nil
    ) {
        let coords = LocationService.shared.getCurrentLocation()
        let batteryLevel = getBatteryLevel()

        let incident = IncidentType(rawValue: incidentType)
        var severity = incident?.baseSeverity ?? 5
        if weaponsMentioned { severity = min(severity + 3, 10) }

        let data = MessageData(
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            location: LocationService.shared.locationString ?? "GPS unavailable",
            description: description,
            batteryLevel: batteryLevel,
            emergencyType: incidentType,
            severityScore: severity,
            audioTranscript: audioTranscript,
            panicId: panicId,
            incidentType: incidentType,
            numberOfPeople: numberOfPeople,
            weaponsMentioned: weaponsMentioned,
            suspectDescription: suspectDescription
        )

        let message = MeshMessage(
            type: .incidentReport,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            senderRole: identity.userRole
        )
        sendMessage(message)
    }

    // MARK: - Witness Mesh

    func dismissWitnessRequest(panicId: String) {
        pendingWitnessRequests.removeAll { $0.id == panicId }
    }

    func sendWitnessConfirmation(panicId: String, note: String? = nil) {
        let coords = LocationService.shared.getCurrentLocation()
        let data = MessageData(
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            confirmedPanicId: panicId,
            witnessNote: note
        )
        let message = MeshMessage(
            type: .witnessConfirm,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            senderRole: identity.userRole
        )
        sendMessage(message)

        // Remove from pending requests
        DispatchQueue.main.async {
            self.pendingWitnessRequests.removeAll { $0.id == panicId }
        }
    }

    // MARK: - Security Response

    func sendSecurityResponse(panicId: String, estimatedArrival: String? = nil) {
        guard identity.isSecurity else { return }

        let coords = LocationService.shared.getCurrentLocation()
        let data = MessageData(
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            respondingToPanicId: panicId,
            estimatedArrival: estimatedArrival
        )
        let message = MeshMessage(
            type: .securityResponse,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            senderRole: .security
        )
        sendMessage(message)

        // Update local duty status
        identity.dutyStatus = .responding
    }

    // MARK: - Legacy Message Sending (kept for compatibility)

    func sendMessage(_ message: MeshMessage) {
        // Always store locally first — ensures gateway can sync even with no peers
        _ = messageStore.addMessage(message)

        // Try to send via mesh if peers are connected
        if !session.connectedPeers.isEmpty {
            do {
                let data = try JSONEncoder().encode(message)
                try session.send(data, toPeers: session.connectedPeers, with: .reliable)
                if message.type == .direct, let targetId = message.targetDeviceId {
                    pendingReceipts[message.id] = (targetId, Date())
                }
                logger.info("Sent message: \(message.type.rawValue)")
            } catch {
                logger.error("Failed to send message: \(error.localizedDescription)")
            }
        } else {
            logger.warning("No connected peers — message stored locally for gateway sync")
        }

        // Sync to dashboard immediately for user-facing messages
        if message.type.isUserFacing {
            GatewayService.shared.syncMessages()
        }
    }

    func sendSOS(location: String, description: String, urgency: String = "high") {
        let coords = LocationService.shared.getCurrentLocation()
        let batteryLevel = getBatteryLevel()
        let data = MessageData(
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            location: location,
            description: description,
            urgency: urgency,
            batteryLevel: batteryLevel
        )
        let message = MeshMessage(
            type: .sos,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            senderRole: identity.userRole
        )
        sendMessage(message)
    }

    private func getBatteryLevel() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        UIDevice.current.isBatteryMonitoringEnabled = false
        if level < 0 { return -1 }
        return Int(level * 100)
    }

    func sendTriage(
        patientName: String,
        age: Int,
        condition: String,
        injuries: String,
        conscious: Bool,
        breathing: Bool
    ) {
        let coords = LocationService.shared.getCurrentLocation()
        let data = MessageData(
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            patientName: patientName,
            age: age,
            condition: condition,
            injuries: injuries,
            conscious: conscious,
            breathing: breathing
        )
        let message = MeshMessage(
            type: .triage,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            senderRole: identity.userRole
        )
        sendMessage(message)
    }

    func sendShelterStatus(
        name: String,
        capacity: Int,
        currentOccupancy: Int,
        supplies: [String],
        acceptingMore: Bool
    ) {
        let coords = LocationService.shared.getCurrentLocation()
        let data = MessageData(
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            shelterName: name,
            capacity: capacity,
            currentOccupancy: currentOccupancy,
            supplies: supplies,
            acceptingMore: acceptingMore
        )
        let message = MeshMessage(
            type: .shelter,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            senderRole: identity.userRole
        )
        sendMessage(message)
    }

    func sendMissingPerson(
        name: String,
        lastSeenLocation: String,
        lastSeenTime: String,
        description: String,
        contactInfo: String,
        photoBase64: String? = nil
    ) {
        let coords = LocationService.shared.getCurrentLocation()
        let data = MessageData(
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            personName: name,
            lastSeenLocation: lastSeenLocation,
            lastSeenTime: lastSeenTime,
            physicalDescription: description,
            contactInfo: contactInfo,
            photoBase64: photoBase64
        )
        let message = MeshMessage(
            type: .missingPerson,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            senderRole: identity.userRole
        )
        sendMessage(message)
    }

    func sendBroadcast(title: String, message: String, priority: String = "normal") {
        let coords = LocationService.shared.getCurrentLocation()
        let data = MessageData(
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            title: title,
            message: message,
            priority: priority
        )
        let msg = MeshMessage(
            type: .broadcast,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            senderRole: identity.userRole
        )
        sendMessage(msg)
    }

    func sendDirectMessage(to targetDeviceId: String, content: String) {
        let data = MessageData(content: content)
        let message = MeshMessage(
            type: .direct,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            targetDeviceId: targetDeviceId,
            senderRole: identity.userRole
        )
        sendMessage(message)
    }

    func sendPing() {
        let data = MessageData(
            originalSenderId: identity.deviceId,
            originalTimestamp: Date()
        )
        let message = MeshMessage(
            type: .ping,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(message)
    }

    func discoverNetwork() {
        let data = MessageData(
            connectedPeers: session.connectedPeers.map { $0.displayName },
            requestId: UUID().uuidString
        )
        let message = MeshMessage(
            type: .discovery,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(message)
    }

    /// Broadcasts this device's gateway status to the mesh
    func broadcastGatewayStatus(isActive: Bool, syncedCount: Int) {
        let data = MessageData(
            isGateway: isActive,
            gatewayDeviceId: identity.deviceId,
            gatewayDeviceName: identity.deviceName,
            syncedCount: syncedCount
        )
        let message = MeshMessage(
            type: .gatewayStatus,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(message)
    }

    var hasReachableGateway: Bool {
        !knownGateways.filter { !$0.isStale }.isEmpty
    }

    var nearestGateway: KnownGateway? {
        knownGateways.filter { !$0.isStale }.min { $0.hops < $1.hops }
    }

    // MARK: - Message Handling
    private func handleReceivedMessage(_ message: MeshMessage, from peerID: MCPeerID) {
        guard !messageStore.hasSeenMessage(message.id) else {
            logger.debug("Ignoring duplicate message: \(message.id)")
            return
        }

        guard message.hopCount < MeshConstants.maxHops else {
            logger.debug("Message exceeded max hops: \(message.id)")
            return
        }

        switch message.type {
        case .direct:
            handleDirectMessage(message)
        case .ping:
            handlePing(message)
        case .pong:
            handlePong(message)
        case .discovery:
            handleDiscovery(message)
        case .discoveryReply:
            handleDiscoveryReply(message)
        case .deliveryReceipt:
            handleDeliveryReceipt(message)
        case .gatewayStatus:
            handleGatewayStatus(message)
        case .securityStatus:
            handleSecurityStatus(message)
        case .panic:
            handlePanic(message)
        case .witnessConfirm:
            handleWitnessConfirm(message)
        case .securityResponse:
            handleSecurityResponse(message)
        default:
            _ = messageStore.addMessage(message)
        }

        forwardMessage(message, excludingPeer: peerID)
    }

    private func handleDirectMessage(_ message: MeshMessage) {
        if message.targetDeviceId == identity.deviceId {
            _ = messageStore.addMessage(message)
            sendDeliveryReceipt(for: message)
        }
    }

    private func handlePing(_ message: MeshMessage) {
        let data = MessageData(
            originalSenderId: message.data.originalSenderId,
            originalTimestamp: message.data.originalTimestamp
        )
        let pong = MeshMessage(
            type: .pong,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(pong)
    }

    private func handlePong(_ message: MeshMessage) {
        _ = messageStore.addMessage(message)
        if let originalSender = message.data.originalSenderId {
            knownDevices[originalSender] = message.hopCount + 1
        }
    }

    private func handleDiscovery(_ message: MeshMessage) {
        let data = MessageData(
            connectedPeers: session.connectedPeers.map { $0.displayName },
            requestId: message.data.requestId
        )
        let reply = MeshMessage(
            type: .discoveryReply,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(reply)
    }

    private func handleDiscoveryReply(_ message: MeshMessage) {
        let senderDistance = message.hopCount + 1
        knownDevices[message.senderId] = senderDistance

        if let peers = message.data.connectedPeers {
            for peer in peers {
                let peerDistance = senderDistance + 1
                if knownDevices[peer] == nil || knownDevices[peer]! > peerDistance {
                    knownDevices[peer] = peerDistance
                }
            }
        }
        _ = messageStore.addMessage(message)
    }

    private func handleDeliveryReceipt(_ message: MeshMessage) {
        if let originalId = message.data.originalMessageId,
           let uuid = UUID(uuidString: originalId) {
            pendingReceipts.removeValue(forKey: uuid)
        }
        _ = messageStore.addMessage(message)
    }

    private func sendDeliveryReceipt(for originalMessage: MeshMessage) {
        let data = MessageData(
            originalMessageId: originalMessage.id.uuidString,
            deliveredAt: Date()
        )
        let receipt = MeshMessage(
            type: .deliveryReceipt,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            targetDeviceId: originalMessage.senderId
        )
        sendMessage(receipt)
    }

    private func handleGatewayStatus(_ message: MeshMessage) {
        guard let isGateway = message.data.isGateway,
              let gatewayId = message.data.gatewayDeviceId,
              let gatewayName = message.data.gatewayDeviceName else { return }

        let hops = message.hopCount + 1
        let syncedCount = message.data.syncedCount ?? 0

        if isGateway {
            if let index = knownGateways.firstIndex(where: { $0.id == gatewayId }) {
                knownGateways[index].hops = min(knownGateways[index].hops, hops)
                knownGateways[index].lastSeen = Date()
                knownGateways[index].syncedCount = syncedCount
            } else {
                knownGateways.append(KnownGateway(
                    id: gatewayId, name: gatewayName,
                    hops: hops, lastSeen: Date(), syncedCount: syncedCount
                ))
            }
        } else {
            knownGateways.removeAll { $0.id == gatewayId }
        }
        knownGateways.removeAll { $0.isStale }
    }

    // MARK: - New Message Handlers

    private func handleSecurityStatus(_ message: MeshMessage) {
        let hops = message.hopCount + 1
        let isOnDuty = message.data.isOnDuty ?? false

        if isOnDuty {
            if let index = knownSecurityPersonnel.firstIndex(where: { $0.id == message.senderId }) {
                knownSecurityPersonnel[index].hops = min(knownSecurityPersonnel[index].hops, hops)
                knownSecurityPersonnel[index].lastSeen = Date()
                knownSecurityPersonnel[index].latitude = message.data.latitude
                knownSecurityPersonnel[index].longitude = message.data.longitude
            } else {
                let node = SecurityNode(
                    id: message.senderId,
                    name: message.senderName,
                    hops: hops,
                    lastSeen: Date(),
                    dutyStatus: .onDuty,
                    skills: message.data.skills ?? [],
                    latitude: message.data.latitude,
                    longitude: message.data.longitude,
                    respondingTo: nil
                )
                knownSecurityPersonnel.append(node)
            }
            logger.info("Security guard discovered: \(message.senderName) at \(hops) hops")
        } else {
            knownSecurityPersonnel.removeAll { $0.id == message.senderId }
        }
        knownSecurityPersonnel.removeAll { $0.isStale }
    }

    private func handlePanic(_ message: MeshMessage) {
        _ = messageStore.addMessage(message)

        // Track active panic
        if let panicId = message.data.panicId {
            let panic = ActivePanic(
                id: panicId,
                senderId: message.senderId,
                senderName: message.senderName,
                timestamp: message.timestamp,
                latitude: message.data.latitude,
                longitude: message.data.longitude,
                emergencyType: message.data.emergencyType,
                severityScore: message.data.severityScore ?? 5,
                witnessCount: 0,
                respondingGuards: [],
                description: message.data.description
            )

            if !activePanics.contains(where: { $0.id == panicId }) {
                activePanics.insert(panic, at: 0)
            }

            // If we're not the sender, create a witness request prompt
            if message.senderId != identity.deviceId {
                let request = WitnessRequest(
                    id: panicId,
                    senderName: message.senderName,
                    timestamp: Date(),
                    emergencyType: message.data.emergencyType,
                    distance: message.hopCount + 1
                )
                if !pendingWitnessRequests.contains(where: { $0.id == panicId }) {
                    pendingWitnessRequests.append(request)
                }
            }

            // Auto-broadcast witness request to mesh
            broadcastWitnessRequest(panicId: panicId, senderName: message.senderName, emergencyType: message.data.emergencyType)
        }
    }

    private func broadcastWitnessRequest(panicId: String, senderName: String, emergencyType: String?) {
        let data = MessageData(
            emergencyType: emergencyType,
            panicId: panicId
        )
        let message = MeshMessage(
            type: .witnessRequest,
            data: data,
            senderId: identity.deviceId,
            senderName: senderName
        )
        // Don't store witness requests, just forward
        if !session.connectedPeers.isEmpty {
            do {
                let encoded = try JSONEncoder().encode(message)
                try session.send(encoded, toPeers: session.connectedPeers, with: .reliable)
            } catch {
                logger.error("Failed to send witness request: \(error.localizedDescription)")
            }
        }
    }

    private func handleWitnessConfirm(_ message: MeshMessage) {
        _ = messageStore.addMessage(message)

        if let panicId = message.data.confirmedPanicId,
           let index = activePanics.firstIndex(where: { $0.id == panicId }) {
            activePanics[index].witnessCount += 1

            // Escalate severity if threshold reached
            if activePanics[index].witnessCount >= MeshConstants.panicEscalationThreshold {
                activePanics[index].severityScore = min(activePanics[index].severityScore + 2, 10)
                logger.info("Panic \(panicId) escalated — \(self.activePanics[index].witnessCount) witnesses")
            }
        }
    }

    private func handleSecurityResponse(_ message: MeshMessage) {
        _ = messageStore.addMessage(message)

        if let panicId = message.data.respondingToPanicId,
           let index = activePanics.firstIndex(where: { $0.id == panicId }) {
            if !activePanics[index].respondingGuards.contains(message.senderId) {
                activePanics[index].respondingGuards.append(message.senderId)
            }
        }

        // Update security node status
        if let index = knownSecurityPersonnel.firstIndex(where: { $0.id == message.senderId }) {
            knownSecurityPersonnel[index].dutyStatus = .responding
            knownSecurityPersonnel[index].respondingTo = message.data.respondingToPanicId
        }
    }

    private func forwardMessage(_ message: MeshMessage, excludingPeer: MCPeerID) {
        var forwardedMessage = message
        forwardedMessage.addHop(deviceId: identity.deviceId)

        let peersToForward = session.connectedPeers.filter { $0 != excludingPeer }
        guard !peersToForward.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(forwardedMessage)
            try session.send(data, toPeers: peersToForward, with: .reliable)
            logger.debug("Forwarded message to \(peersToForward.count) peers")
        } catch {
            logger.error("Failed to forward message: \(error.localizedDescription)")
        }
    }
}

// MARK: - MCSessionDelegate
extension MeshNetworkService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.logger.info("Peer connected: \(peerID.displayName)")
                let peer = Peer(peerID: peerID, isConnected: true)
                if !self.connectedPeers.contains(where: { $0.id == peerID }) {
                    self.connectedPeers.append(peer)
                }
                self.discoveredPeers.removeAll { $0.id == peerID }
                self.networkStatus = .online

            case .connecting:
                self.logger.info("Peer connecting: \(peerID.displayName)")

            case .notConnected:
                self.logger.info("Peer disconnected: \(peerID.displayName)")
                self.connectedPeers.removeAll { $0.id == peerID }
                if self.connectedPeers.isEmpty {
                    self.networkStatus = self.discoveredPeers.isEmpty ? .offline : .connecting
                }

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(MeshMessage.self, from: data)
            DispatchQueue.main.async {
                self.handleReceivedMessage(message, from: peerID)
            }
        } catch {
            logger.error("Failed to decode message: \(error.localizedDescription)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MeshNetworkService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        logger.info("Received invitation from: \(peerID.displayName)")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("Failed to start advertising: \(error.localizedDescription)")
        DispatchQueue.main.async { self.isAdvertising = false }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MeshNetworkService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        logger.info("Found peer: \(peerID.displayName)")

        let role = UserRole(rawValue: info?["role"] ?? "civilian") ?? .civilian
        let org = Organization(rawValue: info?["org"] ?? "community")
        let secOrg = info?["secOrg"].flatMap { SecurityOrganization(rawValue: $0) }

        DispatchQueue.main.async {
            if !self.connectedPeers.contains(where: { $0.id == peerID }) &&
               !self.discoveredPeers.contains(where: { $0.id == peerID }) {
                let peer = Peer(peerID: peerID, isConnected: false, role: role, organization: org, securityOrg: secOrg)
                self.discoveredPeers.append(peer)
            }
        }

        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("Lost peer: \(peerID.displayName)")
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0.id == peerID }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("Failed to start browsing: \(error.localizedDescription)")
        DispatchQueue.main.async { self.isBrowsing = false }
    }
}
