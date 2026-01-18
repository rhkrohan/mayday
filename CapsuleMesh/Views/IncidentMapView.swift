import SwiftUI
import MapKit
import CoreLocation

// MARK: - Data Models

struct MapIncident: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let category: MapIncidentCategory
    let title: String
    let subtitle: String?
    let severityScore: Int?
    let emergencyType: String?
    let timestamp: Date
    let senderName: String?
    let witnessCount: Int
    let respondingGuards: Int
    let isActive: Bool
    let panicId: String?
    let isLandmark: Bool

    init(
        id: String, coordinate: CLLocationCoordinate2D, category: MapIncidentCategory,
        title: String, subtitle: String? = nil, severityScore: Int? = nil,
        emergencyType: String? = nil, timestamp: Date, senderName: String? = nil,
        witnessCount: Int = 0, respondingGuards: Int = 0, isActive: Bool = false,
        panicId: String? = nil, isLandmark: Bool = false
    ) {
        self.id = id; self.coordinate = coordinate; self.category = category
        self.title = title; self.subtitle = subtitle; self.severityScore = severityScore
        self.emergencyType = emergencyType; self.timestamp = timestamp
        self.senderName = senderName; self.witnessCount = witnessCount
        self.respondingGuards = respondingGuards; self.isActive = isActive
        self.panicId = panicId; self.isLandmark = isLandmark
    }
}

enum MapIncidentCategory: String, CaseIterable {
    case panic, sos, incidentReport, securityPersonnel, shelter, witnessConfirm

    var displayName: String {
        switch self {
        case .panic: return "Panic Alert"
        case .sos: return "SOS Emergency"
        case .incidentReport: return "Incident Report"
        case .securityPersonnel: return "Security"
        case .shelter: return "Safe Zone"
        case .witnessConfirm: return "Witness"
        }
    }

    var color: Color {
        switch self {
        case .panic, .sos: return .red
        case .incidentReport: return .orange
        case .securityPersonnel: return MaydayBrand.securityBlue
        case .shelter, .witnessConfirm: return MaydayBrand.safeGreen
        }
    }

    var icon: String {
        switch self {
        case .panic: return "light.beacon.max.fill"
        case .sos: return "exclamationmark.triangle.fill"
        case .incidentReport: return "exclamationmark.shield.fill"
        case .securityPersonnel: return "shield.checkered"
        case .shelter: return "shield.lefthalf.filled"
        case .witnessConfirm: return "checkmark.shield.fill"
        }
    }
}

enum TimeFilter: String, CaseIterable, Identifiable {
    case oneHour = "1h"
    case twentyFourHours = "24h"
    case all = "All"
    var id: String { rawValue }
    var interval: TimeInterval? {
        switch self {
        case .oneHour: return 3600
        case .twentyFourHours: return 86400
        case .all: return nil
        }
    }
}

// MARK: - Virtual Barricade (Camera Coverage Zones)

struct CameraNode: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let coverageRadius: Double  // meters
    let type: String
    let isOnline: Bool
}

// Hardcoded camera positions matching the dashboard server
let cameraNodes: [CameraNode] = [
    CameraNode(id: "cam-1", name: "Drexel 33rd & Market", coordinate: CLLocationCoordinate2D(latitude: 39.9566, longitude: -75.1899), coverageRadius: 200, type: "campus", isOnline: true),
    CameraNode(id: "cam-2", name: "SEPTA 30th St Station", coordinate: CLLocationCoordinate2D(latitude: 39.9557, longitude: -75.1822), coverageRadius: 150, type: "transit", isOnline: true),
    CameraNode(id: "cam-3", name: "Rittenhouse Square", coordinate: CLLocationCoordinate2D(latitude: 39.9496, longitude: -75.1718), coverageRadius: 250, type: "public", isOnline: true),
    CameraNode(id: "cam-4", name: "Temple University Main", coordinate: CLLocationCoordinate2D(latitude: 39.9812, longitude: -75.1553), coverageRadius: 200, type: "campus", isOnline: false),
]

// MARK: - Dark Map Style

struct DarkMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let annotations: [MapIncident]
    let cameras: [CameraNode]
    let showBarricade: Bool
    let pulsePhase: Bool
    var onTap: ((MapIncident) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.overrideUserInterfaceStyle = .dark
        map.pointOfInterestFilter = .excludingAll
        map.showsUserLocation = true
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Update region if significantly different
        let center = map.region.center
        let diff = abs(center.latitude - region.center.latitude) + abs(center.longitude - region.center.longitude)
        if diff > 0.01 {
            map.setRegion(region, animated: true)
        }

        // Remove old overlays and annotations
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })

        // Add camera coverage circles (virtual barricade)
        if showBarricade {
            for cam in cameras {
                let circle = MKCircle(center: cam.coordinate, radius: cam.coverageRadius)
                circle.title = cam.id
                map.addOverlay(circle)
            }
        }

        // Add incident annotations
        for incident in annotations where !incident.isLandmark {
            let ann = IncidentAnnotation(incident: incident)
            map.addAnnotation(ann)
        }

        // Add camera point annotations
        if showBarricade {
            for cam in cameras {
                let ann = CameraAnnotation(camera: cam)
                map.addAnnotation(ann)
            }
        }

        context.coordinator.annotations = annotations
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class IncidentAnnotation: NSObject, MKAnnotation {
        let incident: MapIncident
        var coordinate: CLLocationCoordinate2D { incident.coordinate }
        var title: String? { incident.title }
        init(incident: MapIncident) { self.incident = incident }
    }

    class CameraAnnotation: NSObject, MKAnnotation {
        let camera: CameraNode
        var coordinate: CLLocationCoordinate2D { camera.coordinate }
        var title: String? { camera.name }
        init(camera: CameraNode) { self.camera = camera }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var annotations: [MapIncident] = []
        var onTap: ((MapIncident) -> Void)?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.08)
                renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.35)
                renderer.lineWidth = 1.5
                renderer.lineDashPattern = [6, 4]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let camAnn = annotation as? CameraAnnotation {
                let id = "camera"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                let size: CGFloat = 28
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                view.image = renderer.image { ctx in
                    let rect = CGRect(x: 0, y: 0, width: size, height: size)
                    UIColor.systemGreen.withAlphaComponent(camAnn.camera.isOnline ? 0.9 : 0.3).setFill()
                    UIBezierPath(roundedRect: rect, cornerRadius: 7).fill()
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                        .foregroundColor: UIColor.white
                    ]
                    let text = "C" as NSString
                    let textSize = text.size(withAttributes: attrs)
                    text.draw(at: CGPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2), withAttributes: attrs)
                }
                view.canShowCallout = true
                return view
            }

            if let incAnn = annotation as? IncidentAnnotation {
                let incident = incAnn.incident
                let id = "incident-\(incident.category.rawValue)"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation

                let size: CGFloat = incident.category == .panic || incident.category == .sos ? 34 : 26
                let color: UIColor
                switch incident.category {
                case .panic, .sos: color = .systemRed
                case .incidentReport: color = .systemOrange
                case .securityPersonnel: color = .systemBlue
                case .shelter, .witnessConfirm: color = .systemGreen
                }

                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                view.image = renderer.image { ctx in
                    let rect = CGRect(x: 0, y: 0, width: size, height: size)
                    color.setFill()
                    if incident.category == .incidentReport {
                        UIBezierPath(roundedRect: rect, cornerRadius: 6).fill()
                    } else {
                        UIBezierPath(ovalIn: rect).fill()
                    }

                    // Draw severity number or icon letter
                    let text: String
                    if let score = incident.severityScore {
                        text = "\(score)"
                    } else {
                        switch incident.category {
                        case .securityPersonnel: text = "S"
                        case .shelter: text = "H"
                        case .witnessConfirm: text = "W"
                        default: text = "!"
                        }
                    }
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: size * 0.45, weight: .bold),
                        .foregroundColor: UIColor.white
                    ]
                    let ns = text as NSString
                    let textSize = ns.size(withAttributes: attrs)
                    ns.draw(at: CGPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2), withAttributes: attrs)
                }

                view.canShowCallout = false
                return view
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let incAnn = view.annotation as? IncidentAnnotation {
                onTap?(incAnn.incident)
            }
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
    }
}

// MARK: - IncidentMapView

struct IncidentMapView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @ObservedObject private var simulationService = SimulationService.shared

    @State private var region = MKCoordinateRegion(
        center: PhillyLocations.center,
        span: PhillyLocations.defaultSpan
    )
    @State private var timeFilter: TimeFilter = .twentyFourHours
    @State private var selectedIncident: MapIncident?
    @State private var showingDetail = false
    @State private var pulseAnimation = false
    @State private var showBarricade = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .zIndex(10)

                ZStack(alignment: .bottom) {
                    // Dark map with overlays
                    DarkMapView(
                        region: $region,
                        annotations: filteredAnnotations,
                        cameras: cameraNodes,
                        showBarricade: showBarricade,
                        pulsePhase: pulseAnimation
                    ) { incident in
                        selectedIncident = incident
                        showingDetail = true
                    }
                    .ignoresSafeArea(edges: .bottom)

                    // Floating controls
                    VStack(spacing: 8) {
                        floatingStats
                        filterPills
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let incident = selectedIncident {
                IncidentDetailSheet(incident: incident)
                    .presentationDetents([.medium])
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                Text("Incidents")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            // Time filter
            HStack(spacing: 4) {
                ForEach(TimeFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { timeFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(timeFilter == filter ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(timeFilter == filter ? Color.white : Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            // Barricade toggle
            Button {
                showBarricade.toggle()
            } label: {
                Image(systemName: showBarricade ? "video.fill" : "video.slash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(showBarricade ? .green : .white.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(showBarricade ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            // Recenter
            Button {
                withAnimation(.easeInOut(duration: 0.4)) {
                    region = MKCoordinateRegion(center: PhillyLocations.center, span: PhillyLocations.defaultSpan)
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.black)
    }

    // MARK: - Floating Stats

    private var floatingStats: some View {
        let incidents = filteredAnnotations.filter { !$0.isLandmark && $0.category != .securityPersonnel }
        let activePanics = incidents.filter { $0.isActive && ($0.category == .panic || $0.category == .sos) }
        let security = filteredAnnotations.filter { $0.category == .securityPersonnel }
        let onlineCams = cameraNodes.filter { $0.isOnline }

        return HStack(spacing: 14) {
            statPill(count: activePanics.count, label: "Active", color: .red)
            statPill(count: incidents.count, label: "Incidents", color: .white)
            statPill(count: security.count, label: "Security", color: .blue)
            statPill(count: onlineCams.count, label: "Cameras", color: .green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }

    private func statPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(nil, label: "All", icon: "circle.grid.2x2")
                filterChip(.panic, label: "Panic", icon: "light.beacon.max.fill")
                filterChip(.incidentReport, label: "Incidents", icon: "exclamationmark.shield.fill")
                filterChip(.securityPersonnel, label: "Security", icon: "shield.checkered")
                filterChip(.shelter, label: "Safe Zones", icon: "shield.lefthalf.filled")
            }
        }
    }

    @State private var selectedCategory: MapIncidentCategory?
    private func filterChip(_ category: MapIncidentCategory?, label: String, icon: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = category }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.1)))
        }
    }

    // MARK: - Data

    private var filteredAnnotations: [MapIncident] {
        let all = allAnnotationItems
        guard let cat = selectedCategory else { return all }
        return all.filter { $0.category == cat || $0.isLandmark }
    }

    private var allAnnotationItems: [MapIncident] {
        var items: [MapIncident] = []
        items.append(contentsOf: incidentsFromMessages)
        items.append(contentsOf: incidentsFromActivePanics)
        items.append(contentsOf: incidentsFromSecurity)
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }

    private var incidentsFromMessages: [MapIncident] {
        let allMsgs = combinedMessages
        let cutoff = timeFilter.interval.map { Date().addingTimeInterval(-$0) }
        return allMsgs.compactMap { message -> MapIncident? in
            guard let coord = message.coordinate, message.type.isUserFacing else { return nil }
            if let cutoff = cutoff, message.timestamp < cutoff { return nil }
            let category: MapIncidentCategory
            switch message.type {
            case .panic: category = .panic
            case .sos: category = .sos
            case .incidentReport: category = .incidentReport
            case .shelter: category = .shelter
            case .witnessConfirm: category = .witnessConfirm
            case .securityResponse: category = .securityPersonnel
            default: return nil
            }
            let title: String
            switch message.type {
            case .panic: title = message.data.emergencyType?.capitalized ?? "Panic Alert"
            case .sos: title = "SOS Emergency"
            case .incidentReport: title = message.data.incidentType?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Incident"
            case .shelter: title = message.data.shelterName ?? "Safe Zone"
            case .witnessConfirm: title = "Witness Confirmed"
            case .securityResponse: title = "Security Responding"
            default: title = message.type.displayName
            }
            return MapIncident(
                id: "msg-\(message.id.uuidString)", coordinate: coord, category: category,
                title: title, subtitle: message.data.description ?? message.data.witnessNote,
                severityScore: message.data.severityScore,
                emergencyType: message.data.emergencyType ?? message.data.incidentType,
                timestamp: message.timestamp, senderName: message.senderName,
                witnessCount: message.data.witnessCount ?? 0,
                isActive: Date().timeIntervalSince(message.timestamp) < 900,
                panicId: message.data.panicId
            )
        }
    }

    private var incidentsFromActivePanics: [MapIncident] {
        let cutoff = timeFilter.interval.map { Date().addingTimeInterval(-$0) }
        return viewModel.meshService.activePanics.compactMap { panic -> MapIncident? in
            guard let lat = panic.latitude, let lon = panic.longitude else { return nil }
            if let cutoff = cutoff, panic.timestamp < cutoff { return nil }
            return MapIncident(
                id: "panic-\(panic.id)",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                category: .panic, title: panic.emergencyType?.capitalized ?? "Panic Alert",
                subtitle: panic.description, severityScore: panic.severityScore,
                emergencyType: panic.emergencyType, timestamp: panic.timestamp,
                senderName: panic.senderName, witnessCount: panic.witnessCount,
                respondingGuards: panic.respondingGuards.count, isActive: true, panicId: panic.id
            )
        }
    }

    private var incidentsFromSecurity: [MapIncident] {
        viewModel.meshService.allSecurityForDisplay.compactMap { node -> MapIncident? in
            guard let lat = node.latitude, let lon = node.longitude else { return nil }
            return MapIncident(
                id: "sec-\(node.id)",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                category: .securityPersonnel, title: node.name,
                subtitle: node.dutyStatus.displayName, timestamp: node.lastSeen,
                senderName: node.name, isActive: !node.isStale, panicId: node.respondingTo
            )
        }
    }

    private var combinedMessages: [MeshMessage] {
        var messages = viewModel.messageStore.messages
        if simulationService.isRunning { messages.append(contentsOf: simulationService.simulatedMessages) }
        return messages
    }
}

// MARK: - Incident Detail Sheet

struct IncidentDetailSheet: View {
    let incident: MapIncident
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        Image(systemName: incident.category.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(incident.category.color)
                            .clipShape(RoundedRectangle(cornerRadius: 9))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(incident.category.displayName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(incident.category.color)
                                .textCase(.uppercase)
                            Text(incident.timestamp, style: .relative)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if incident.isActive && incident.category != .securityPersonnel {
                            Text("ACTIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.red).clipShape(Capsule())
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(incident.title).font(.system(size: 20, weight: .bold))
                        if let subtitle = incident.subtitle {
                            Text(subtitle).font(.system(size: 14)).foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        if let sev = incident.severityScore { detailCell("Severity", "\(sev)/10", sevColor(sev)) }
                        if let type = incident.emergencyType { detailCell("Type", type.replacingOccurrences(of: "_", with: " ").capitalized, .primary) }
                        if let name = incident.senderName, incident.category != .securityPersonnel { detailCell("Reported by", name, .primary) }
                        if incident.witnessCount > 0 { detailCell("Witnesses", "\(incident.witnessCount)", .green) }
                        if incident.respondingGuards > 0 { detailCell("Responding", "\(incident.respondingGuards)", .blue) }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 12)).foregroundColor(.secondary)
                        Text(String(format: "%.4f, %.4f", incident.coordinate.latitude, incident.coordinate.longitude))
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary).padding(8)
                            .background(Color(.systemGray5)).clipShape(Circle())
                    }
                }
            }
        }
    }

    private func detailCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).textCase(.uppercase)
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func sevColor(_ s: Int) -> Color {
        switch s { case 1...3: return .green; case 4...6: return .orange; case 7...8: return .orange; case 9...10: return .red; default: return .secondary }
    }
}
