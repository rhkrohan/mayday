import SwiftUI

/// Shows when the user opens the app after a silent Action Button recording.
/// Prompts for suspect appearance, details, and sends to dashboard.
struct PostIncidentView: View {
    @StateObject private var audioService = AudioRecordingService.shared
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var suspectDescription = ""
    @State private var numberOfPeople = ""
    @State private var weaponsMentioned = false
    @State private var additionalDetails = ""
    @State private var suspectClothing = ""
    @State private var suspectDirection = ""
    @State private var showingSubmitted = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Alert banner
                    alertBanner

                    // Recording info
                    if audioService.isRecording {
                        recordingIndicator
                    } else if let timestamp = audioService.pendingRecordingTimestamp {
                        recordingCompleted(timestamp: timestamp)
                    }

                    // Audio transcript
                    if audioService.isTranscribing {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Transcribing audio...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Transcription failed — show retry
                    if audioService.transcriptionFailed {
                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Transcription failed")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            Text("Check your network connection and try again.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Button {
                                audioService.retryTranscription()
                            } label: {
                                Text("Retry Transcription")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let transcript = audioService.pendingTranscript, !transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.blue)
                                Text("AUDIO TRANSCRIPT")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }

                            Text(transcript)
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                                )
                        }
                    }

                    // Suspect appearance
                    formSection(title: "SUSPECT DESCRIPTION") {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $suspectDescription)
                                .font(.system(size: 16))
                                .frame(minHeight: 80)
                                .padding(12)

                            if suspectDescription.isEmpty {
                                Text("Height, build, skin color, hair, distinguishing features...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(16)
                                    .allowsHitTesting(false)
                            }
                        }
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Clothing
                    formSection(title: "CLOTHING") {
                        TextField("What were they wearing?", text: $suspectClothing)
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Direction of travel
                    formSection(title: "DIRECTION OF TRAVEL") {
                        TextField("Which way did they go?", text: $suspectDirection)
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Number of people
                    formSection(title: "NUMBER OF PEOPLE") {
                        TextField("How many people involved?", text: $numberOfPeople)
                            .keyboardType(.numberPad)
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Weapons
                    Toggle(isOn: $weaponsMentioned) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Weapons involved")
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                    .padding(16)
                    .background(weaponsMentioned ? Color.red.opacity(0.05) : Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Additional details
                    formSection(title: "ANYTHING ELSE") {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $additionalDetails)
                                .font(.system(size: 16))
                                .frame(minHeight: 60)
                                .padding(12)

                            if additionalDetails.isEmpty {
                                Text("Any other details that could help...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(16)
                                    .allowsHitTesting(false)
                            }
                        }
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Submit — only enabled when transcript is available
                    Button {
                        submitReport()
                    } label: {
                        HStack(spacing: 8) {
                            if audioService.isRecording || audioService.isTranscribing {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                                Text(audioService.isRecording ? "Recording..." : "Transcribing...")
                            } else if audioService.transcriptionFailed {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Submit without transcript")
                            } else if audioService.pendingTranscript == nil {
                                Image(systemName: "waveform")
                                Text("Waiting for transcript...")
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Send to Dashboard")
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(audioService.pendingTranscript != nil ? Color.red : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(audioService.pendingTranscript == nil && !audioService.transcriptionFailed)

                    if audioService.pendingTranscript == nil && !audioService.transcriptionFailed {
                        Text("The audio transcript must be ready before you can submit the report.")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }

                    // Skip
                    Button {
                        audioService.dismissPendingIncident()
                        dismiss()
                    } label: {
                        Text("Skip for now")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Text("Your emergency alert was already sent. This additional info helps security respond better.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Complete Report")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
            }
            .alert("Report Submitted", isPresented: $showingSubmitted) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your incident details have been sent to the dispatch dashboard. Stay safe.")
            }
            .onAppear {
                // If recording is still running when user opens this form,
                // stop it so Whisper transcription starts immediately
                if audioService.isRecording {
                    audioService.stopRecording()
                }
                // If recording already stopped but no transcript yet, upload now
                if !audioService.isRecording, audioService.pendingTranscript == nil,
                   audioService.pendingAudioFilePath != nil {
                    audioService.uploadAudioNow()
                }
            }
        }
    }

    // MARK: - Components

    private var alertBanner: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 56, height: 56)
                Image(systemName: "light.beacon.max.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            Text("Emergency Alert Active")
                .font(.system(size: 20, weight: .bold))

            Text("An alert was sent from your Action Button.\nHelp us with more details about what happened.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var recordingIndicator: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(0.8)

            Text("Recording audio — \(Int(audioService.recordingDuration))s")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.red)

            Spacer()

            Button {
                audioService.stopRecording()
            } label: {
                Text("Stop")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func recordingCompleted(timestamp: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 18))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Audio recorded")
                    .font(.system(size: 14, weight: .semibold))
                Text(timestamp, style: .relative)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(16)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
    }

    private func submitReport() {
        let fullDescription = [
            suspectDescription.isEmpty ? nil : "Appearance: \(suspectDescription)",
            suspectClothing.isEmpty ? nil : "Clothing: \(suspectClothing)",
            suspectDirection.isEmpty ? nil : "Direction: \(suspectDirection)",
            additionalDetails.isEmpty ? nil : additionalDetails
        ].compactMap { $0 }.joined(separator: ". ")

        audioService.completePendingIncident(
            suspectDescription: suspectDescription + (suspectClothing.isEmpty ? "" : ", wearing \(suspectClothing)"),
            numberOfPeople: Int(numberOfPeople),
            weaponsMentioned: weaponsMentioned,
            additionalDetails: fullDescription
        )

        showingSubmitted = true
    }
}
