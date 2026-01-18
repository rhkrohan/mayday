import AppIntents

// MARK: - Silent Panic Alert Intent (Action Button)

struct SendPanicAlertIntent: AppIntent {
    static let title: LocalizedStringResource = "Mayday Silent Alert"
    static let description: IntentDescription = "Records audio and sends emergency alert with transcript."

    // Must open app — iOS does not allow audio recording from background intents.
    // The app handles everything automatically with zero user interaction.
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Start recording + send panic — app will handle the rest automatically
        AudioRecordingService.shared.startSilentRecording()
        return .result()
    }
}

// MARK: - Shortcuts Provider

struct MaydayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendPanicAlertIntent(),
            phrases: [
                "Send alert with \(.applicationName)",
                "\(.applicationName) panic",
                "\(.applicationName) emergency",
                "\(.applicationName) help"
            ],
            shortTitle: "Silent Alert",
            systemImageName: "light.beacon.max.fill"
        )
    }
}
