import SwiftUI

struct MeshVisualizationView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()

                    if viewModel.meshService.knownDevices.isEmpty && viewModel.meshService.connectedPeers.isEmpty {
                        emptyState
                    } else {
                        meshGraph(in: geometry.size)
                    }
                }
            }
            .navigationTitle("Mesh topology")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.meshService.discoverNetwork()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No mesh data")
                .font(.headline)

            Text("Discover the network to see the mesh topology")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Discover network") {
                viewModel.meshService.discoverNetwork()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding(40)
    }

    func meshGraph(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let nodes = buildNodes(center: center, size: size)

        return ZStack {
            // Draw edges (connections)
            ForEach(nodes.filter { $0.id != "self" }, id: \.id) { node in
                Path { path in
                    path.move(to: center)
                    path.addLine(to: node.position)
                }
                .stroke(
                    edgeColor(hops: node.hops),
                    style: StrokeStyle(lineWidth: edgeWidth(hops: node.hops), lineCap: .round)
                )
            }

            // Draw nodes
            ForEach(nodes, id: \.id) { node in
                NodeView(node: node, isSelf: node.id == "self")
                    .position(node.position)
            }

            // Legend
            VStack(alignment: .leading, spacing: 8) {
                Text("Connection strength")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(1...4, id: \.self) { hop in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(hopColor(hop))
                            .frame(width: 20, height: 4)
                        Text("\(hop) hop\(hop == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding()
        }
    }

    struct MeshNode: Identifiable {
        let id: String
        let displayName: String
        let position: CGPoint
        let hops: Int
        let isConnected: Bool
    }

    func buildNodes(center: CGPoint, size: CGSize) -> [MeshNode] {
        var nodes: [MeshNode] = []

        // Add self node at center
        nodes.append(MeshNode(
            id: "self",
            displayName: DeviceIdentity.shared.deviceName,
            position: center,
            hops: 0,
            isConnected: true
        ))

        // Add connected peers in inner ring
        let connectedCount = viewModel.meshService.connectedPeers.count
        let innerRadius = min(size.width, size.height) * 0.25

        for (index, peer) in viewModel.meshService.connectedPeers.enumerated() {
            let angle = (2.0 * Double.pi * Double(index) / Double(max(connectedCount, 1))) - Double.pi / 2.0
            let position = CGPoint(
                x: center.x + CGFloat(innerRadius) * CGFloat(cos(angle)),
                y: center.y + CGFloat(innerRadius) * CGFloat(sin(angle))
            )
            nodes.append(MeshNode(
                id: peer.id.displayName,
                displayName: peer.displayName,
                position: position,
                hops: 1,
                isConnected: true
            ))
        }

        // Get connected peer display names for filtering
        let connectedPeerNames = Set(viewModel.meshService.connectedPeers.map { $0.id.displayName })

        // Add known devices in outer rings based on hop count
        let knownDevices = viewModel.meshService.knownDevices
            .filter { device in
                !connectedPeerNames.contains(device.key)
            }
            .sorted { $0.value < $1.value }

        let groupedByHops = Dictionary(grouping: knownDevices, by: { $0.value })

        for (hops, devices) in groupedByHops.sorted(by: { $0.key < $1.key }) {
            let radius = min(size.width, size.height) * (0.25 + 0.15 * Double(hops))
            let deviceCount = devices.count

            for (index, device) in devices.enumerated() {
                let angle = (2.0 * Double.pi * Double(index) / Double(max(deviceCount, 1))) - Double.pi / 2.0 + Double(hops) * 0.3
                let position = CGPoint(
                    x: center.x + CGFloat(radius) * CGFloat(cos(angle)),
                    y: center.y + CGFloat(radius) * CGFloat(sin(angle))
                )
                nodes.append(MeshNode(
                    id: device.key,
                    displayName: String(device.key.prefix(8)),
                    position: position,
                    hops: hops,
                    isConnected: false
                ))
            }
        }

        return nodes
    }

    func edgeColor(hops: Int) -> Color {
        hopColor(hops).opacity(0.6)
    }

    func edgeWidth(hops: Int) -> CGFloat {
        max(1, 4 - CGFloat(hops))
    }

    func hopColor(_ hops: Int) -> Color {
        switch hops {
        case 0: return .accentColor
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        default: return .red
        }
    }
}

struct NodeView: View {
    let node: MeshVisualizationView.MeshNode
    let isSelf: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(nodeColor.opacity(0.15))
                    .frame(width: nodeSize + 8, height: nodeSize + 8)

                Circle()
                    .fill(nodeColor)
                    .frame(width: nodeSize, height: nodeSize)

                if isSelf {
                    Image(systemName: "iphone")
                        .font(.system(size: nodeSize * 0.4))
                        .foregroundStyle(.white)
                } else if node.isConnected {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: nodeSize * 0.35))
                        .foregroundStyle(.white)
                }
            }

            Text(node.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 60)
        }
    }

    var nodeSize: CGFloat {
        isSelf ? 44 : (node.isConnected ? 36 : 28)
    }

    var nodeColor: Color {
        if isSelf {
            return .accentColor
        }
        switch node.hops {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        default: return .red
        }
    }
}
