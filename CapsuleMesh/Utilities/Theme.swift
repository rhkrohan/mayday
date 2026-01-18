import SwiftUI

// MARK: - Mayday Branding

enum MaydayBrand {
    // Primary brand colors - Black and White theme
    static let primary = Color.black
    static let secondary = Color(white: 0.3)
    static let accent = Color(white: 0.5)

    // Light variants for backgrounds
    static let background = Color.white
    static let surfaceLight = Color(white: 0.97)
    static let surfaceMedium = Color(white: 0.92)

    // For map visualization
    static let mapBackground = Color.white
    static let gridColor = Color.black.opacity(0.08)
    static let nodeColor = Color.black
    static let edgeColor = Color.black

    // Safety-specific colors
    static let securityBlue = Color(red: 0.2, green: 0.4, blue: 0.9)
    static let panicRed = Color.red
    static let witnessAmber = Color.orange
    static let safeGreen = Color(red: 0.2, green: 0.8, blue: 0.4)

    // App name
    static let appName = "Mayday"
    static let tagline = "Community safety mesh network"
}

// MARK: - Mayday Logo

struct MaydayLogo: View {
    var size: CGFloat = 60
    var showText: Bool = true
    var animated: Bool = false
    var inverted: Bool = false // For dark backgrounds

    @State private var pulseScale: CGFloat = 1.0

    private var foregroundColor: Color {
        inverted ? .white : MaydayBrand.primary
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(foregroundColor.opacity(0.1))
                    .frame(width: size * 1.3, height: size * 1.3)
                    .scaleEffect(animated ? pulseScale : 1.0)

                Image(systemName: "light.beacon.max.fill")
                    .font(.system(size: size * 0.7, weight: .medium))
                    .foregroundColor(foregroundColor)
            }

            if showText {
                Text(MaydayBrand.appName)
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .foregroundColor(foregroundColor)
            }
        }
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.08
                }
            }
        }
    }
}

struct MaydayLogoCompact: View {
    var size: CGFloat = 24
    var inverted: Bool = false

    var body: some View {
        Image(systemName: "light.beacon.max.fill")
            .font(.system(size: size, weight: .medium))
            .foregroundColor(inverted ? .white : MaydayBrand.primary)
    }
}

// MARK: - App Theme

enum AppTheme {
    // Semantic colors that adapt to light/dark mode
    static let accent = MaydayBrand.primary
    static let destructive = Color.red
    static let success = Color.green
    static let warning = Color.orange

    // Status colors
    static let online = Color.green
    static let offline = Color.secondary
    static let connecting = Color.orange
}

// MARK: - Message Type Styling

extension MessageType {
    var color: Color {
        switch self {
        case .panic: return .red
        case .incidentReport: return Color(red: 0.9, green: 0.3, blue: 0.1)
        case .witnessRequest: return .orange
        case .witnessConfirm: return Color(red: 0.2, green: 0.7, blue: 0.3)
        case .securityStatus: return MaydayBrand.securityBlue
        case .securityResponse: return Color(red: 0.1, green: 0.5, blue: 0.9)
        case .sos: return .red
        case .triage: return .orange
        case .shelter: return .blue
        case .missingPerson: return .purple
        case .broadcast: return .green
        case .direct: return .secondary
        default: return .secondary
        }
    }
}

// MARK: - Role Styling

extension UserRole {
    var color: Color {
        switch self {
        case .civilian: return .secondary
        case .security: return MaydayBrand.securityBlue
        case .admin: return .purple
        }
    }
}

extension DutyStatus {
    var color: Color {
        switch self {
        case .offDuty: return .secondary
        case .onDuty: return MaydayBrand.safeGreen
        case .responding: return .orange
        case .unavailable: return .red
        }
    }
}

// MARK: - Reusable Components

struct PrimaryButton: View {
    let title: String
    let icon: String?
    var role: ButtonRole? = nil
    var isDisabled: Bool = false
    let action: () -> Void

    init(_ title: String, icon: String? = nil, role: ButtonRole? = nil, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.role = role
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(role == .destructive ? .red : .accentColor)
        .disabled(isDisabled)
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
    }
}

struct StatusIndicator: View {
    let status: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let action = action, let label = actionLabel {
                Button(label, action: action)
                    .font(.subheadline)
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let action = action, let label = actionLabel {
                Button(label, action: action)
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

struct MessageRow: View {
    let message: MeshMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Type icon
            Image(systemName: message.type.icon)
                .font(.title3)
                .foregroundStyle(message.type.color)
                .frame(width: 32, height: 32)
                .background(message.type.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.type.displayName)
                        .font(.subheadline.weight(.semibold))

                    if message.senderRole == .security {
                        Image(systemName: "shield.checkered")
                            .font(.caption)
                            .foregroundStyle(MaydayBrand.securityBlue)
                    }

                    Spacer()
                    Text(message.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 4) {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if message.senderRole == .security {
                        Text("SECURITY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(MaydayBrand.securityBlue)
                            .clipShape(Capsule())
                    }
                }

                // Content preview
                messagePreview
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)

                // Severity badge for panic/incident
                if let severity = message.data.severityScore {
                    SeverityBadge(score: severity)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    var messagePreview: some View {
        switch message.type {
        case .panic:
            if let desc = message.data.description {
                Text(desc)
            } else if let emergencyType = message.data.emergencyType {
                Text(emergencyType.capitalized)
            }
        case .incidentReport:
            if let type = message.data.incidentType {
                Text(type.capitalized.replacingOccurrences(of: "_", with: " "))
            }
        case .witnessConfirm:
            Text("Incident confirmed by witness")
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
}

// MARK: - Severity Badge

struct SeverityBadge: View {
    let score: Int

    var color: Color {
        switch score {
        case 1...3: return .green
        case 4...6: return .orange
        case 7...8: return Color(red: 0.9, green: 0.3, blue: 0.1)
        case 9...10: return .red
        default: return .secondary
        }
    }

    var label: String {
        switch score {
        case 1...3: return "LOW"
        case 4...6: return "MEDIUM"
        case 7...8: return "HIGH"
        case 9...10: return "CRITICAL"
        default: return "UNKNOWN"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("Severity \(score)/10 — \(label)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct PeerRow: View {
    let peer: Peer
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: peer.role == .security ? "shield.checkered" : (isConnected ? "iphone.radiowaves.left.and.right" : "iphone"))
                .font(.title2)
                .foregroundStyle(peerColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(peer.displayName)
                        .font(.body)
                    if peer.role == .security {
                        Text(peer.dutyStatus?.displayName ?? "Security")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(peer.dutyStatus?.color ?? MaydayBrand.securityBlue)
                            .clipShape(Capsule())
                    }
                }
                Text(isConnected ? "Connected" : "Available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(peerColor)
            }
        }
    }

    private var peerColor: Color {
        if peer.isOnDutySecurity {
            return MaydayBrand.securityBlue
        }
        return isConnected ? .green : .secondary
    }
}

struct HopIndicator: View {
    let hops: Int

    var body: some View {
        Text("\(hops) hop\(hops == 1 ? "" : "s")")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
    }
}

struct NetworkStatusCard: View {
    let isOnline: Bool
    let peerCount: Int
    let isAdvertising: Bool
    let isBrowsing: Bool
    var securityCount: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network status")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(isOnline ? "Online" : "Offline")
                        .font(.title2.weight(.semibold))
                }

                Spacer()

                Circle()
                    .fill(isOnline ? Color.green : Color.secondary)
                    .frame(width: 12, height: 12)
            }

            Divider()

            HStack {
                Label("\(peerCount) peers", systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if securityCount > 0 {
                    Label("\(securityCount) security", systemImage: "shield.checkered")
                        .font(.subheadline)
                        .foregroundStyle(MaydayBrand.securityBlue)
                }

                Spacer()

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isAdvertising ? Color.green : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                        Text("Advertising")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(isBrowsing ? Color.green : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                        Text("Browsing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Form Components

struct FormSection<Content: View>: View {
    let header: String?
    let footer: String?
    let content: Content

    init(header: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = header
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        Section {
            content
        } header: {
            if let header = header {
                Text(header)
            }
        } footer: {
            if let footer = footer {
                Text(footer)
            }
        }
    }
}

struct OptionPicker<T: Hashable>: View {
    let title: String
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String
    var color: ((T) -> Color)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        Text(label(option))
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selection == option ? (color?(option) ?? .accentColor) : Color(.systemGray5))
                            .foregroundStyle(selection == option ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Security Nearest Guard Card

struct NearestGuardCard: View {
    let guardName: String
    let hops: Int
    let dutyStatus: DutyStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 24))
                .foregroundStyle(MaydayBrand.securityBlue)
                .frame(width: 44, height: 44)
                .background(MaydayBrand.securityBlue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Nearest Security")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(guardName)
                    .font(.system(size: 15, weight: .semibold))
                HStack(spacing: 8) {
                    Text("\(hops) hop\(hops == 1 ? "" : "s") away")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dutyStatus.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(dutyStatus.color)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(MaydayBrand.securityBlue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MaydayBrand.securityBlue.opacity(0.2), lineWidth: 1)
        )
    }
}
