import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @StateObject private var identity = DeviceIdentity.shared
    @StateObject private var audioService = AudioRecordingService.shared
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // Content
            Group {
                switch selectedTab {
                case 0:
                    MessagesView()
                case 1:
                    NetworkMapView()
                case 2:
                    PanicView()
                case 3:
                    if identity.isSecurity {
                        SecurityDashboardView()
                    } else {
                        IncidentMapView()
                    }
                case 4:
                    SettingsView()
                default:
                    MessagesView()
                }
            }

            // Witness prompt overlay
            WitnessOverlay()

            // Active recording overlay — allows ending the action button early
            if audioService.isRecording {
                RecordingOverlay()
            }

            // Floating Tab Bar
            VStack {
                Spacer()
                FloatingTabBar(selectedTab: $selectedTab, isSecurity: identity.isSecurity)
                    .padding(.bottom, 8)
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Recording Overlay (stop action button early)

struct RecordingOverlay: View {
    @StateObject private var audioService = AudioRecordingService.shared
    @State private var pulse = false

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                // Recording indicator
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulse ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recording in progress")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(Int(audioService.recordingDuration))s / 15s")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Stop button
                Button {
                    audioService.stopRecording()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("End & Transcribe")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.9))
                    .shadow(color: .red.opacity(0.3), radius: 12, y: 4)
            )
            .padding(.horizontal, 16)
            .padding(.top, 60)

            Spacer()
        }
        .onAppear { pulse = true }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.4), value: audioService.isRecording)
    }
}

// MARK: - Floating Tab Bar

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    var isSecurity: Bool = false

    private var tabs: [(icon: String, label: String, isEmergency: Bool, isSecurity: Bool)] {
        [
            ("message.fill", "Feed", false, false),
            ("point.3.connected.trianglepath.dotted", "Mesh", false, false),
            ("light.beacon.max.fill", "Panic", true, false),
            (isSecurity ? "shield.checkered" : "mappin.and.ellipse",
             isSecurity ? "Duty" : "Incidents", false, isSecurity),
            ("gearshape.fill", "Settings", false, false)
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabBarButton(
                    icon: tabs[index].icon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index,
                    isEmergency: tabs[index].isEmergency,
                    isSecurity: tabs[index].isSecurity
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        )
        .padding(.horizontal, 24)
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let isEmergency: Bool
    var isSecurity: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(selectedBackground)
                            .frame(width: 56, height: 32)
                    }

                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 18 : 16, weight: .medium))
                        .foregroundColor(iconColor)
                }
                .frame(height: 32)

                if isSelected {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(labelColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(TabButtonStyle())
    }

    private var selectedBackground: Color {
        if isEmergency { return Color.red.opacity(0.2) }
        if isSecurity { return MaydayBrand.securityBlue.opacity(0.3) }
        return Color.white.opacity(0.15)
    }

    private var iconColor: Color {
        if isSelected {
            if isEmergency { return .red }
            if isSecurity { return MaydayBrand.securityBlue }
            return .white
        }
        if isEmergency { return .red.opacity(0.6) }
        if isSecurity { return MaydayBrand.securityBlue.opacity(0.6) }
        return .white.opacity(0.5)
    }

    private var labelColor: Color {
        if isEmergency { return .red }
        if isSecurity { return MaydayBrand.securityBlue }
        return .white
    }
}

struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
