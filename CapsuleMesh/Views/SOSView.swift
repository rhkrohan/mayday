import SwiftUI
import UIKit

struct SOSView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @State private var showingSOSForm = false
    @State private var pulseScale: CGFloat = 1.0

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

                Spacer()

                // Emergency button section
                emergencySection

                Spacer()

                // Network status
                networkStatus
                    .padding(.bottom, 100)
            }
        }
        .onAppear {
            startPulse()
        }
        .sheet(isPresented: $showingSOSForm) {
            SOSFormSheet()
        }
    }

    private var header: some View {
        HStack {
            Spacer()

            HStack(spacing: 8) {
                MaydayLogoCompact(size: 22)
                Text("Emergency")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            }

            Spacer()
        }
    }

    private var emergencySection: some View {
        VStack(spacing: 32) {
            // Pulsing SOS button
            ZStack {
                // Outer pulse rings
                Circle()
                    .stroke(Color.red.opacity(0.1), lineWidth: 2)
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulseScale)

                Circle()
                    .stroke(Color.red.opacity(0.15), lineWidth: 2)
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulseScale * 0.95)

                // Main button
                Button {
                    showingSOSForm = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 140, height: 140)
                            .shadow(color: .red.opacity(0.3), radius: 20, y: 10)

                        VStack(spacing: 4) {
                            Image(systemName: "sos")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)

                            Text("SEND")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .buttonStyle(SOSButtonStyle())
            }

            // Description
            VStack(spacing: 8) {
                Text("Emergency broadcast")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)

                Text("Send an SOS alert to all nearby\ndevices on the Mayday network")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var networkStatus: some View {
        HStack(spacing: 12) {
            Image(systemName: "bird.fill")
                .font(.system(size: 16))
                .foregroundColor(.black)

            Circle()
                .fill(viewModel.meshService.networkStatus == .online ? Color.black : Color.black.opacity(0.3))
                .frame(width: 8, height: 8)

            Text(viewModel.meshService.networkStatus == .online
                 ? "\(viewModel.meshService.connectedPeers.count) devices connected"
                 : "No devices nearby")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.05))
        .clipShape(Capsule())
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }
}

struct SOSButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - SOS Form Sheet

struct SOSFormSheet: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @StateObject private var locationService = LocationService.shared
    @Environment(\.dismiss) var dismiss

    @State private var description = ""
    @State private var urgency = "high"
    @State private var showingConfirmation = false
    @State private var showingSentAlert = false

    let urgencyLevels = ["low", "medium", "high", "critical"]

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

                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        }

                        Text("Emergency SOS")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.red.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Location (auto-detected)
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
                                        .foregroundColor(.black)
                                    Text("Location detected automatically")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Detecting location...")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.black)
                                    Text("GPS coordinates will be sent with your alert")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if locationService.currentLocation != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                            } else {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(16)
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Battery level (auto-detected)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Battery status")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 12) {
                            Image(systemName: batteryIcon)
                                .font(.system(size: 18))
                                .foregroundColor(batteryColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(batteryLevel)%")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
                                Text("Battery level will be sent with your alert")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        .padding(16)
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Description (optional)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("What happened?")
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
                                Text("Describe the emergency (optional)...")
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
                        Text("Urgency level")
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

                    // Send button
                    Button {
                        showingConfirmation = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sos")
                                .font(.system(size: 18, weight: .bold))
                            Text("Send emergency alert")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 8)

                    // Warning text
                    Text("This will broadcast your GPS location and emergency details to all devices on the mesh network.")
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
            .alert("Send emergency alert?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Send SOS", role: .destructive) {
                    sendSOS()
                }
            } message: {
                Text("This will notify all \(viewModel.meshService.connectedPeers.count) connected devices.")
            }
            .alert("SOS sent", isPresented: $showingSentAlert) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your emergency alert has been broadcast to the Mayday network.")
            }
        }
        .onAppear {
            // Ensure location updates are running
            locationService.startUpdating()
        }
    }

    // MARK: - Battery Properties

    private var batteryLevel: Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        if level < 0 { return 0 }
        return Int(level * 100)
    }

    private var batteryIcon: String {
        let level = batteryLevel
        switch level {
        case 0..<20: return "battery.0"
        case 20..<50: return "battery.25"
        case 50..<75: return "battery.50"
        case 75..<100: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryColor: Color {
        let level = batteryLevel
        if level < 20 { return .red }
        if level < 50 { return .orange }
        return .black
    }

    private func urgencyColor(_ level: String) -> Color {
        switch level {
        case "low": return .black.opacity(0.6)
        case "medium": return .black.opacity(0.75)
        case "high": return .black.opacity(0.9)
        case "critical": return .red
        default: return .black
        }
    }

    private func sendSOS() {
        // Use GPS coordinates as location string, or "Unknown" if not available
        let locationString = locationService.locationString ?? "GPS unavailable"

        viewModel.meshService.sendSOS(
            location: locationString,
            description: description.isEmpty ? "Emergency SOS" : description,
            urgency: urgency
        )
        showingSentAlert = true
    }
}
