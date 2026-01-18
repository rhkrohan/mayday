import SwiftUI

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var userName = ""
    @State private var selectedOrganization: Organization? = nil
    @State private var currentPage = 0
    @FocusState private var isNameFieldFocused: Bool

    private let totalPages = 4

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    organizationPage.tag(2)
                    namePage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomSection
            }
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        .frame(width: 200, height: 200)
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        .frame(width: 160, height: 160)
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        .frame(width: 120, height: 120)

                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 80, height: 80)
                        Image(systemName: "light.beacon.max.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                VStack(spacing: 8) {
                    Text("Mayday")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Text("Community safety mesh network")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                Text("Safety in numbers")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                Text("A mesh network that connects you with\nnearby people and security personnel")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Features Page

    private var featuresPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("How it works")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)

            VStack(spacing: 20) {
                FeatureRow(
                    icon: "light.beacon.max.fill",
                    title: "Panic Alert",
                    description: "One tap broadcasts an alert to nearby devices and security guards"
                )
                FeatureRow(
                    icon: "shield.checkered",
                    title: "Security Network",
                    description: "See nearby security personnel and get help fast"
                )
                FeatureRow(
                    icon: "eye.fill",
                    title: "Witness Mesh",
                    description: "Confirm incidents nearby to help dispatchers prioritize"
                )
                FeatureRow(
                    icon: "map.fill",
                    title: "Incident Map",
                    description: "See what's happening around you in real time"
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Organization Page

    private var organizationPage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 80, height: 80)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }

                Text("Your Community")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)

                Text("Select your university or area to join\nyour local safety network")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Organization grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Organization.allCases) { org in
                    OrgPickerCard(
                        org: org,
                        isSelected: selectedOrganization == org
                    ) {
                        withAnimation(.spring(response: 0.2)) {
                            selectedOrganization = org
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Name Page

    private var namePage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 80, height: 80)
                    Image(systemName: "person.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }

                Text("What's your name?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)

                Text("This will be shown to others on the network")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                TextField("Enter your name", text: $userName)
                    .font(.system(size: 18))
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .background(Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .focused($isNameFieldFocused)

                Text("You can change this later in Settings")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFieldFocused = true
            }
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 20) {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? Color.black : Color.black.opacity(0.2))
                        .frame(width: currentPage == index ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            // Button
            Button {
                if currentPage < totalPages - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentPage += 1
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(buttonText)
                        .font(.system(size: 17, weight: .semibold))
                    if currentPage < totalPages - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(canContinue ? Color.black : Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)

            // Skip button
            if currentPage < 2 {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentPage = 2
                    }
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else {
                Text(" ").font(.system(size: 15))
            }
        }
        .padding(.bottom, 40)
    }

    private var buttonText: String {
        switch currentPage {
        case 0: return "Get Started"
        case 1: return "Continue"
        case 2: return selectedOrganization == nil ? "Select your community" : "Continue"
        case 3: return userName.isEmpty ? "Enter your name" : "Start using Mayday"
        default: return "Continue"
        }
    }

    private var canContinue: Bool {
        switch currentPage {
        case 2: return selectedOrganization != nil
        case 3: return !userName.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private func completeOnboarding() {
        let trimmedName = userName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            DeviceIdentity.shared.deviceName = trimmedName
        }
        DeviceIdentity.shared.organization = selectedOrganization ?? .community
        DeviceIdentity.shared.hasCompletedOnboarding = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Org Picker Card

struct OrgPickerCard: View {
    let org: Organization
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: org.icon)
                    .font(.system(size: 24))
                Text(org.shortName)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.black : Color.black.opacity(0.04))
            .foregroundColor(isSelected ? .white : .black)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.black : Color.clear, lineWidth: 2)
            )
        }
    }

    private var subtitle: String {
        org == .community ? "General Philly" : org.displayName
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
