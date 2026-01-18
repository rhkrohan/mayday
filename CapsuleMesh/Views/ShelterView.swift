import SwiftUI

struct ShelterView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var shelterName = ""
    @State private var capacity = ""
    @State private var currentOccupancy = ""
    @State private var acceptingMore = true
    @State private var supplies: Set<String> = []
    @State private var showingSentAlert = false

    let availableSupplies: [String] = ["Water", "Food", "Medical", "Blankets", "Power", "First Aid"]

    var body: some View {
        Form {
            Section("Shelter information") {
                TextField("Shelter name or location", text: $shelterName)
            }

            Section("Capacity") {
                TextField("Maximum capacity", text: $capacity)
                    .keyboardType(.numberPad)
                TextField("Current occupancy", text: $currentOccupancy)
                    .keyboardType(.numberPad)
                Toggle("Accepting more people", isOn: $acceptingMore)
            }

            Section("Available supplies") {
                ForEach(Array(availableSupplies), id: \.self) { supply in
                    Button {
                        if supplies.contains(supply) {
                            supplies.remove(supply)
                        } else {
                            supplies.insert(supply)
                        }
                    } label: {
                        HStack {
                            Text(supply)
                                .foregroundColor(.primary)
                            Spacer()
                            if supplies.contains(supply) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    sendShelterStatus()
                } label: {
                    HStack {
                        Spacer()
                        Text("Update shelter status")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(shelterName.isEmpty)
            }
        }
        .navigationTitle("Shelter status")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Status sent", isPresented: $showingSentAlert) {
            Button("Done") { dismiss() }
        } message: {
            Text("Shelter status has been broadcast to the mesh network.")
        }
    }

    private func sendShelterStatus() {
        viewModel.meshService.sendShelterStatus(
            name: shelterName,
            capacity: Int(capacity) ?? 0,
            currentOccupancy: Int(currentOccupancy) ?? 0,
            supplies: Array(supplies),
            acceptingMore: acceptingMore
        )
        showingSentAlert = true
    }
}
