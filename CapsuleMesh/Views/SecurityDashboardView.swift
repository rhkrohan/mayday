import SwiftUI

/// Security personnel mode — duty toggle, live incident feed, respond flow
struct SecurityDashboardView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @StateObject private var identity = DeviceIdentity.shared
    @State private var showingActivation = false
    @State private var activationCode = ""
    @State private var activationError = false
    @State private var selectedSecurityOrg: SecurityOrganization = .campusSecurity

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if identity.isSecurity {
                securityContent
            } else {
                activationPrompt
            }
        }
        .sheet(isPresented: $showingActivation) {
            activationSheet
        }
    }

    // MARK: - Security Content

    private var securityContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Security Dashboard")
                            .font(.system(size: 22, weight: .bold))
                        Text(identity.deviceName)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    dutyToggle
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Status Card
                statusCard.padding(.horizontal)

                // Active Incidents
                if !viewModel.meshService.activePanics.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Incidents")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        ForEach(viewModel.meshService.activePanics) { panic in
                            IncidentCard(panic: panic) {
                                viewModel.meshService.sendSecurityResponse(
                                    panicId: panic.id,
                                    estimatedArrival: "< 3 min"
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Recent alerts from message store
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Alerts")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)

                    let alertMessages = viewModel.messageStore.messages.filter { $0.type.isCritical }
                    if alertMessages.isEmpty {
                        EmptyStateView(
                            icon: "shield.checkered",
                            title: "No active alerts",
                            description: "You'll see incidents here when they're reported on the mesh"
                        )
                    } else {
                        ForEach(alertMessages.prefix(20)) { message in
                            MessageRow(message: message)
                                .padding(.horizontal)
                        }
                    }
                }

                Spacer(minLength: 120)
            }
        }
    }

    // MARK: - Duty Toggle

    private var dutyToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                if identity.dutyStatus == .onDuty {
                    identity.dutyStatus = .offDuty
                    viewModel.meshService.stopSecurityBroadcast()
                } else {
                    identity.dutyStatus = .onDuty
                    viewModel.meshService.startSecurityBroadcast()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(identity.dutyStatus == .onDuty ? MaydayBrand.safeGreen : Color.secondary)
                    .frame(width: 10, height: 10)
                Text(identity.dutyStatus == .onDuty ? "On Duty" : "Off Duty")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(identity.dutyStatus == .onDuty ? .white : .black)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(identity.dutyStatus == .onDuty ? MaydayBrand.securityBlue : Color.black.opacity(0.05))
            .clipShape(Capsule())
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack {
                StatBox(label: "Active Incidents", value: "\(viewModel.meshService.activePanics.count)", color: .red)
                StatBox(label: "On Duty Guards", value: "\(viewModel.meshService.onDutySecurityCount)", color: MaydayBrand.securityBlue)
                StatBox(label: "Mesh Nodes", value: "\(viewModel.meshService.connectedPeers.count)", color: .green)
            }

            if identity.dutyStatus == .onDuty {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(MaydayBrand.securityBlue)
                    Text("Your location is being shared with the mesh")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(MaydayBrand.securityBlue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Activation Prompt (for non-security users)

    private var activationPrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "shield.checkered")
                .font(.system(size: 60))
                .foregroundColor(MaydayBrand.securityBlue)

            Text("Security Mode")
                .font(.system(size: 24, weight: .bold))

            Text("Enter your organization's security code\nto activate Security Personnel mode")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingActivation = true
            } label: {
                Text("Activate Security Mode")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(MaydayBrand.securityBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)

            Text("Security codes are provided by your\norganization (e.g., SEC-DREXEL-001)")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Activation Sheet

    private var activationSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 40))
                    .foregroundColor(MaydayBrand.securityBlue)
                    .padding(.top, 20)

                Text("Enter Security Code")
                    .font(.system(size: 20, weight: .bold))

                TextField("e.g., SEC-DREXEL-001", text: $activationCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .padding(.horizontal)

                if activationError {
                    Text("Invalid code. Try SEC-, GUARD-, CAMPUS-, SEPTA-, PPD-, DREXEL-, PENN-, or TEMPLE-")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Security organization selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Department")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(SecurityOrganization.allCases) { org in
                            Button {
                                selectedSecurityOrg = org
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: org.icon)
                                    Text(org.shortName)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedSecurityOrg == org ? MaydayBrand.securityBlue : Color.black.opacity(0.05))
                                .foregroundColor(selectedSecurityOrg == org ? .white : .black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Skill selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Skills")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(UserSkill.allCases) { skill in
                            Button {
                                if identity.userSkills.contains(skill) {
                                    identity.userSkills.removeAll { $0 == skill }
                                } else {
                                    identity.userSkills.append(skill)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: skill.icon)
                                    Text(skill.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(identity.userSkills.contains(skill) ? MaydayBrand.securityBlue : Color.black.opacity(0.05))
                                .foregroundColor(identity.userSkills.contains(skill) ? .white : .black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Button {
                    if identity.activateSecurityRole(code: activationCode, securityOrg: selectedSecurityOrg) {
                        showingActivation = false
                        activationError = false
                    } else {
                        activationError = true
                    }
                } label: {
                    Text("Activate")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(activationCode.isEmpty ? Color.gray : MaydayBrand.securityBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(activationCode.isEmpty)
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { showingActivation = false }
                }
            }
        }
    }
}

// MARK: - Incident Card

struct IncidentCard: View {
    let panic: MeshNetworkService.ActivePanic
    let onRespond: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Severity indicator
                SeverityBadge(score: panic.severityScore)

                Spacer()

                Text(panic.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                if let type = panic.emergencyType {
                    let incident = IncidentType(rawValue: type)
                    Image(systemName: incident?.icon ?? "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(incident?.displayName ?? type.capitalized)
                        .font(.system(size: 15, weight: .semibold))
                }
            }

            Text("Reported by \(panic.senderName)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            if let desc = panic.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }

            // Stats row
            HStack(spacing: 16) {
                Label("\(panic.witnessCount) witnesses", systemImage: "eye.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)

                Label("\(panic.respondingGuards.count) responding", systemImage: "figure.run")
                    .font(.system(size: 12))
                    .foregroundColor(MaydayBrand.securityBlue)
            }

            // Respond button
            if panic.respondingGuards.isEmpty || !panic.respondingGuards.contains(DeviceIdentity.shared.deviceId) {
                Button {
                    onRespond()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                        Text("Respond to Incident")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MaydayBrand.securityBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("You are responding")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(MaydayBrand.safeGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(MaydayBrand.safeGreen.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
