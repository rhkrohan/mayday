import SwiftUI

struct IncidentReportView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var incidentType: IncidentType = .other
    @State private var description = ""
    @State private var numberOfPeople = ""
    @State private var weaponsMentioned = false
    @State private var suspectDescription = ""
    @State private var showingSentAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.1))
                        Text("Report an Incident")
                            .font(.system(size: 20, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.orange.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Incident type
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Incident Type")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(IncidentType.allCases) { type in
                                Button {
                                    incidentType = type
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 20))
                                        Text(type.displayName)
                                            .font(.system(size: 11, weight: .medium))
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(incidentType == type ? Color(red: 0.9, green: 0.3, blue: 0.1) : Color.black.opacity(0.05))
                                    .foregroundColor(incidentType == type ? .white : .black)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What happened?")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $description)
                                .font(.system(size: 16))
                                .frame(minHeight: 80)
                                .padding(12)

                            if description.isEmpty {
                                Text("Describe what you witnessed...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(16)
                                    .allowsHitTesting(false)
                            }
                        }
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Number of people
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of people involved")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        TextField("e.g., 2", text: $numberOfPeople)
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

                    // Suspect description
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Suspect Description")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Text("Optional")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.05))
                                .clipShape(Capsule())
                        }

                        TextField("Physical description, clothing, direction of travel...", text: $suspectDescription)
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Submit
                    Button {
                        submitReport()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.shield.fill")
                            Text("Submit Report")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(description.isEmpty ? Color.gray : Color(red: 0.9, green: 0.3, blue: 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(description.isEmpty)
                }
                .padding()
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
            }
            .alert("Report Submitted", isPresented: $showingSentAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your incident report has been broadcast to the mesh network.")
            }
        }
    }

    private func submitReport() {
        viewModel.meshService.sendIncidentReport(
            incidentType: incidentType.rawValue,
            description: description,
            numberOfPeople: Int(numberOfPeople),
            weaponsMentioned: weaponsMentioned,
            suspectDescription: suspectDescription.isEmpty ? nil : suspectDescription
        )
        showingSentAlert = true
    }
}
