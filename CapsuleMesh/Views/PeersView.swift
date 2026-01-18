import SwiftUI

struct PeersView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                // Network status section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Status")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(statusText)
                                    .font(.title2.weight(.semibold))
                            }

                            Spacer()

                            Circle()
                                .fill(statusColor)
                                .frame(width: 12, height: 12)
                        }

                        Divider()

                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Advertising")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(viewModel.meshService.isAdvertising ? Color.green : Color.secondary.opacity(0.3))
                                        .frame(width: 6, height: 6)
                                    Text(viewModel.meshService.isAdvertising ? "On" : "Off")
                                        .font(.subheadline)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Browsing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(viewModel.meshService.isBrowsing ? Color.green : Color.secondary.opacity(0.3))
                                        .frame(width: 6, height: 6)
                                    Text(viewModel.meshService.isBrowsing ? "On" : "Off")
                                        .font(.subheadline)
                                }
                            }

                            Spacer()

                            Text(DeviceIdentity.shared.deviceName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Connected peers
                Section {
                    if viewModel.meshService.connectedPeers.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)
                                Text("No connected peers")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(viewModel.meshService.connectedPeers) { peer in
                            PeerRow(peer: peer, isConnected: true)
                        }
                    }
                } header: {
                    Text("Connected (\(viewModel.meshService.connectedPeers.count))")
                }

                // Discovered peers
                Section {
                    if viewModel.meshService.discoveredPeers.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(viewModel.meshService.discoveredPeers) { peer in
                            PeerRow(peer: peer, isConnected: false)
                        }
                    }
                } header: {
                    Text("Discovered (\(viewModel.meshService.discoveredPeers.count))")
                }

                // Known devices (mesh topology)
                if !viewModel.meshService.knownDevices.isEmpty {
                    Section {
                        ForEach(Array(viewModel.meshService.knownDevices.keys.sorted()), id: \.self) { deviceId in
                            if let hops = viewModel.meshService.knownDevices[deviceId] {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(String(deviceId.prefix(16)) + "...")
                                            .font(.system(.subheadline, design: .monospaced))
                                        Text("\(hops) hop\(hops == 1 ? "" : "s") away")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    HopIndicator(hops: hops)
                                }
                            }
                        }
                    } header: {
                        Text("Mesh topology (\(viewModel.meshService.knownDevices.count))")
                    }
                }

                // Actions
                Section {
                    Button {
                        viewModel.meshService.stop()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            viewModel.meshService.start()
                        }
                    } label: {
                        Label("Restart network", systemImage: "arrow.clockwise")
                    }

                    Button {
                        viewModel.meshService.discoverNetwork()
                    } label: {
                        Label("Discover mesh topology", systemImage: "network")
                    }

                    Button {
                        viewModel.meshService.sendPing()
                    } label: {
                        Label("Send ping", systemImage: "wave.3.right")
                    }
                }
            }
            .navigationTitle("Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if !viewModel.meshService.isAdvertising {
                    viewModel.meshService.start()
                }
            }
        }
    }

    var statusColor: Color {
        switch viewModel.meshService.networkStatus {
        case .offline: return .secondary
        case .connecting: return .orange
        case .online: return .green
        }
    }

    var statusText: String {
        switch viewModel.meshService.networkStatus {
        case .offline: return "Offline"
        case .connecting: return "Connecting"
        case .online: return "Online"
        }
    }
}
