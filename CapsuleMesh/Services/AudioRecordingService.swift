import Foundation
import AVFoundation
import UIKit
import Combine

/// Handles silent background audio recording for emergency incidents.
/// When triggered via Action Button, records audio without opening the app,
/// saves locally, and auto-reports the incident.
class AudioRecordingService: NSObject, ObservableObject {
    static let shared = AudioRecordingService()

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasPendingRecording = false  // True if user needs to complete post-incident form

    // Stored incident data from the silent recording
    @Published var pendingIncidentPanicId: String?
    @Published var pendingAudioFilePath: String?
    @Published var pendingRecordingTimestamp: Date?
    @Published var pendingTranscript: String?
    @Published var isTranscribing = false
    @Published var transcriptionFailed = false

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var durationTimer: Timer?

    private let maxRecordingDuration: TimeInterval = 15  // 15 seconds — short so background upload has time
    private let recordingsDirectory: URL
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    var isBackgroundAutoFire = false  // true when triggered outside app — auto-submit on transcript

    // UserDefaults keys for persistence across app launches
    private let pendingRecordingKey = "Mayday.PendingRecording"
    private let pendingPanicIdKey = "Mayday.PendingPanicId"
    private let pendingAudioPathKey = "Mayday.PendingAudioPath"
    private let pendingTimestampKey = "Mayday.PendingTimestamp"
    private let pendingTranscriptKey = "Mayday.PendingTranscript"

    private override init() {
        // Create recordings directory
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        recordingsDirectory = docs.appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)

        super.init()
        loadPendingState()
    }

    // MARK: - Start Silent Recording

    /// Called from AppIntent — starts recording without any UI
    func startSilentRecording() {
        // If already recording, stop early (action button toggles)
        guard !isRecording else {
            stopRecording()
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
            // Still send panic even if recording fails
            sendSilentPanic(audioPath: nil)
            return
        }

        // Check microphone permission — request if undetermined
        if session.recordPermission == .undetermined {
            session.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startSilentRecording()  // Retry now that we have permission
                    } else {
                        self?.sendSilentPanic(audioPath: nil)
                    }
                }
            }
            return
        }
        guard session.recordPermission == .granted else {
            sendSilentPanic(audioPath: nil)
            return
        }

        // Create unique filename
        let timestamp = Date()
        let filename = "incident_\(Int(timestamp.timeIntervalSince1970)).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            recordingDuration = 0

            // Detect if we're in background — if so, auto-fire report after transcription
            let appState = UIApplication.shared.applicationState
            isBackgroundAutoFire = (appState != .active)

            // Request background time — covers recording (15s) + upload (~5s)
            backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "MaydayRecording") { [weak self] in
                // iOS forcing expiry — stop and fire what we have
                if self?.isRecording == true {
                    self?.stopRecording()
                }
                self?.endBackgroundTask()
            }

            // Track duration
            durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.recordingDuration += 1
            }

            // Auto-stop after max duration — uses record(forDuration:) as a backup
            // since Timer may not fire in background
            audioRecorder?.record(forDuration: maxRecordingDuration)
            recordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
                self?.stopRecording()
            }

            // Send panic immediately with the audio path
            sendSilentPanic(audioPath: fileURL.path)

            // Haptic: 2 quick taps = recording started
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            print("Silent recording started: \(filename)")

        } catch {
            print("Failed to start recording: \(error)")
            sendSilentPanic(audioPath: nil)
        }
    }

    // MARK: - Stop Recording

    func stopRecording() {
        guard isRecording else { return }

        // Capture audio path from the recorder itself (not the async-set property)
        let audioPath = audioRecorder?.url.path ?? pendingAudioFilePath

        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Haptic: 2 taps = recording stopped
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            generator.notificationOccurred(.warning)
        }

        print("Silent recording stopped. Duration: \(Int(recordingDuration))s")

        if isBackgroundAutoFire {
            // Background mode: embed audio in message and auto-submit via gateway sync
            // No separate Whisper upload — server handles transcription from base64
            autoSubmitReport(transcript: nil)
        } else if let path = audioPath {
            // Foreground mode: upload to Whisper, show transcript to user
            transcribeAudio(filePath: path)
        }
    }

    /// Uploads the audio file now, regardless of recording state.
    /// Called when user submits report early or when we need to force-push audio.
    func uploadAudioNow() {
        // Stop recording first if still active
        if isRecording {
            stopRecording()  // This will trigger transcribeAudio
            return
        }

        // Not recording — upload existing file if it hasn't been transcribed yet
        if let path = pendingAudioFilePath, pendingTranscript == nil {
            transcribeAudio(filePath: path)
        }
    }

    // MARK: - Whisper Transcription (server-side via OpenAI)
    // Uploads audio → gets transcript back → saves locally.
    // Does NOT push to dashboard. User must submit the report first.

    private func transcribeAudio(filePath: String) {
        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("Audio file not found for transcription: \(filePath)")
            transcriptionFailed = true
            return
        }

        DispatchQueue.main.async {
            self.isTranscribing = true
            self.transcriptionFailed = false
        }

        let endpoint = GatewayService.shared.apiEndpoint
            .replacingOccurrences(of: "/api/messages", with: "/api/transcribe")

        guard let url = URL(string: endpoint) else {
            print("Invalid transcribe endpoint: \(endpoint)")
            DispatchQueue.main.async {
                self.isTranscribing = false
                self.transcriptionFailed = true
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("Failed to read audio file data")
            DispatchQueue.main.async {
                self.isTranscribing = false
                self.transcriptionFailed = true
            }
            return
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        print("Uploading \(audioData.count / 1024)KB audio to Whisper at \(endpoint)...")

        // Use background URLSession configuration so upload continues when app is suspended
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isTranscribing = false

                if let error = error {
                    print("Whisper upload failed: \(error.localizedDescription)")
                    self?.transcriptionFailed = true
                    self?.endBackgroundTask()
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("Whisper server error: HTTP \(httpResponse.statusCode)")
                    self?.transcriptionFailed = true
                    self?.endBackgroundTask()
                    return
                }

                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let transcript = json["transcript"] as? String, !transcript.isEmpty {
                    self?.pendingTranscript = transcript
                    self?.transcriptionFailed = false
                    self?.savePendingState()
                    print("Whisper transcript received: \(transcript)")

                    // AUTO-FIRE: If triggered outside app, send report to dashboard immediately
                    if self?.isBackgroundAutoFire == true {
                        self?.autoSubmitReport(transcript: transcript)
                    }
                } else {
                    print("Whisper: no transcript in response")
                    if let data = data, let raw = String(data: data, encoding: .utf8) {
                        print("Whisper raw: \(raw)")
                    }
                    self?.transcriptionFailed = true

                    // Even if transcription failed, auto-fire what we have
                    if self?.isBackgroundAutoFire == true {
                        self?.autoSubmitReport(transcript: nil)
                    }
                }
                self?.endBackgroundTask()
            }
        }.resume()
    }

    /// Called by AppIntent when background transcription didn't complete in time.
    /// Forces sending the audio via gateway sync with base64.
    func forceAutoSubmit() {
        if pendingAudioFilePath != nil {
            autoSubmitReport(transcript: pendingTranscript)
        }
    }

    func retryTranscription() {
        transcriptionFailed = false
        if let path = pendingAudioFilePath ?? audioRecorder?.url.path {
            transcribeAudio(filePath: path)
        }
    }

    // MARK: - Silent Panic

    private func sendSilentPanic(audioPath: String?) {
        let panicId = UUID().uuidString
        let timestamp = Date()

        // Save pending state so when user opens app, we can prompt for details
        pendingIncidentPanicId = panicId
        pendingAudioFilePath = audioPath
        pendingRecordingTimestamp = timestamp
        hasPendingRecording = true
        savePendingState()

        // Send the panic via mesh IMMEDIATELY — use the same panicId so transcript links correctly
        DispatchQueue.main.async {
            MeshNetworkService.shared.sendPanic(
                description: "Silent emergency alert — audio recording in progress",
                emergencyType: "robbery",
                urgency: "critical",
                existingPanicId: panicId
            )

            // Force sync to dashboard RIGHT NOW — don't wait for the 30s timer
            GatewayService.shared.syncMessages()
        }
    }

    // MARK: - Post-Incident Completion

    /// Called when user submits the post-incident report.
    /// Transcript MUST be available before this is called.
    /// Sends the full report (with transcript) to the dashboard.
    func completePendingIncident(
        suspectDescription: String,
        numberOfPeople: Int?,
        weaponsMentioned: Bool,
        additionalDetails: String
    ) {
        let panicId = pendingIncidentPanicId
        let transcript = pendingTranscript
        guard panicId != nil else { return }

        // Send incident report WITH transcript and panicId to dashboard
        DispatchQueue.main.async {
            MeshNetworkService.shared.sendIncidentReport(
                incidentType: "robbery",
                description: additionalDetails,
                numberOfPeople: numberOfPeople,
                weaponsMentioned: weaponsMentioned,
                suspectDescription: suspectDescription.isEmpty ? nil : suspectDescription,
                audioTranscript: transcript,
                panicId: panicId
            )

            // Force sync to dashboard immediately
            GatewayService.shared.syncMessages()
        }

        // Clear pending state — audio file stays on device
        clearPendingState()
    }

    /// Dismiss without completing the form
    func dismissPendingIncident() {
        clearPendingState()
    }

    // MARK: - Persistence

    private func savePendingState() {
        UserDefaults.standard.set(true, forKey: pendingRecordingKey)
        UserDefaults.standard.set(pendingIncidentPanicId, forKey: pendingPanicIdKey)
        UserDefaults.standard.set(pendingAudioFilePath, forKey: pendingAudioPathKey)
        UserDefaults.standard.set(pendingTranscript, forKey: pendingTranscriptKey)
        if let ts = pendingRecordingTimestamp {
            UserDefaults.standard.set(ts.timeIntervalSince1970, forKey: pendingTimestampKey)
        }
    }

    private func loadPendingState() {
        hasPendingRecording = UserDefaults.standard.bool(forKey: pendingRecordingKey)
        pendingIncidentPanicId = UserDefaults.standard.string(forKey: pendingPanicIdKey)
        pendingAudioFilePath = UserDefaults.standard.string(forKey: pendingAudioPathKey)
        pendingTranscript = UserDefaults.standard.string(forKey: pendingTranscriptKey)
        let ts = UserDefaults.standard.double(forKey: pendingTimestampKey)
        if ts > 0 {
            pendingRecordingTimestamp = Date(timeIntervalSince1970: ts)
        }
    }

    private func clearPendingState() {
        hasPendingRecording = false
        pendingIncidentPanicId = nil
        pendingAudioFilePath = nil
        pendingRecordingTimestamp = nil
        pendingTranscript = nil
        transcriptionFailed = false
        UserDefaults.standard.removeObject(forKey: pendingRecordingKey)
        UserDefaults.standard.removeObject(forKey: pendingPanicIdKey)
        UserDefaults.standard.removeObject(forKey: pendingAudioPathKey)
        UserDefaults.standard.removeObject(forKey: pendingTimestampKey)
        UserDefaults.standard.removeObject(forKey: pendingTranscriptKey)
    }

    // MARK: - Audio File Management

    /// Auto-submits the incident report with embedded audio to the dashboard.
    /// Called when recording was triggered outside the app (Action Button background).
    /// Stores directly in MessageStore (bypasses MeshNetworkService.sendMessage which
    /// requires connected peers — in background there are none).
    private func autoSubmitReport(transcript: String?) {
        let panicId = pendingIncidentPanicId
        let audioPath = pendingAudioFilePath

        // Encode audio file as base64 so it travels with the normal gateway sync
        var audioBase64: String? = nil
        if let path = audioPath, let audioData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            audioBase64 = audioData.base64EncodedString()
            print("Auto-fire: embedded \(audioData.count / 1024)KB audio as base64")
        }

        print("Auto-firing report to dashboard (background). Transcript: \(transcript != nil ? "yes" : "no"), Audio: \(audioBase64 != nil ? "yes" : "no")")

        let coords = LocationService.shared.getCurrentLocation()
        let data = MessageData(
            latitude: coords?.latitude,
            longitude: coords?.longitude,
            description: transcript ?? "Silent emergency alert — audio captured",
            emergencyType: "robbery",
            severityScore: 7,
            audioTranscript: transcript,
            audioBase64: audioBase64,
            panicId: panicId
        )
        let msg = MeshMessage(
            type: .incidentReport,
            data: data,
            senderId: DeviceIdentity.shared.deviceId,
            senderName: DeviceIdentity.shared.deviceName,
            senderRole: DeviceIdentity.shared.userRole
        )

        // Store DIRECTLY in MessageStore — do NOT use sendMessage() which requires
        // connected MultipeerConnectivity peers (none exist in background)
        _ = MessageStore.shared.addMessage(msg)

        // Force sync to dashboard NOW
        GatewayService.shared.syncMessages()

        isBackgroundAutoFire = false
        clearPendingState()
    }

    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }

    /// Get the URL for a recorded audio file
    func audioFileURL(for path: String) -> URL? {
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: path) ? url : nil
    }

    /// Delete old recordings (keep last 10)
    func cleanupOldRecordings() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }

        let sorted = files.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return dateA > dateB
        }

        // Keep only the latest 10
        for file in sorted.dropFirst(10) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            if flag && self.isRecording {
                // record(forDuration:) finished naturally — trigger full stop + transcription
                print("Recording finished (duration limit reached)")
                self.stopRecording()
            } else if !flag {
                self.isRecording = false
                print("Audio recording failed")
                self.endBackgroundTask()
            }
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            print("Audio encoding error: \(error?.localizedDescription ?? "unknown")")
        }
    }
}
