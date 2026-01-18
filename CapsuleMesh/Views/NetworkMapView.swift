import SwiftUI
import CoreLocation

struct NetworkMapView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @ObservedObject private var simulationService = SimulationService.shared
    @State private var animationPhase: CGFloat = 0
    @State private var selectedNode: NetworkNode? = nil
    @State private var pulseScale: CGFloat = 1.0
    @State private var showingPeersList = false

    // Interactive state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var computedNodes: [NetworkNode] = []

    // Floating animation
    @State private var floatPhase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Clean white background
                Color.white
                    .ignoresSafeArea()

                // Minimal grid
                MinimalGrid()
                    .scaleEffect(scale)
                    .offset(offset)

                // Main visualization
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
                    let nodes = computeNodePositions(center: center, size: size)

                    // Separate nodes by type
                    let directPeers = nodes.filter { $0.isConnected && $0.id != "self" }
                    let remoteNodes = nodes.filter { !$0.isConnected && $0.id != "self" }

                    // 1. Draw SOLID lines from self to directly connected peers
                    for node in directPeers {
                        drawDirectConnection(
                            context: &context,
                            from: center,
                            to: node.position,
                            phase: animationPhase,
                            isSelected: selectedNode?.id == node.id
                        )
                    }

                    // 2. Draw DASHED lines from peers to remote nodes (mesh routing)
                    drawMeshRoutes(
                        context: &context,
                        directPeers: directPeers,
                        remoteNodes: remoteNodes,
                        phase: animationPhase,
                        selectedId: selectedNode?.id
                    )

                    // 3. Draw peer-to-peer connections (between direct peers)
                    drawPeerConnections(context: &context, nodes: nodes, phase: animationPhase)

                    // Draw nodes
                    for node in nodes {
                        drawFlatNode(
                            context: &context,
                            node: node,
                            isSelected: selectedNode?.id == node.id,
                            pulseScale: node.id == "self" ? pulseScale : 1.0
                        )
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                scale = min(max(newScale, 0.5), 3.0)
                            }
                            .onEnded { _ in
                                lastScale = scale
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            // Only handle as tap if no significant movement
                            if abs(value.translation.width) < 10 && abs(value.translation.height) < 10 {
                                handleTap(at: value.location, in: geometry.size)
                            }
                        }
                )

                // Selected node info card
                if let node = selectedNode {
                    VStack {
                        nodeInfoCard(for: node)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 80)
                    .padding(.horizontal)
                }

                // Stats overlay at bottom
                VStack {
                    Spacer()
                    statsOverlay
                        .padding(.bottom, 110)
                }
                .padding(.horizontal)

                // Top bar
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            showingPeersList = true
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                                .padding(12)
                                .background(Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }

                        Spacer()

                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                MaydayLogoCompact(size: 22)
                                Text("Mayday")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                            }

                            Button {
                                refreshNetwork()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("Refresh")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black)
                                .clipShape(Capsule())
                            }
                        }

                        Spacer()

                        Button {
                            withAnimation(.spring()) {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                                selectedNode = nil
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                                .padding(12)
                                .background(Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .onAppear {
            startAnimations()
        }
        .sheet(isPresented: $showingPeersList) {
            PeersView()
        }
    }

    private func nodeInfoCard(for node: NetworkNode) -> some View {
        HStack(spacing: 16) {
            // Node indicator - green for gateway, black otherwise
            Circle()
                .fill(node.isGateway ? Color.green : Color.black.opacity(node.nodeType == .self ? 1.0 : (node.isConnected ? 0.8 : 0.4)))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(node.isGateway ? Color.green.opacity(0.3) : Color.black.opacity(0.2), lineWidth: 2)
                )
                .overlay(
                    // Wifi icon for gateway
                    node.isGateway ? Image(systemName: "wifi")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white) : nil
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(node.displayName)
                        .font(.headline)
                        .foregroundColor(node.isGateway ? .green : .black)

                    if node.isGateway {
                        Text("Gateway")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 12) {
                    Label(node.nodeType == .self ? "You" : (node.isConnected ? "Connected" : "Remote"), systemImage: node.isConnected ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if node.hops > 0 {
                        Label("\(node.hops) hop\(node.hops == 1 ? "" : "s")", systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if node.isGateway {
                        Label("Online", systemImage: "globe")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    if node.isSimulated {
                        Text("SIM")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }
                }

                // Extra info for simulated peers
                if node.isSimulated {
                    HStack(spacing: 12) {
                        if node.batteryLevel >= 0 {
                            Label("\(node.batteryLevel)%", systemImage: batteryIcon(for: node.batteryLevel))
                                .font(.caption)
                                .foregroundColor(batteryColor(for: node.batteryLevel))
                        }

                        if let loc = node.location, loc.latitude != 0 {
                            Label(String(format: "%.4f, %.4f", loc.latitude, loc.longitude), systemImage: "location.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Button {
                withAnimation(.spring()) {
                    selectedNode = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
    }

    private var statsOverlay: some View {
        let realPeers = viewModel.meshService.connectedPeers.count
        let simPeers = simulationService.isRunning ? simulationService.simulatedPeers.filter { $0.hops == 1 }.count : 0
        let totalConnected = realPeers + simPeers

        let realMesh = viewModel.meshService.knownDevices.count
        let simMesh = simulationService.isRunning ? simulationService.simulatedPeers.count : 0
        let totalMesh = realMesh + simMesh

        return HStack(spacing: 14) {
            // Simulation indicator
            if simulationService.isRunning {
                VStack(spacing: 0) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("SIM")
                        .font(.system(size: 7, weight: .bold))
                }
                .foregroundColor(.purple)
            }

            StatBadgeBW(value: "\(totalConnected)", label: "Connected")
            StatBadgeBW(value: "\(totalMesh)", label: "In Mesh")
            StatBadgeBW(value: "\(maxHops)", label: "Hops")

            // Gateway indicator - show if we ARE a gateway OR if we can REACH a gateway
            if GatewayService.shared.isGatewayActive {
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.system(size: 12, weight: .bold))
                    VStack(spacing: 0) {
                        Text("You")
                            .font(.system(size: 11, weight: .bold))
                        Text("Gateway")
                            .font(.system(size: 8, weight: .medium))
                            .opacity(0.6)
                    }
                }
                .foregroundColor(.green)
            } else if let nearestGateway = viewModel.meshService.nearestGateway {
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.system(size: 12, weight: .bold))
                    VStack(spacing: 0) {
                        Text("\(nearestGateway.hops)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        Text("Hops to Web")
                            .font(.system(size: 7, weight: .medium))
                            .opacity(0.6)
                    }
                }
                .foregroundColor(.green)
            } else if simulationService.isRunning {
                // Show simulated gateways
                let simGateways = simulationService.simulatedPeers.filter { $0.isGateway }
                if let nearest = simGateways.min(by: { $0.hops < $1.hops }) {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi")
                            .font(.system(size: 12, weight: .bold))
                        VStack(spacing: 0) {
                            Text("\(nearest.hops)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                            Text("Hops to Web")
                                .font(.system(size: 7, weight: .medium))
                                .opacity(0.6)
                        }
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.black)
        .clipShape(Capsule())
    }

    private var maxHops: Int {
        let realMax = viewModel.meshService.knownDevices.values.max() ?? 0
        let simMax = simulationService.isRunning ? (simulationService.simulatedPeers.map { $0.hops }.max() ?? 0) : 0
        return max(realMax, simMax)
    }

    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 0..<10: return "battery.0"
        case 10..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            animationPhase = 1
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            floatPhase = 1
        }
    }

    private func refreshNetwork() {
        // Use the new refreshAndConnect method which:
        // 1. Tries to connect to all discovered peers
        // 2. Restarts browsing/advertising
        // 3. Sends discovery request to map the network
        viewModel.meshService.refreshAndConnect()

        // Reset view
        withAnimation(.spring()) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
            selectedNode = nil
        }
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
        let nodes = computeNodePositions(center: center, size: size)

        // Adjust tap location for scale and offset
        let adjustedLocation = CGPoint(
            x: (location.x - size.width / 2 - offset.width) / scale + size.width / 2,
            y: (location.y - size.height / 2 - offset.height) / scale + size.height / 2
        )

        // Find tapped node
        for node in nodes {
            let distance = sqrt(pow(adjustedLocation.x - node.position.x, 2) + pow(adjustedLocation.y - node.position.y, 2))
            let hitRadius: CGFloat = node.nodeType == .self ? 40 : (node.isConnected ? 30 : 25)

            if distance < hitRadius {
                withAnimation(.spring()) {
                    if selectedNode?.id == node.id {
                        selectedNode = nil
                    } else {
                        selectedNode = node
                    }
                }
                return
            }
        }

        // Tap on empty space deselects
        withAnimation(.spring()) {
            selectedNode = nil
        }
    }

    private func computeNodePositions(center: CGPoint, size: CGSize) -> [NetworkNode] {
        var result: [NetworkNode] = []

        // 1. Self node at center
        result.append(NetworkNode(
            id: "self",
            displayName: DeviceIdentity.shared.deviceName,
            position: center,
            hops: 0,
            isConnected: true,
            nodeType: .self,
            routedThrough: nil,
            isGateway: GatewayService.shared.isGatewayActive
        ))

        let connectedCount = viewModel.meshService.connectedPeers.count
        let innerRadius = min(size.width, size.height) * 0.28  // Increased for better spacing

        // 2. Direct peers in first ring around self
        var peerPositions: [String: CGPoint] = [:]

        // Get known gateway IDs for checking
        let gatewayIds = Set(viewModel.meshService.knownGateways.map { $0.id })

        for (index, peer) in viewModel.meshService.connectedPeers.enumerated() {
            let angle = (2.0 * Double.pi * Double(index) / Double(max(connectedCount, 1))) - Double.pi / 2.0
            let position = CGPoint(
                x: center.x + CGFloat(innerRadius) * CGFloat(cos(angle)),
                y: center.y + CGFloat(innerRadius) * CGFloat(sin(angle)) * 0.7
            )
            peerPositions[peer.id.displayName] = position

            // Check if this peer is a known gateway
            let isGateway = gatewayIds.contains(peer.id.displayName) || gatewayIds.contains(peer.displayName)

            result.append(NetworkNode(
                id: peer.id.displayName,
                displayName: peer.displayName,
                position: position,
                hops: 1,
                isConnected: true,
                nodeType: .peer,
                routedThrough: nil,
                isGateway: isGateway
            ))
        }

        // 3. Remote nodes - position them branching out from their routing peer
        // Filter out: directly connected peers AND self (we shouldn't appear as remote node)
        let connectedNames = Set(viewModel.meshService.connectedPeers.map { $0.id.displayName })
        let selfId = DeviceIdentity.shared.deviceId
        let selfName = DeviceIdentity.shared.deviceName
        let knownDevices = viewModel.meshService.knownDevices
            .filter { !connectedNames.contains($0.key) && $0.key != selfId && $0.key != selfName }
            .sorted { $0.value < $1.value }

        // Group remote nodes and distribute them among direct peers
        _ = max(1, (knownDevices.count + connectedCount - 1) / max(connectedCount, 1))

        for (index, device) in knownDevices.enumerated() {
            let hops = device.value

            // Assign to a routing peer (distribute evenly)
            let peerIndex = connectedCount > 0 ? index % connectedCount : 0
            let routingPeerName = connectedCount > 0 ? viewModel.meshService.connectedPeers[peerIndex].id.displayName : nil
            let routingPeerPosition = routingPeerName.flatMap { peerPositions[$0] } ?? center

            // Position relative to the routing peer, branching outward
            let peerToCenter = CGPoint(
                x: routingPeerPosition.x - center.x,
                y: routingPeerPosition.y - center.y
            )

            // Calculate angle from center through peer
            let baseAngle = atan2(peerToCenter.y, peerToCenter.x)

            // Spread remote nodes in a fan pattern behind their routing peer
            let devicesForThisPeer = knownDevices.filter { d in
                let idx = knownDevices.firstIndex(where: { $0.key == d.key }) ?? 0
                return connectedCount > 0 ? idx % connectedCount == peerIndex : true
            }.count

            let localIndex = (index / max(connectedCount, 1))
            let spreadAngle = Double.pi * 0.4 // 72 degree spread
            let angleOffset = devicesForThisPeer > 1
                ? spreadAngle * (Double(localIndex) / Double(devicesForThisPeer - 1) - 0.5)
                : 0

            let angle = baseAngle + angleOffset

            // Distance from routing peer based on hop count
            let hopDistance = min(size.width, size.height) * 0.12 * Double(hops)
            let position = CGPoint(
                x: routingPeerPosition.x + CGFloat(hopDistance) * CGFloat(cos(angle)),
                y: routingPeerPosition.y + CGFloat(hopDistance) * CGFloat(sin(angle)) * 0.7
            )

            result.append(NetworkNode(
                id: device.key,
                displayName: String(device.key.prefix(6)),
                position: position,
                hops: hops,
                isConnected: false,
                nodeType: .remote,
                routedThrough: routingPeerName,
                isGateway: gatewayIds.contains(device.key)
            ))
        }

        // 4. Simulated peers (if simulation is running)
        if SimulationService.shared.isRunning {
            let simPeers = SimulationService.shared.simulatedPeers
            let simCount = simPeers.count

            for (index, simPeer) in simPeers.enumerated() {
                // Position simulated peers with better spacing based on hop count
                let baseRadius = min(size.width, size.height) * 0.32
                let hopOffset = Double(simPeer.hops) * min(size.width, size.height) * 0.12
                let simRadius = baseRadius + hopOffset

                // Stagger angles slightly based on hop count for visual separation
                let angleOffset = Double(simPeer.hops) * 0.15
                let angle = (2.0 * Double.pi * Double(index) / Double(max(simCount, 1))) - Double.pi / 2.0 + angleOffset

                let position = CGPoint(
                    x: center.x + CGFloat(simRadius) * CGFloat(cos(angle)),
                    y: center.y + CGFloat(simRadius) * CGFloat(sin(angle)) * 0.75
                )

                result.append(NetworkNode(
                    id: simPeer.id,
                    displayName: simPeer.name,
                    position: position,
                    hops: simPeer.hops,
                    isConnected: simPeer.hops == 1,
                    nodeType: simPeer.hops == 1 ? .peer : .remote,
                    routedThrough: nil,
                    isGateway: simPeer.isGateway,
                    isSimulated: true,
                    location: simPeer.location,
                    batteryLevel: simPeer.batteryLevel
                ))
            }
        }

        return result
    }

    // MARK: - Direct Connection (Solid Line)
    // Draws a solid curved line from self to a directly connected peer

    private func drawDirectConnection(
        context: inout GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        phase: CGFloat,
        isSelected: Bool
    ) {
        let midX = (from.x + to.x) / 2
        let midY = (from.y + to.y) / 2
        let distance = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
        let hillHeight = distance * 0.35

        let controlPoint = CGPoint(x: midX, y: midY - hillHeight)

        var path = Path()
        path.move(to: from)
        path.addQuadCurve(to: to, control: controlPoint)

        let lineWidth: CGFloat = isSelected ? 3.0 : 2.5

        // Glow/shadow
        context.stroke(
            path,
            with: .color(Color.black.opacity(0.1)),
            style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round)
        )

        // Solid line for direct connection
        context.stroke(
            path,
            with: .color(Color.black.opacity(isSelected ? 1.0 : 0.8)),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )

        // Animated data packet
        let dotPosition = pointOnQuadCurve(from: from, to: to, control: controlPoint, t: phase)
        let dotPath = Path(ellipseIn: CGRect(x: dotPosition.x - 4, y: dotPosition.y - 4, width: 8, height: 8))
        context.fill(dotPath, with: .color(Color.black))
    }

    // MARK: - Mesh Routes (Solid Lines - messages can be transmitted)
    // Draws solid lines from direct peers to remote nodes showing message routing path

    private func drawMeshRoutes(
        context: inout GraphicsContext,
        directPeers: [NetworkNode],
        remoteNodes: [NetworkNode],
        phase: CGFloat,
        selectedId: String?
    ) {
        guard !directPeers.isEmpty else { return }

        for remoteNode in remoteNodes {
            // Use the actual routing peer if known, otherwise find nearest
            let routingPeer: NetworkNode?
            if let routedThrough = remoteNode.routedThrough {
                routingPeer = directPeers.first(where: { $0.id == routedThrough })
            } else {
                // Fallback: find nearest peer
                routingPeer = directPeers.min(by: { peer1, peer2 in
                    let dist1 = sqrt(pow(peer1.position.x - remoteNode.position.x, 2) +
                                    pow(peer1.position.y - remoteNode.position.y, 2))
                    let dist2 = sqrt(pow(peer2.position.x - remoteNode.position.x, 2) +
                                    pow(peer2.position.y - remoteNode.position.y, 2))
                    return dist1 < dist2
                })
            }

            guard let peer = routingPeer else { continue }

            // Draw solid line from routing peer to remote node (messages CAN be transmitted)
            let from = peer.position
            let to = remoteNode.position

            let midX = (from.x + to.x) / 2
            let midY = (from.y + to.y) / 2
            let distance = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
            let hillHeight = distance * 0.2

            let controlPoint = CGPoint(x: midX, y: midY - hillHeight)

            var path = Path()
            path.move(to: from)
            path.addQuadCurve(to: to, control: controlPoint)

            let isSelected = selectedId == remoteNode.id
            let opacity = isSelected ? 0.7 : 0.5
            let lineWidth: CGFloat = isSelected ? 2.0 : 1.5

            // Glow/shadow for mesh route
            context.stroke(
                path,
                with: .color(Color.black.opacity(0.05)),
                style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round)
            )

            // Solid line for mesh connection (thinner than direct connections)
            context.stroke(
                path,
                with: .color(Color.black.opacity(opacity)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            // Small animated dot moving along the line (showing message relay)
            let slowPhase = phase.truncatingRemainder(dividingBy: 1.0)
            let dotPosition = pointOnQuadCurve(from: from, to: to, control: controlPoint, t: slowPhase)
            let dotPath = Path(ellipseIn: CGRect(x: dotPosition.x - 2.5, y: dotPosition.y - 2.5, width: 5, height: 5))
            context.fill(dotPath, with: .color(Color.black.opacity(0.6)))
        }
    }

    // Legacy function - keeping for reference but not used
    private func drawHillEdge(
        context: inout GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        hops: Int,
        phase: CGFloat,
        isActive: Bool,
        isSelected: Bool
    ) {
        let midX = (from.x + to.x) / 2
        let midY = (from.y + to.y) / 2
        let distance = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
        let hillHeight = distance * 0.4

        let controlPoint = CGPoint(x: midX, y: midY - hillHeight)

        var path = Path()
        path.move(to: from)
        path.addQuadCurve(to: to, control: controlPoint)

        let opacity = isSelected ? 1.0 : (isActive ? 0.8 : 0.25)
        let lineWidth: CGFloat = isSelected ? 3.0 : (isActive ? 2.0 : 1.0)

        // Shadow
        context.stroke(
            path,
            with: .color(Color.black.opacity(0.05)),
            style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round)
        )

        // Main edge
        context.stroke(
            path,
            with: .color(Color.black.opacity(opacity)),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )

        // Animated dot
        if isActive {
            let dotPosition = pointOnQuadCurve(from: from, to: to, control: controlPoint, t: phase)
            let shadowPath = Path(ellipseIn: CGRect(x: dotPosition.x - 6, y: dotPosition.y - 4, width: 12, height: 8))
            context.fill(shadowPath, with: .color(Color.black.opacity(0.1)))

            let dotPath = Path(ellipseIn: CGRect(x: dotPosition.x - 4, y: dotPosition.y - 4, width: 8, height: 8))
            context.fill(dotPath, with: .color(Color.black))
        }
    }

    private func drawPeerConnections(context: inout GraphicsContext, nodes: [NetworkNode], phase: CGFloat) {
        let connectedNodes = nodes.filter { $0.isConnected && $0.id != "self" }

        for i in 0..<connectedNodes.count {
            for j in (i+1)..<connectedNodes.count {
                let from = connectedNodes[i].position
                let to = connectedNodes[j].position

                let midX = (from.x + to.x) / 2
                let midY = (from.y + to.y) / 2
                let distance = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
                let hillHeight = distance * 0.3

                let controlPoint = CGPoint(x: midX, y: midY - hillHeight)

                var path = Path()
                path.move(to: from)
                path.addQuadCurve(to: to, control: controlPoint)

                context.stroke(
                    path,
                    with: .color(Color.black.opacity(0.12)),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [6, 4])
                )
            }
        }
    }

    private func drawFlatNode(
        context: inout GraphicsContext,
        node: NetworkNode,
        isSelected: Bool,
        pulseScale: CGFloat,
        floatOffset: CGFloat = 0
    ) {
        let baseSize: CGFloat
        let fillOpacity: Double

        switch node.nodeType {
        case .self:
            baseSize = 40  // Increased for better visibility
            fillOpacity = 1.0
        case .peer:
            baseSize = 30  // Increased for better visibility
            fillOpacity = 0.85
        case .remote:
            baseSize = 22  // Increased for better visibility
            fillOpacity = 0.5
        }

        let size = baseSize * (isSelected ? 1.25 : pulseScale)
        let actualOpacity = isSelected ? 1.0 : fillOpacity

        // Calculate floating offset for this node (creates gentle bobbing motion)
        let nodeHash = abs(node.id.hashValue)
        let floatSpeed = 0.5 + Double(nodeHash % 100) / 200.0  // Vary speed per node
        let floatAmount: CGFloat = node.nodeType == .self ? 0 : (isSelected ? 0 : 4)
        let yOffset = sin(Double(floatPhase) * .pi * 2 * floatSpeed) * Double(floatAmount)

        // Adjusted position with float
        let drawPosition = CGPoint(x: node.position.x, y: node.position.y + CGFloat(yOffset))

        // Gateway nodes are green, simulated nodes have purple tint, others are black
        var nodeColor: Color = node.isGateway ? .green : .black
        if node.isSimulated && !node.isGateway {
            nodeColor = Color(red: 0.3, green: 0.2, blue: 0.4)  // Dark purple for simulated
        }

        // Shadow (moves with float)
        let shadowRect = CGRect(
            x: drawPosition.x - size * 0.5,
            y: drawPosition.y + size * 0.35 - CGFloat(yOffset) * 0.5,
            width: size,
            height: size * 0.25
        )
        context.fill(Path(ellipseIn: shadowRect), with: .color(nodeColor.opacity(isSelected ? 0.25 : 0.12)))

        // Selection ring
        if isSelected {
            let selectionRect = CGRect(
                x: drawPosition.x - size / 2 - 8,
                y: drawPosition.y - size / 2 - 8,
                width: size + 16,
                height: size + 16
            )
            context.stroke(
                Path(ellipseIn: selectionRect),
                with: .color(nodeColor.opacity(0.4)),
                style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
            )
        }

        // Outer glow ring
        let outerRect = CGRect(
            x: drawPosition.x - size / 2 - 3,
            y: drawPosition.y - size / 2 - 3,
            width: size + 6,
            height: size + 6
        )
        context.stroke(
            Path(ellipseIn: outerRect),
            with: .color(nodeColor.opacity(actualOpacity * 0.25)),
            style: StrokeStyle(lineWidth: 1.5)
        )

        // Main node
        let rect = CGRect(
            x: drawPosition.x - size / 2,
            y: drawPosition.y - size / 2,
            width: size,
            height: size
        )
        context.fill(Path(ellipseIn: rect), with: .color(nodeColor.opacity(actualOpacity)))

        // Inner dot for self
        if node.nodeType == .self {
            let innerRect = CGRect(x: drawPosition.x - 6, y: drawPosition.y - 6, width: 12, height: 12)
            context.fill(Path(ellipseIn: innerRect), with: .color(.white))
        }

        // Gateway indicator icon (wifi symbol) for gateway nodes
        if node.isGateway && node.nodeType == .self {
            let iconY = drawPosition.y - size / 2 - 16
            context.draw(
                Text(Image(systemName: "wifi"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green),
                at: CGPoint(x: drawPosition.x, y: iconY)
            )
        }

        // Simulated indicator
        if node.isSimulated {
            let simY = drawPosition.y - size / 2 - 12
            context.draw(
                Text("SIM")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.purple),
                at: CGPoint(x: drawPosition.x, y: simY)
            )
        }

        // Label
        if node.nodeType == .self || node.isConnected || isSelected {
            let labelY = drawPosition.y + size / 2 + 18
            let labelPoint = CGPoint(x: drawPosition.x, y: labelY)

            let labelColor: Color = node.isGateway ? .green : (node.isSimulated ? .purple : .black)
            context.draw(
                Text(node.displayName)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(labelColor),
                at: labelPoint
            )
        }
    }

    private func pointOnQuadCurve(from: CGPoint, to: CGPoint, control: CGPoint, t: CGFloat) -> CGPoint {
        let t1 = 1 - t
        return CGPoint(
            x: t1 * t1 * from.x + 2 * t1 * t * control.x + t * t * to.x,
            y: t1 * t1 * from.y + 2 * t1 * t * control.y + t * t * to.y
        )
    }
}

// MARK: - Supporting Types

struct NetworkNode: Identifiable, Equatable {
    let id: String
    let displayName: String
    let position: CGPoint
    let hops: Int
    let isConnected: Bool
    let nodeType: NodeType
    let routedThrough: String?  // ID of the peer this node is routed through
    let isGateway: Bool  // Whether this node is acting as a gateway to the internet
    var isSimulated: Bool = false  // Whether this is a simulated peer
    var location: CLLocationCoordinate2D? = nil  // GPS location if available
    var batteryLevel: Int = -1  // Battery level (-1 = unknown)

    enum NodeType {
        case `self`, peer, remote
    }

    static func == (lhs: NetworkNode, rhs: NetworkNode) -> Bool {
        lhs.id == rhs.id
    }
}

struct StatBadgeBW: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct MinimalGrid: View {
    var body: some View {
        Canvas { context, size in
            let gridSpacing: CGFloat = 50
            let lineColor = Color.black.opacity(0.04)

            var y: CGFloat = gridSpacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
                y += gridSpacing
            }

            var x: CGFloat = gridSpacing
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
                x += gridSpacing
            }

            let centerX = size.width / 2
            let centerY = size.height / 2 + 20

            var hLine = Path()
            hLine.move(to: CGPoint(x: centerX - 30, y: centerY))
            hLine.addLine(to: CGPoint(x: centerX + 30, y: centerY))
            context.stroke(hLine, with: .color(Color.black.opacity(0.1)), lineWidth: 1)

            var vLine = Path()
            vLine.move(to: CGPoint(x: centerX, y: centerY - 30))
            vLine.addLine(to: CGPoint(x: centerX, y: centerY + 30))
            context.stroke(vLine, with: .color(Color.black.opacity(0.1)), lineWidth: 1)
        }
    }
}
