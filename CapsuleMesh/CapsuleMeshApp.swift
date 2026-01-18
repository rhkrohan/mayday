import SwiftUI
import AVFoundation

@main
struct CapsuleMeshApp: App {
    @StateObject private var viewModel = MeshViewModel()
    @StateObject private var audioService = AudioRecordingService.shared
    @State private var hasCompletedOnboarding: Bool
    @State private var showingPostIncident = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Self.clearDataIfNewBuild()
        _hasCompletedOnboarding = State(initialValue: DeviceIdentity.shared.hasCompletedOnboarding)
        LocationService.shared.requestPermission()
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("Microphone permission: \(granted)")
        }
    }

    private static func clearDataIfNewBuild() {
        let buildKey = "CapsuleMesh.LastBuildNumber"
        let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let lastBuild = UserDefaults.standard.string(forKey: buildKey)

        if lastBuild != currentBuild {
            print("New build detected (\(lastBuild ?? "none") -> \(currentBuild)). Clearing data...")
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
                UserDefaults.standard.synchronize()
            }
            UserDefaults.standard.set(currentBuild, forKey: buildKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                        .environmentObject(viewModel)
                        .transition(.opacity)
                } else {
                    WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(.light)
            .onAppear {
                LocationService.shared.startUpdating()
                if audioService.hasPendingRecording && !audioService.isRecording {
                    showingPostIncident = true
                }
            }
            .sheet(isPresented: $showingPostIncident) {
                PostIncidentView()
                    .environmentObject(viewModel)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active && audioService.hasPendingRecording && !audioService.isRecording && !showingPostIncident {
                    showingPostIncident = true
                }
            }
            .onChange(of: audioService.isRecording) { isRecording in
                if !isRecording && audioService.hasPendingRecording && !showingPostIncident {
                    showingPostIncident = true
                }
            }
        }
    }
}
