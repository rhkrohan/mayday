import Foundation
import Combine

class MeshViewModel: ObservableObject {
    let meshService = MeshNetworkService.shared
    let messageStore = MessageStore.shared

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward changes from nested ObservableObjects
        meshService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        messageStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Start mesh on init
        meshService.start()
    }

    deinit {
        meshService.stop()
    }

    var statusText: String {
        switch meshService.networkStatus {
        case .offline:
            return "Offline - Searching..."
        case .connecting:
            return "Connecting..."
        case .online:
            return "Online - \(meshService.connectedPeers.count) peers"
        }
    }

    var statusColor: String {
        switch meshService.networkStatus {
        case .offline: return "red"
        case .connecting: return "orange"
        case .online: return "green"
        }
    }
}
