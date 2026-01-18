import SwiftUI

struct PanicView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @State private var showingPanicForm = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                header.padding(.horizontal).padding(.top, 8)

                // Nearest security guard card
                if let guard_ = viewModel.meshService.nearestAvailableGuard {
                    NearestGuardCard(
                        guardName: guard_.name,
                        hops: guard_.hops,
                        dutyStatus: guard_.dutyStatus
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)
                }

                Spacer()
                emergencySection
                Spacer()
                networkStatus.padding(.bottom, 100)
            }
        }
        .onAppear { startPulse() }
        .sheet(isPresented: $showingPanicForm) {
            PanicFormSheet()
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "light.beacon.max.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                Text("Panic Alert")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            }
            Spacer()
        }
    }

    private var emergencySection: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .stroke(Color.red.opacity(0.1), lineWidth: 2)
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulseScale)

                Circle()
                    .stroke(Color.red.opacity(0.15), lineWidth: 2)
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulseScale * 0.95)

                Button {
                    showingPanicForm = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 140, height: 140)
                            .shadow(color: .red.opacity(0.3), radius: 20, y: 10)

                        VStack(spacing: 4) {
                            Image(systemName: "light.beacon.max.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            Text("PANIC")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .buttonStyle(SOSButtonStyle())
            }

            VStack(spacing: 8) {
                Text("Emergency Alert")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)

                Text("Alerts nearby security, mesh users,\nand the dispatch dashboard")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var networkStatus: some View {
        HStack(spacing: 12) {
            // Security count
            if viewModel.meshService.onDutySecurityCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 14))
                        .foregroundColor(MaydayBrand.securityBlue)
                    Text("\(viewModel.meshService.onDutySecurityCount) security")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MaydayBrand.securityBlue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(MaydayBrand.securityBlue.opacity(0.1))
                .clipShape(Capsule())
            }

            HStack(spacing: 6) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.black)

                Circle()
                    .fill(viewModel.meshService.networkStatus == .online ? Color.black : Color.black.opacity(0.3))
                    .frame(width: 6, height: 6)

                Text(viewModel.meshService.networkStatus == .online
                     ? "\(viewModel.meshService.connectedPeers.count) connected"
                     : "No devices nearby")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.05))
            .clipShape(Capsule())
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }
}

// MARK: - Panic Form Sheet

struct PanicFormSheet: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @StateObject private var locationService = LocationService.shared
    @Environment(\.dismiss) var dismiss

    @State private var description = ""
    @State private var emergencyType: IncidentType = .other
    @State private var urgency = "high"
    @State private var showingConfirmation = false
    @State private var showingSentAlert = false

    let urgencyLevels = ["medium", "high", "critical"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 64, height: 64)
                            Image(systemName: "light.beacon.max.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        }
                        Text("Panic Alert")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.red.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Emergency type
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What's happening?")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(IncidentType.allCases) { type in
                                Button {
                                    emergencyType = type
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 20))
                                        Text(type.displayName)
                                            .font(.system(size: 11, weight: .medium))
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(emergencyType == type ? Color.red : Color.black.opacity(0.05))
                                    .foregroundColor(emergencyType == type ? .white : .black)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your location")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 12) {
                            Image(systemName: locationService.isAuthorized ? "location.fill" : "location.slash")
                                .font(.system(size: 18))
                                .foregroundColor(locationService.isAuthorized ? .black : .black.opacity(0.4))

                            VStack(alignment: .leading, spacing: 2) {
                                if let coords = locationService.locationString {
                                    Text("GPS: \(coords)")
                                        .font(.system(size: 15, weight: .medium))
                                    Text("Location auto-attached")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Detecting location...")
                                        .font(.system(size: 15, weight: .medium))
                                }
                            }

                            Spacer()

                            if locationService.currentLocation != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                            } else {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                        .padding(16)
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Details")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Text("Optional")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.05))
                                .clipShape(Capsule())
                        }

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $description)
                                .font(.system(size: 16))
                                .frame(minHeight: 80)
                                .padding(12)

                            if description.isEmpty {
                                Text("Describe what's happening...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(16)
                                    .allowsHitTesting(false)
                            }
                        }
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Urgency
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Urgency")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 8) {
                            ForEach(urgencyLevels, id: \.self) { level in
                                Button {
                                    urgency = level
                                } label: {
                                    Text(level.capitalized)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(urgency == level ? .white : .black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(urgency == level ? urgencyColor(level) : Color.black.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    // Security info
                    if viewModel.meshService.onDutySecurityCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(MaydayBrand.securityBlue)
                            Text("\(viewModel.meshService.onDutySecurityCount) security personnel will be alerted")
                                .font(.system(size: 13))
                                .foregroundColor(MaydayBrand.securityBlue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(MaydayBrand.securityBlue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Send button
                    Button {
                        showingConfirmation = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "light.beacon.max.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Send Panic Alert")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 8)

                    Text("This will broadcast your location and emergency details to all devices on the mesh network and alert nearby security personnel.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
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
            .alert("Send panic alert?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Send Alert", role: .destructive) { sendPanic() }
            } message: {
                Text("This will alert \(viewModel.meshService.connectedPeers.count) connected devices and \(viewModel.meshService.onDutySecurityCount) security personnel.")
            }
            .alert("Alert Sent", isPresented: $showingSentAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your panic alert has been broadcast. Nearby security and mesh users have been notified.")
            }
        }
        .onAppear {
            locationService.startUpdating()
        }
    }

    private func urgencyColor(_ level: String) -> Color {
        switch level {
        case "medium": return .black.opacity(0.75)
        case "high": return .black.opacity(0.9)
        case "critical": return .red
        default: return .black
        }
    }

    private func sendPanic() {
        viewModel.meshService.sendPanic(
            description: description,
            emergencyType: emergencyType.rawValue,
            urgency: urgency
        )
        showingSentAlert = true
    }
}
