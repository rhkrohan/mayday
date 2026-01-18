import SwiftUI

struct BroadcastView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var message = ""
    @State private var priority = "normal"
    @State private var showingSentAlert = false

    let priorities = ["low", "normal", "high", "urgent"]

    var body: some View {
        Form {
            Section("Message") {
                TextField("Title", text: $title)
                TextEditor(text: $message)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Message content")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section("Priority") {
                Picker("Priority level", selection: $priority) {
                    ForEach(priorities, id: \.self) { p in
                        Text(p.capitalized).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button {
                    sendBroadcast()
                } label: {
                    HStack {
                        Spacer()
                        Text("Send broadcast")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(title.isEmpty || message.isEmpty)
            } footer: {
                Text("This message will be sent to all devices on the mesh network.")
            }
        }
        .navigationTitle("Broadcast")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Broadcast sent", isPresented: $showingSentAlert) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your message has been sent to the mesh network.")
        }
    }

    private func sendBroadcast() {
        viewModel.meshService.sendBroadcast(
            title: title,
            message: message,
            priority: priority
        )
        showingSentAlert = true
    }
}
