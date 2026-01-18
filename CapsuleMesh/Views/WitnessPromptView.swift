import SwiftUI

/// Overlay that appears when a nearby panic alert needs corroboration
struct WitnessPromptView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    let request: MeshNetworkService.WitnessRequest
    let onConfirm: (String?) -> Void
    let onDismiss: () -> Void

    @State private var note = ""
    @State private var showNoteField = false

    var body: some View {
        VStack(spacing: 0) {
            // Alert header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 44, height: 44)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Incident Reported Nearby")
                        .font(.system(size: 16, weight: .bold))
                    Text("\(request.senderName) — \(request.distance) hop\(request.distance == 1 ? "" : "s") away")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
            }
            .padding(16)

            Divider()

            // Incident details
            VStack(alignment: .leading, spacing: 12) {
                if let type = request.emergencyType {
                    HStack(spacing: 8) {
                        let incident = IncidentType(rawValue: type)
                        Image(systemName: incident?.icon ?? "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(incident?.displayName ?? type.capitalized)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }

                Text("Can you safely confirm this incident?")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text("Multiple confirmations help dispatchers prioritize the response.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))

                if showNoteField {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $note)
                            .font(.system(size: 14))
                            .frame(height: 60)
                            .padding(8)

                        if note.isEmpty {
                            Text("What can you see? (optional)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                    }
                    .background(Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(16)

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onDismiss()
                } label: {
                    Text("Can't Confirm")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if !showNoteField {
                    Button {
                        showNoteField = true
                    } label: {
                        Text("Add Note")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                Button {
                    onConfirm(note.isEmpty ? nil : note)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Confirm")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .padding(.horizontal, 16)
    }
}

/// Floating witness request overlay manager
struct WitnessOverlay: View {
    @EnvironmentObject var viewModel: MeshViewModel

    var body: some View {
        VStack {
            Spacer()

            if let request = viewModel.meshService.pendingWitnessRequests.first(where: { !$0.isExpired }) {
                WitnessPromptView(
                    request: request,
                    onConfirm: { note in
                        viewModel.meshService.sendWitnessConfirmation(panicId: request.id, note: note)
                    },
                    onDismiss: {
                        viewModel.meshService.dismissWitnessRequest(panicId: request.id)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 100) // Above tab bar
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.meshService.pendingWitnessRequests.count)
    }
}
