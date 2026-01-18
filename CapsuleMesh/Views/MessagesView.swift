import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @ObservedObject private var simulationService = SimulationService.shared
    @State private var selectedFilter: MessageType?
    @State private var selectedMessage: MeshMessage?
    @State private var selectedQuickAction: QuickActionType?

    // System message types that should not be shown in the feed
    private static let systemMessageTypes: Set<MessageType> = [
        .ping, .pong, .discovery, .discoveryReply, .deliveryReceipt, .gatewayStatus,
        .witnessRequest, .securityStatus
    ]

    var allUserMessages: [MeshMessage] {
        var allMessages = viewModel.messageStore.messages
        if simulationService.isRunning {
            allMessages.append(contentsOf: simulationService.simulatedMessages)
        }
        return allMessages
            .filter { !Self.systemMessageTypes.contains($0.type) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var filteredMessages: [MeshMessage] {
        guard let filter = selectedFilter else {
            return allUserMessages
        }
        return allUserMessages.filter { $0.type == filter }
    }

    /// Group related messages into incident clusters
    var incidentClusters: [IncidentCluster] {
        var clusters: [String: IncidentCluster] = [:]

        for msg in allUserMessages {
            guard let panicId = msg.relatedPanicId else { continue }

            if clusters[panicId] == nil {
                clusters[panicId] = IncidentCluster(id: panicId)
            }

            switch msg.type {
            case .panic, .sos:
                clusters[panicId]?.panic = msg
            case .witnessConfirm:
                clusters[panicId]?.witnesses.append(msg)
            case .securityResponse:
                clusters[panicId]?.securityResponses.append(msg)
            case .incidentReport:
                clusters[panicId]?.incidentReports.append(msg)
            default:
                break
            }
            clusters[panicId]?.updateLatestTimestamp(msg.timestamp)
        }

        // Only return clusters that have a panic/root message
        return clusters.values
            .filter { $0.panic != nil }
            .sorted { ($0.panic?.data.severityScore ?? 0) > ($1.panic?.data.severityScore ?? 0) }
    }

    /// Messages not linked to any incident cluster
    var standaloneMessages: [MeshMessage] {
        let clusteredTypes: Set<MessageType> = [.panic, .sos, .witnessConfirm, .securityResponse]
        return filteredMessages.filter { msg in
            if clusteredTypes.contains(msg.type) && msg.relatedPanicId != nil {
                return false // This belongs to a cluster
            }
            return true
        }
    }

    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header
                header
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Quick actions
                quickActionsRow
                    .padding(.bottom, 16)

                // Content
                if filteredMessages.isEmpty {
                    emptyState
                } else {
                    groupedFeed
                }
            }
        }
        .sheet(item: $selectedMessage) { message in
            MessageDetailSheet(message: message)
        }
        .sheet(item: $selectedQuickAction) { action in
            quickActionSheet(for: action)
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            // Top bar with logo
            HStack {
                // Filter button
                Menu {
                    Button {
                        selectedFilter = nil
                    } label: {
                        Label("All messages", systemImage: selectedFilter == nil ? "checkmark" : "")
                    }

                    Divider()

                    ForEach([MessageType.panic, .incidentReport, .witnessConfirm, .securityResponse, .sos, .triage, .shelter, .missingPerson, .broadcast, .direct], id: \.self) { type in
                        Button {
                            selectedFilter = type
                        } label: {
                            Label(type.displayName, systemImage: selectedFilter == type ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: selectedFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding(12)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
                }

                Spacer()

                // Mayday logo
                HStack(spacing: 8) {
                    MaydayLogoCompact(size: 22)
                    Text("Messages")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                }

                Spacer()

                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())
            }

            // Filter chip if active
            if let filter = selectedFilter {
                HStack {
                    Text("Showing: \(filter.displayName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black)

                    Spacer()

                    Button {
                        withAnimation { selectedFilter = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Quick Actions Row

    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickActionCard(
                    icon: "exclamationmark.shield.fill",
                    title: "Incident",
                    borderColor: Color(red: 0.9, green: 0.3, blue: 0.1),
                    opacity: 0.95
                ) {
                    selectedQuickAction = .incidentReport
                }

                QuickActionCard(
                    icon: "megaphone.fill",
                    title: "Broadcast",
                    borderColor: Color(red: 0.5, green: 0.4, blue: 0.8),
                    opacity: 0.75
                ) {
                    selectedQuickAction = .broadcast
                }

                QuickActionCard(
                    icon: "person.fill.questionmark",
                    title: "Missing",
                    borderColor: Color(red: 0.95, green: 0.6, blue: 0.2),
                    opacity: 0.85
                ) {
                    selectedQuickAction = .missingPerson
                }

                QuickActionCard(
                    icon: "cross.case.fill",
                    title: "Triage",
                    borderColor: Color(red: 0.2, green: 0.6, blue: 0.9),
                    opacity: 0.9
                ) {
                    selectedQuickAction = .triage
                }

                QuickActionCard(
                    icon: "shield.lefthalf.filled",
                    title: "Safe Zone",
                    borderColor: Color(red: 0.3, green: 0.7, blue: 0.4),
                    opacity: 0.8
                ) {
                    selectedQuickAction = .shelter
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func quickActionSheet(for action: QuickActionType) -> some View {
        switch action {
        case .incidentReport:
            IncidentReportView()
        case .broadcast:
            BroadcastSheet()
        case .missingPerson:
            if #available(iOS 16.0, *) {
                MissingPersonSheet()
            } else {
                Text("Photo picker requires iOS 16+")
            }
        case .triage:
            TriageSheet()
        case .shelter:
            ShelterSheet()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated pigeon
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.03))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(Color.black.opacity(0.05))
                        .frame(width: 100, height: 100)

                    Image(systemName: "bird.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.black)
                }

                VStack(spacing: 8) {
                    Text("No messages yet")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)

                    Text("Messages from the Mayday mesh\nnetwork will appear here")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            // Action button
            Button {
                viewModel.meshService.sendPing()
            } label: {
                Text("Send ping")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 100)
        }
    }

    private var groupedFeed: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Active incident clusters (grouped by panic)
                if !incidentClusters.isEmpty && selectedFilter == nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Incidents")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)

                        ForEach(incidentClusters) { cluster in
                            FeedIncidentCard(cluster: cluster)
                        }
                    }
                }

                // Standalone messages
                if !standaloneMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        if !incidentClusters.isEmpty && selectedFilter == nil {
                            Text("Other Activity")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 4)
                        }

                        ForEach(standaloneMessages) { message in
                            MessageCard(message: message)
                                .onTapGesture {
                                    selectedMessage = message
                                }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
    }

    private var statusColor: Color {
        switch viewModel.meshService.networkStatus {
        case .offline: return .black.opacity(0.3)
        case .connecting: return .black.opacity(0.5)
        case .online: return .black
        }
    }

    private var statusText: String {
        switch viewModel.meshService.networkStatus {
        case .offline: return "Offline"
        case .connecting: return "Connecting"
        case .online: return "\(viewModel.meshService.connectedPeers.count) peers"
        }
    }
}

// MARK: - Message Card

struct MessageCard: View {
    let message: MeshMessage

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Type icon with black background and colored border
            ZStack {
                Circle()
                    .fill(Color.black.opacity(iconOpacity))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: 2.5)
                    )

                Image(systemName: message.type.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack {
                    Text(message.type.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)

                    Spacer()

                    Text(message.timestamp, style: .relative)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Sender
                Text(message.senderName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                // Preview
                messagePreview
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.7))
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var iconOpacity: Double {
        switch message.type {
        case .panic, .sos: return 1.0
        case .incidentReport: return 0.95
        case .securityResponse: return 0.9
        case .witnessConfirm: return 0.85
        case .triage: return 0.9
        case .shelter: return 0.8
        case .missingPerson: return 0.85
        case .broadcast: return 0.75
        case .direct: return 0.7
        default: return 0.6
        }
    }

    private var borderColor: Color {
        switch message.type {
        case .panic, .sos: return .red
        case .incidentReport: return Color(red: 0.9, green: 0.3, blue: 0.1)
        case .securityResponse: return MaydayBrand.securityBlue
        case .witnessConfirm: return Color(red: 0.2, green: 0.7, blue: 0.3)
        case .triage: return Color(red: 0.2, green: 0.6, blue: 0.9)
        case .shelter: return Color(red: 0.3, green: 0.7, blue: 0.4)
        case .missingPerson: return Color(red: 0.95, green: 0.6, blue: 0.2)
        case .broadcast: return Color(red: 0.5, green: 0.4, blue: 0.8)
        case .direct: return Color(red: 0.4, green: 0.4, blue: 0.4)
        default: return .black
        }
    }

    @ViewBuilder
    private var messagePreview: some View {
        switch message.type {
        case .panic:
            if let desc = message.data.description {
                Text(desc)
            } else if let type = message.data.emergencyType {
                Text(type.capitalized)
            }
        case .incidentReport:
            if let desc = message.data.description {
                Text(desc)
            }
        case .witnessConfirm:
            if let note = message.data.witnessNote {
                Text(note)
            } else {
                Text("Incident confirmed by witness")
            }
        case .securityResponse:
            if let eta = message.data.estimatedArrival {
                Text("Security responding — ETA \(eta)")
            } else {
                Text("Security is responding")
            }
        case .sos:
            if let location = message.data.location {
                Text(location)
            }
        case .triage:
            if let name = message.data.patientName, let condition = message.data.condition {
                Text("\(name) — \(condition.capitalized)")
            }
        case .shelter:
            if let name = message.data.shelterName {
                Text(name)
            }
        case .missingPerson:
            if let name = message.data.personName {
                Text(name)
            }
        case .broadcast:
            if let title = message.data.title {
                Text(title)
            }
        case .direct:
            if let content = message.data.content {
                Text(content)
            }
        default:
            EmptyView()
        }
    }

    // Severity/security badge below the preview
    @ViewBuilder
    private var messageBadges: some View {
        HStack(spacing: 8) {
            if let severity = message.data.severityScore {
                SeverityBadge(score: severity)
            }
            if message.senderRole == .security {
                Text("SECURITY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(MaydayBrand.securityBlue)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Message Detail Sheet

struct MessageDetailSheet: View {
    let message: MeshMessage
    @Environment(\.dismiss) var dismiss

    private var borderColor: Color {
        switch message.type {
        case .sos: return .red
        case .triage: return Color(red: 0.2, green: 0.6, blue: 0.9)
        case .shelter: return Color(red: 0.3, green: 0.7, blue: 0.4)
        case .missingPerson: return Color(red: 0.95, green: 0.6, blue: 0.2)
        case .broadcast: return Color(red: 0.5, green: 0.4, blue: 0.8)
        case .direct: return Color(red: 0.4, green: 0.4, blue: 0.4)
        default: return .black
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header card
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Circle()
                                        .stroke(borderColor, lineWidth: 3)
                                )

                            Image(systemName: message.type.icon)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 4) {
                            Text(message.type.displayName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)

                            Text("From \(message.senderName)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Details section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 0) {
                            detailContent
                        }
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Metadata section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Metadata")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 0) {
                            DetailRowBW(label: "Received", value: message.timestamp.formatted())
                            Divider().padding(.leading, 16)
                            DetailRowBW(label: "Hops", value: "\(message.hopCount)")
                            Divider().padding(.leading, 16)
                            DetailRowBW(label: "Message ID", value: String(message.id.uuidString.prefix(12)) + "...")
                        }
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        MaydayLogoCompact(size: 18)
                        Text("Mayday")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch message.type {
        case .sos:
            if let location = message.data.location {
                DetailRowBW(label: "Location", value: location)
                Divider().padding(.leading, 16)
            }
            if let desc = message.data.description {
                DetailRowBW(label: "Description", value: desc)
                Divider().padding(.leading, 16)
            }
            if let urgency = message.data.urgency {
                DetailRowBW(label: "Urgency", value: urgency.capitalized)
            }

        case .triage:
            if let name = message.data.patientName {
                DetailRowBW(label: "Patient", value: name)
                Divider().padding(.leading, 16)
            }
            if let age = message.data.age {
                DetailRowBW(label: "Age", value: "\(age)")
                Divider().padding(.leading, 16)
            }
            if let condition = message.data.condition {
                DetailRowBW(label: "Condition", value: condition.capitalized)
                Divider().padding(.leading, 16)
            }
            if let injuries = message.data.injuries {
                DetailRowBW(label: "Injuries", value: injuries)
            }

        case .shelter:
            if let name = message.data.shelterName {
                DetailRowBW(label: "Shelter", value: name)
                Divider().padding(.leading, 16)
            }
            if let capacity = message.data.capacity, let occupancy = message.data.currentOccupancy {
                DetailRowBW(label: "Occupancy", value: "\(occupancy) / \(capacity)")
                Divider().padding(.leading, 16)
            }
            if let accepting = message.data.acceptingMore {
                DetailRowBW(label: "Accepting", value: accepting ? "Yes" : "No")
            }

        case .missingPerson:
            if let name = message.data.personName {
                DetailRowBW(label: "Name", value: name)
                Divider().padding(.leading, 16)
            }
            if let lastSeen = message.data.lastSeenLocation {
                DetailRowBW(label: "Last seen", value: lastSeen)
                Divider().padding(.leading, 16)
            }
            if let desc = message.data.physicalDescription {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(desc)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }
                .padding(16)
            }

        case .broadcast:
            if let title = message.data.title {
                DetailRowBW(label: "Title", value: title)
                Divider().padding(.leading, 16)
            }
            if let msg = message.data.message {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(msg)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }
                .padding(16)
            }

        case .direct:
            if let content = message.data.content {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(content)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }
                .padding(16)
            }

        default:
            EmptyView()
        }
    }
}

// MARK: - Detail Row

struct DetailRowBW: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.black)
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
    }
}

// MARK: - Quick Action Type

enum QuickActionType: String, Identifiable {
    case incidentReport
    case broadcast
    case missingPerson
    case triage
    case shelter

    var id: String { rawValue }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let borderColor: Color
    let opacity: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(opacity))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(borderColor, lineWidth: 2.5)
                        )

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black)
            }
            .frame(width: 80)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(QuickActionButtonStyle())
    }
}

struct QuickActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Incident Cluster Model

struct IncidentCluster: Identifiable {
    let id: String // panicId
    var panic: MeshMessage?
    var witnesses: [MeshMessage] = []
    var securityResponses: [MeshMessage] = []
    var incidentReports: [MeshMessage] = []
    var latestTimestamp: Date = Date()

    var totalMessages: Int {
        (panic != nil ? 1 : 0) + witnesses.count + securityResponses.count + incidentReports.count
    }

    var severity: Int {
        panic?.data.severityScore ?? 5
    }

    var isBeingResponded: Bool {
        !securityResponses.isEmpty
    }

    mutating func updateLatestTimestamp(_ date: Date) {
        if date > latestTimestamp {
            latestTimestamp = date
        }
    }
}

// MARK: - Feed Incident Card (grouped)

struct FeedIncidentCard: View {
    let cluster: IncidentCluster
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon — same style as MessageCard (black circle + colored border)
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(severityColor, lineWidth: 2.5)
                    )

                if let type = cluster.panic?.data.emergencyType {
                    let incident = IncidentType(rawValue: type)
                    Image(systemName: incident?.icon ?? "light.beacon.max.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "light.beacon.max.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(cluster.panic?.data.emergencyType?.capitalized.replacingOccurrences(of: "_", with: " ") ?? "Incident")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)

                    Spacer()

                    if let ts = cluster.panic?.timestamp {
                        Text(ts, style: .relative)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                // Sender
                if let name = cluster.panic?.senderName {
                    Text(name)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                // Description
                if let desc = cluster.panic?.data.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.7))
                        .lineLimit(isExpanded ? nil : 2)
                }

                // Severity badge
                if cluster.severity > 0 {
                    SeverityBadge(score: cluster.severity)
                }

                // Status pills
                HStack(spacing: 6) {
                    if !cluster.witnesses.isEmpty {
                        statusPill(icon: "eye.fill", text: "\(cluster.witnesses.count)", color: .orange)
                    }
                    if cluster.isBeingResponded {
                        statusPill(icon: "shield.checkered", text: "\(cluster.securityResponses.count)", color: MaydayBrand.securityBlue)
                    }
                    if !cluster.incidentReports.isEmpty {
                        statusPill(icon: "doc.text.fill", text: "\(cluster.incidentReports.count)", color: Color(red: 0.9, green: 0.3, blue: 0.1))
                    }
                }

                // Timeline (expanded)
                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(expandedMessages) { msg in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(msg.type.color)
                                    .frame(width: 6, height: 6)
                                Text(msg.type.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(msg.type.color)
                                Text(msg.senderName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(msg.timestamp, style: .relative)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // Expand button
                if cluster.totalMessages > 1 {
                    Button {
                        withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Show less" : "\(cluster.totalMessages) updates")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var severityColor: Color {
        switch cluster.severity {
        case 7...10: return .red
        case 4...6: return .orange
        default: return Color(red: 0.3, green: 0.7, blue: 0.4)
        }
    }

    private var expandedMessages: [MeshMessage] {
        var msgs: [MeshMessage] = []
        if let panic = cluster.panic { msgs.append(panic) }
        msgs.append(contentsOf: cluster.witnesses)
        msgs.append(contentsOf: cluster.securityResponses)
        msgs.append(contentsOf: cluster.incidentReports)
        return msgs.sorted { $0.timestamp < $1.timestamp }
    }

    private func statusPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
