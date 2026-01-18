import SwiftUI

struct TriageView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var patientName = ""
    @State private var age = ""
    @State private var condition = "stable"
    @State private var injuries = ""
    @State private var isConscious = true
    @State private var isBreathing = true
    @State private var showingSentAlert = false

    let conditions = ["stable", "serious", "critical", "unknown"]

    var body: some View {
        Form {
            Section("Patient information") {
                TextField("Patient name", text: $patientName)
                TextField("Age", text: $age)
                    .keyboardType(.numberPad)
            }

            Section("Condition") {
                Picker("Status", selection: $condition) {
                    ForEach(conditions, id: \.self) { cond in
                        HStack {
                            Circle()
                                .fill(conditionColor(cond))
                                .frame(width: 8, height: 8)
                            Text(cond.capitalized)
                        }
                        .tag(cond)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Vital signs") {
                Toggle("Conscious", isOn: $isConscious)
                Toggle("Breathing", isOn: $isBreathing)
            }

            Section("Injuries") {
                TextEditor(text: $injuries)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if injuries.isEmpty {
                            Text("Describe injuries or notes")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section {
                Button {
                    sendTriage()
                } label: {
                    HStack {
                        Spacer()
                        Text("Send triage report")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(patientName.isEmpty)
            }
        }
        .navigationTitle("Medical triage")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Report sent", isPresented: $showingSentAlert) {
            Button("Done") { dismiss() }
        } message: {
            Text("Triage report has been broadcast to the mesh network.")
        }
    }

    func conditionColor(_ condition: String) -> Color {
        switch condition {
        case "stable": return .green
        case "serious": return .orange
        case "critical": return .red
        default: return .secondary
        }
    }

    private func sendTriage() {
        viewModel.meshService.sendTriage(
            patientName: patientName,
            age: Int(age) ?? 0,
            condition: condition,
            injuries: injuries,
            conscious: isConscious,
            breathing: isBreathing
        )
        showingSentAlert = true
    }
}
