import SwiftUI

struct DirectMessageView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedDevice: String = ""
    @State private var message = ""
    @State private var showingSentAlert = false

    var knownDevices: [(id: String, hops: Int)] {
        viewModel.meshService.knownDevices.map { ($0.key, $0.value) }
            .sorted { $0.1 < $1.1 }
    }

    var body: some View {
        Form {
            recipientSection
            messageSection
            sendSection
        }
        .navigationTitle("Direct message")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Message sent", isPresented: $showingSentAlert) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your message has been sent through the mesh network.")
        }
    }

    private var recipientSection: some View {
        Section {
            if knownDevices.isEmpty {
                emptyDevicesView
            } else {
                deviceListView
            }
        } header: {
            Text("Select recipient")
        }
    }

    private var emptyDevicesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.title)
                .foregroundColor(.secondary)
            Text("No devices found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Discover network") {
                viewModel.meshService.discoverNetwork()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var deviceListView: some View {
        ForEach(knownDevices, id: \.id) { device in
            DeviceRowButton(
                device: device,
                isSelected: selectedDevice == device.id,
                onSelect: { selectedDevice = device.id }
            )
        }
    }

    private var messageSection: some View {
        Section("Message") {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $message)
                    .frame(minHeight: 80)
                if message.isEmpty {
                    Text("Write your message")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var sendSection: some View {
        Section {
            Button {
                sendDirectMessage()
            } label: {
                HStack {
                    Spacer()
                    Text("Send message")
                        .font(.headline)
                    Spacer()
                }
            }
            .disabled(selectedDevice.isEmpty || message.isEmpty)
        }
    }

    private func sendDirectMessage() {
        viewModel.meshService.sendDirectMessage(
            to: selectedDevice,
            content: message
        )
        showingSentAlert = true
    }
}

struct DeviceRowButton: View {
    let device: (id: String, hops: Int)
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(device.id.prefix(16)) + "...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("\(device.hops) hop\(device.hops == 1 ? "" : "s") away")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}
