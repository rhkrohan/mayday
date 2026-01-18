import SwiftUI
import PhotosUI
import UIKit

struct ActionsView: View {
    @State private var selectedAction: ActionType?

    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        reportsSection
                        communicationSection
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(item: $selectedAction) { action in
            actionSheet(for: action)
        }
    }

    private var header: some View {
        HStack {
            Spacer()

            HStack(spacing: 8) {
                MaydayLogoCompact(size: 22)
                Text("Actions")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            }

            Spacer()
        }
        .padding(.bottom, 16)
    }

    // MARK: - Reports Section

    private var reportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reports")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ActionCard(
                    icon: "cross.case.fill",
                    title: "Medical Triage",
                    subtitle: "Report patient conditions",
                    iconOpacity: 0.9
                ) {
                    selectedAction = .triage
                }

                ActionCard(
                    icon: "house.fill",
                    title: "Shelter Status",
                    subtitle: "Update availability",
                    iconOpacity: 0.75
                ) {
                    selectedAction = .shelter
                }

                ActionCard(
                    icon: "person.fill.questionmark",
                    title: "Missing Person",
                    subtitle: "Report missing",
                    iconOpacity: 0.8
                ) {
                    selectedAction = .missingPerson
                }
            }
        }
    }

    // MARK: - Communication Section

    private var communicationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Communication")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ActionCard(
                    icon: "megaphone.fill",
                    title: "Broadcast",
                    subtitle: "Send to all devices",
                    iconOpacity: 0.7
                ) {
                    selectedAction = .broadcast
                }

                ActionCard(
                    icon: "envelope.fill",
                    title: "Direct Message",
                    subtitle: "Message a device",
                    iconOpacity: 0.55
                ) {
                    selectedAction = .directMessage
                }
            }
        }
    }

    @ViewBuilder
    private func actionSheet(for action: ActionType) -> some View {
        switch action {
        case .triage:
            TriageSheet()
        case .shelter:
            ShelterSheet()
        case .missingPerson:
            if #available(iOS 16.0, *) {
                MissingPersonSheet()
            } else {
                Text("Photo picker requires iOS 16+")
            }
        case .broadcast:
            BroadcastSheet()
        case .directMessage:
            DirectMessageSheet()
        }
    }
}

// MARK: - Action Type

enum ActionType: String, Identifiable {
    case triage
    case shelter
    case missingPerson
    case broadcast
    case directMessage

    var id: String { rawValue }
}

// MARK: - Action Card

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconOpacity: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(iconOpacity))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }

                // Text
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(ActionCardButtonStyle())
    }
}

struct ActionCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Triage Sheet

struct TriageSheet: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var patientName = ""
    @State private var age = ""
    @State private var condition = "stable"
    @State private var injuries = ""
    @State private var conscious = true
    @State private var breathing = true
    @State private var showingSentAlert = false

    let conditions = ["stable", "serious", "critical"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    sheetHeader(icon: "cross.case.fill", title: "Medical Triage")

                    // Patient Name
                    FormFieldBW(label: "Patient name") {
                        TextField("Enter name", text: $patientName)
                            .font(.system(size: 16))
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Age
                    FormFieldBW(label: "Age") {
                        TextField("Enter age", text: $age)
                            .font(.system(size: 16))
                            .keyboardType(.numberPad)
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Condition
                    FormFieldBW(label: "Condition") {
                        HStack(spacing: 8) {
                            ForEach(conditions, id: \.self) { cond in
                                Button {
                                    condition = cond
                                } label: {
                                    Text(cond.capitalized)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(condition == cond ? .white : .black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(condition == cond ? Color.black : Color.black.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    // Vital Signs
                    FormFieldBW(label: "Vital signs") {
                        VStack(spacing: 0) {
                            HStack {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.08))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: conscious ? "brain.head.profile" : "zzz")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(conscious ? .black : .secondary)
                                    }
                                    Text("Conscious")
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                }
                                Spacer()
                                Toggle("", isOn: $conscious)
                                    .tint(.black)
                            }
                            .padding(14)

                            Divider()
                                .padding(.leading, 60)

                            HStack {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.08))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: breathing ? "lungs.fill" : "lungs")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(breathing ? .black : .secondary)
                                    }
                                    Text("Breathing")
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                }
                                Spacer()
                                Toggle("", isOn: $breathing)
                                    .tint(.black)
                            }
                            .padding(14)
                        }
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Injuries
                    FormFieldBW(label: "Injuries / Notes") {
                        TextEditorBW(text: $injuries, placeholder: "Describe injuries or medical notes...")
                    }

                    // Send button
                    sendButton(title: "Send triage report", enabled: canSend) {
                        sendTriage()
                    }
                }
                .padding()
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { sheetToolbar(dismiss: dismiss) }
            .alert("Report sent", isPresented: $showingSentAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("Triage report has been broadcast to the Mayday network.")
            }
        }
    }

    private var canSend: Bool {
        !patientName.isEmpty
    }

    private func sendTriage() {
        viewModel.meshService.sendTriage(
            patientName: patientName,
            age: Int(age) ?? 0,
            condition: condition,
            injuries: injuries,
            conscious: conscious,
            breathing: breathing
        )
        showingSentAlert = true
    }
}

// MARK: - Shelter Sheet

struct ShelterSheet: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var shelterName = ""
    @State private var capacity = ""
    @State private var currentOccupancy = ""
    @State private var supplies: Set<String> = []
    @State private var acceptingMore = true
    @State private var showingSentAlert = false

    let availableSupplies = ["Water", "Food", "Medical", "Blankets", "Power"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    sheetHeader(icon: "house.fill", title: "Shelter Status")

                    // Shelter Name
                    FormFieldBW(label: "Shelter name") {
                        TextField("Enter shelter name", text: $shelterName)
                            .font(.system(size: 16))
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Capacity
                    HStack(spacing: 12) {
                        FormFieldBW(label: "Capacity") {
                            TextField("Max", text: $capacity)
                                .font(.system(size: 16))
                                .keyboardType(.numberPad)
                                .padding(16)
                                .background(Color.black.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        FormFieldBW(label: "Current") {
                            TextField("Now", text: $currentOccupancy)
                                .font(.system(size: 16))
                                .keyboardType(.numberPad)
                                .padding(16)
                                .background(Color.black.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Supplies
                    FormFieldBW(label: "Available supplies") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(availableSupplies, id: \.self) { supply in
                                Button {
                                    if supplies.contains(supply) {
                                        supplies.remove(supply)
                                    } else {
                                        supplies.insert(supply)
                                    }
                                } label: {
                                    Text(supply)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(supplies.contains(supply) ? .white : .black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(supplies.contains(supply) ? Color.black : Color.black.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    // Accepting Toggle
                    FormFieldBW(label: "Status") {
                        HStack {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.08))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: acceptingMore ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(acceptingMore ? .black : .secondary)
                                }

                                Text("Accepting new arrivals")
                                    .font(.system(size: 15))
                                    .foregroundColor(.black)
                            }

                            Spacer()

                            Toggle("", isOn: $acceptingMore)
                                .tint(.black)
                        }
                        .padding(14)
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Send button
                    sendButton(title: "Send shelter update", enabled: canSend) {
                        sendShelter()
                    }
                }
                .padding()
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { sheetToolbar(dismiss: dismiss) }
            .alert("Update sent", isPresented: $showingSentAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("Shelter status has been broadcast to the Mayday network.")
            }
        }
    }

    private var canSend: Bool {
        !shelterName.isEmpty
    }

    private func sendShelter() {
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

// MARK: - Missing Person Sheet

@available(iOS 16.0, *)
struct MissingPersonSheet: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var personName = ""
    @State private var lastSeenLocation = ""
    @State private var lastSeenTime = ""
    @State private var physicalDescription = ""
    @State private var contactInfo = ""
    @State private var showingSentAlert = false

    // Photo picker state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    sheetHeader(icon: "person.fill.questionmark", title: "Missing Person")

                    // Photo Section
                    FormFieldBW(label: "Photo", optional: true) {
                        VStack(spacing: 16) {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    )
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.black.opacity(0.03))
                                        .frame(width: 120, height: 120)

                                    VStack(spacing: 8) {
                                        Image(systemName: "person.crop.rectangle")
                                            .font(.system(size: 32))
                                            .foregroundColor(.black.opacity(0.3))
                                        Text("Add photo")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Text(selectedImage == nil ? "Select photo" : "Change photo")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.black)
                                    .clipShape(Capsule())
                            }
                            .onChange(of: selectedPhotoItem) { newValue in
                                Task {
                                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        selectedImage = resizeImage(image, maxSize: 300)
                                    }
                                }
                            }

                            Text("Photo will be compressed for transmission")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }

                    // Person Name
                    FormFieldBW(label: "Person's name") {
                        TextField("Enter name", text: $personName)
                            .font(.system(size: 16))
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Last Seen Location
                    FormFieldBW(label: "Last seen location") {
                        TextField("Where were they last seen?", text: $lastSeenLocation)
                            .font(.system(size: 16))
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Last Seen Time
                    FormFieldBW(label: "Last seen time") {
                        TextField("When were they last seen?", text: $lastSeenTime)
                            .font(.system(size: 16))
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Physical Description
                    FormFieldBW(label: "Physical description") {
                        TextEditorBW(text: $physicalDescription, placeholder: "Describe appearance, clothing, etc...")
                    }

                    // Contact Info
                    FormFieldBW(label: "Contact information") {
                        TextField("How to reach you if found", text: $contactInfo)
                            .font(.system(size: 16))
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Send button
                    sendButton(title: "Send missing person alert", enabled: canSend) {
                        sendMissingPerson()
                    }
                }
                .padding()
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { sheetToolbar(dismiss: dismiss) }
            .alert("Alert sent", isPresented: $showingSentAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("Missing person alert has been broadcast to the Mayday network.")
            }
        }
    }

    private var canSend: Bool {
        !personName.isEmpty
    }

    private func sendMissingPerson() {
        // Convert image to base64 if available
        var photoBase64: String? = nil
        if let image = selectedImage,
           let imageData = image.jpegData(compressionQuality: 0.5) {
            photoBase64 = imageData.base64EncodedString()
        }

        viewModel.meshService.sendMissingPerson(
            name: personName,
            lastSeenLocation: lastSeenLocation,
            lastSeenTime: lastSeenTime,
            description: physicalDescription,
            contactInfo: contactInfo,
            photoBase64: photoBase64
        )
        showingSentAlert = true
    }

    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)
        if ratio >= 1 { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Broadcast Sheet

struct BroadcastSheet: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var message = ""
    @State private var showingSentAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    sheetHeader(icon: "megaphone.fill", title: "Broadcast")

                    // Title
                    FormFieldBW(label: "Title") {
                        TextField("Announcement title", text: $title)
                            .font(.system(size: 16))
                            .padding(16)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Message
                    FormFieldBW(label: "Message") {
                        TextEditorBW(text: $message, placeholder: "Write your announcement...")
                    }

                    // Info text
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                        Text("This will be sent to all \(viewModel.meshService.connectedPeers.count) connected devices")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Send button
                    sendButton(title: "Send broadcast", enabled: canSend) {
                        sendBroadcast()
                    }
                }
                .padding()
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { sheetToolbar(dismiss: dismiss) }
            .alert("Broadcast sent", isPresented: $showingSentAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your announcement has been broadcast to the Mayday network.")
            }
        }
    }

    private var canSend: Bool {
        !title.isEmpty && !message.isEmpty
    }

    private func sendBroadcast() {
        viewModel.meshService.sendBroadcast(title: title, message: message)
        showingSentAlert = true
    }
}

// MARK: - Direct Message Sheet

struct DirectMessageSheet: View {
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
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    sheetHeader(icon: "envelope.fill", title: "Direct Message")

                    // Recipient
                    FormFieldBW(label: "Select recipient") {
                        if knownDevices.isEmpty {
                            emptyDevicesView
                        } else {
                            deviceListView
                        }
                    }

                    // Message
                    FormFieldBW(label: "Message") {
                        TextEditorBW(text: $message, placeholder: "Write your message...")
                    }

                    // Send button
                    sendButton(title: "Send message", enabled: canSend) {
                        sendDirectMessage()
                    }
                }
                .padding()
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { sheetToolbar(dismiss: dismiss) }
            .alert("Message sent", isPresented: $showingSentAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your message has been sent through the Mayday network.")
            }
        }
    }

    private var emptyDevicesView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 64, height: 64)
                Image(systemName: "network.slash")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.black.opacity(0.4))
            }

            Text("No devices found")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)

            Button {
                viewModel.meshService.discoverNetwork()
            } label: {
                Text("Discover network")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var deviceListView: some View {
        VStack(spacing: 0) {
            ForEach(Array(knownDevices.enumerated()), id: \.element.id) { index, device in
                Button {
                    selectedDevice = device.id
                } label: {
                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(selectedDevice == device.id ? Color.black : Color.black.opacity(0.08))
                                    .frame(width: 36, height: 36)
                                Image(systemName: selectedDevice == device.id ? "checkmark" : "iphone")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedDevice == device.id ? .white : .black)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(device.id.prefix(16)) + "...")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.black)
                                Text("\(device.hops) hop\(device.hops == 1 ? "" : "s") away")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(14)
                }

                if index < knownDevices.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var canSend: Bool {
        !selectedDevice.isEmpty && !message.isEmpty
    }

    private func sendDirectMessage() {
        viewModel.meshService.sendDirectMessage(
            to: selectedDevice,
            content: message
        )
        showingSentAlert = true
    }
}

// MARK: - Shared Components

struct FormFieldBW<Content: View>: View {
    let label: String
    let optional: Bool
    let content: Content

    init(label: String, optional: Bool = false, @ViewBuilder content: () -> Content) {
        self.label = label
        self.optional = optional
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                if optional {
                    Text("Optional")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Capsule())
                }
            }

            content
        }
    }
}

struct TextEditorBW: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 16))
                .frame(minHeight: 100)
                .padding(12)

            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(16)
                    .allowsHitTesting(false)
            }
        }
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@ViewBuilder
func sheetHeader(icon: String, title: String) -> some View {
    VStack(spacing: 16) {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 64, height: 64)

            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white)
        }

        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.black)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
    .background(Color.black.opacity(0.03))
    .clipShape(RoundedRectangle(cornerRadius: 20))
}

@ViewBuilder
func sendButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 8) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 16, weight: .medium))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(enabled ? Color.black : Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .disabled(!enabled)
}

@ToolbarContentBuilder
func sheetToolbar(dismiss: DismissAction) -> some ToolbarContent {
    ToolbarItem(placement: .navigationBarLeading) {
        HStack(spacing: 8) {
            MaydayLogoCompact(size: 18)
            Text("Mayday")
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .foregroundColor(.black)
    }

    ToolbarItem(placement: .navigationBarTrailing) {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
                .padding(8)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
    }
}
