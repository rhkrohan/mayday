import SwiftUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @StateObject private var gatewayService = GatewayService.shared
    @ObservedObject private var simulationService = SimulationService.shared
    @State private var deviceName: String = DeviceIdentity.shared.deviceName
    @State private var showingClearConfirmation = false
    @State private var apiEndpoint: String = GatewayService.shared.apiEndpoint
    @State private var showingEndpointEditor = false
    @State private var selectedScenario: SimulationScenario = .normal

    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        deviceSection
                        networkSection
                        gatewaySection
                        simulationSection
                        dataSection
                        aboutSection
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
        }
        .alert("Clear all messages?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                viewModel.messageStore.clearMessages()
            }
        } message: {
            Text("This will delete all \(viewModel.messageStore.messages.count) stored messages. This cannot be undone.")
        }
    }

    private var header: some View {
        HStack {
            Spacer()

            HStack(spacing: 8) {
                MaydayLogoCompact(size: 22)
                Text("Settings")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            }

            Spacer()
        }
        .padding(.bottom, 16)
    }

    // MARK: - Device Section

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                // Device ID
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: "number")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }

                        Text("Device ID")
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                    }

                    Spacer()

                    Text(String(DeviceIdentity.shared.deviceId.prefix(12)) + "...")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(14)

                Divider()
                    .padding(.leading, 60)

                // Device Name
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                        }

                        Text("Name")
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                    }

                    Spacer()

                    TextField("Device name", text: $deviceName)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            DeviceIdentity.shared.deviceName = deviceName
                        }
                }
                .padding(14)
            }
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Network Section

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                // Advertising Toggle
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Advertising")
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                            Text("Allow others to find you")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { viewModel.meshService.isAdvertising },
                        set: { if $0 { viewModel.meshService.startAdvertising() } else { viewModel.meshService.stopAdvertising() } }
                    ))
                    .tint(.black)
                }
                .padding(14)

                Divider()
                    .padding(.leading, 60)

                // Browsing Toggle
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Browsing")
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                            Text("Search for nearby devices")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { viewModel.meshService.isBrowsing },
                        set: { if $0 { viewModel.meshService.startBrowsing() } else { viewModel.meshService.stopBrowsing() } }
                    ))
                    .tint(.black)
                }
                .padding(14)
            }
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Gateway Section

    private var gatewaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gateway")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                // Internet Status
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(gatewayService.isOnline ? Color.green.opacity(0.15) : Color.black.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: gatewayService.isOnline ? "wifi" : "wifi.slash")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(gatewayService.isOnline ? .green : .black)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Internet")
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                            Text(gatewayService.isOnline ? "Connected" : "Not available")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Circle()
                        .fill(gatewayService.isOnline ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                }
                .padding(14)

                Divider()
                    .padding(.leading, 60)

                // Gateway Status
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(gatewayService.isGatewayActive ? Color.blue.opacity(0.15) : Color.black.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: "antenna.radiowaves.left.and.right.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(gatewayService.isGatewayActive ? .blue : .black)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gateway Mode")
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                            Text(gatewayService.isGatewayActive ? "Active - syncing to cloud" : "Inactive")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if gatewayService.isGatewayActive {
                        Text("ON")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding(14)

                Divider()
                    .padding(.leading, 60)

                // Synced Messages
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Synced to Cloud")
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                            if let lastSync = gatewayService.lastSyncTime {
                                Text("Last: \(lastSync.formatted(date: .omitted, time: .shortened))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Never synced")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Text("\(gatewayService.syncedMessageCount)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Capsule())
                }
                .padding(14)

                Divider()
                    .padding(.leading, 60)

                // Sync Status
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(syncStatusColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: syncStatusIcon)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(syncStatusColor)
                        }

                        Text(syncStatusText)
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                    }

                    Spacer()

                    if case .syncing = gatewayService.syncStatus {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(14)

                Divider()
                    .padding(.leading, 60)

                // Force Sync Button
                Button {
                    gatewayService.forceSyncAll()
                } label: {
                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.08))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
                            }

                            Text("Force Sync All")
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                }
                .disabled(!gatewayService.isOnline)
                .opacity(gatewayService.isOnline ? 1 : 0.5)
            }
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("When online, this device acts as a gateway to sync mesh messages to the cloud for emergency responders.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // Helper computed properties for sync status
    private var syncStatusColor: Color {
        switch gatewayService.syncStatus {
        case .idle: return .gray
        case .syncing: return .blue
        case .success: return .green
        case .failed: return .red
        }
    }

    private var syncStatusIcon: String {
        switch gatewayService.syncStatus {
        case .idle: return "moon.zzz"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }

    private var syncStatusText: String {
        switch gatewayService.syncStatus {
        case .idle: return "Idle"
        case .syncing: return "Syncing..."
        case .success(let count): return "Synced \(count) messages"
        case .failed(let error): return error
        }
    }

    // MARK: - Simulation Section

    private var simulationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Simulation")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                // Simulation Toggle
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(simulationService.isRunning ? Color.purple.opacity(0.15) : Color.black.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: simulationService.isRunning ? "play.circle.fill" : "play.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(simulationService.isRunning ? .purple : .black)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Simulation Mode")
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                            Text(simulationService.isRunning ? "Running with \(simulationService.simulatedPeers.count) peers" : "Test mesh without real devices")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { simulationService.isRunning },
                        set: { newValue in
                            if newValue {
                                simulationService.start(scenario: selectedScenario)
                            } else {
                                simulationService.stop()
                            }
                        }
                    ))
                    .tint(.purple)
                }
                .padding(14)

                if simulationService.isRunning {
                    Divider()
                        .padding(.leading, 60)

                    // Scenario picker
                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.08))
                                    .frame(width: 36, height: 36)
                                Image(systemName: selectedScenario.icon)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scenario")
                                    .font(.system(size: 15))
                                    .foregroundColor(.black)
                                Text(selectedScenario.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Menu {
                            ForEach(SimulationScenario.allCases) { scenario in
                                Button {
                                    selectedScenario = scenario
                                    simulationService.setScenario(scenario)
                                } label: {
                                    Label(scenario.rawValue, systemImage: scenario.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedScenario.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(14)

                    Divider()
                        .padding(.leading, 60)

                    // Stats
                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.08))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "person.3")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.black)
                            }

                            Text("Simulated Peers")
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            // Total peers
                            HStack(spacing: 4) {
                                Text("\(simulationService.simulatedPeers.count)")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                Text("peers")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)

                            // Gateways
                            HStack(spacing: 4) {
                                Image(systemName: "wifi")
                                    .font(.system(size: 10, weight: .bold))
                                Text("\(simulationService.simulatedPeers.filter { $0.isGateway }.count)")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.green)
                        }
                    }
                    .padding(14)

                    Divider()
                        .padding(.leading, 60)

                    // Messages
                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.08))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                            }

                            Text("Simulated Messages")
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                        }

                        Spacer()

                        Text("\(simulationService.simulatedMessages.count)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                }
            }
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("Simulation creates virtual peers to test mesh networking features without needing multiple physical devices.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                // Stored messages count
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: "tray.full")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.black)
                        }

                        Text("Stored messages")
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                    }

                    Spacer()

                    Text("\(viewModel.messageStore.messages.count)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Capsule())
                }
                .padding(14)

                Divider()
                    .padding(.leading, 60)

                // Clear messages button
                Button {
                    showingClearConfirmation = true
                } label: {
                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.red)
                            }

                            Text("Clear all messages")
                                .font(.system(size: 15))
                                .foregroundColor(.red)
                        }

                        Spacer()
                    }
                    .padding(14)
                }
            }
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("Clearing messages cannot be undone.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                // App info header
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                            .frame(width: 56, height: 56)

                        Image(systemName: "bird.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mayday")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)

                        Text("Mesh communication for emergencies")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(16)

                Divider()
                    .padding(.leading, 86)

                // Version
                HStack {
                    Text("Version")
                        .font(.system(size: 15))
                        .foregroundColor(.black)

                    Spacer()

                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(14)

                Divider()
                    .padding(.leading, 16)

                // Build
                HStack {
                    Text("Build")
                        .font(.system(size: 15))
                        .foregroundColor(.black)

                    Spacer()

                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("Mayday enables peer-to-peer communication when traditional networks are unavailable.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }
}
