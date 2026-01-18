import Foundation
import CoreLocation
import MapKit

enum MeshConstants {
    static let serviceType = "pigeon-mesh"  // Max 15 chars, lowercase + hyphens only
    static let maxHops = 10
    static let maxPeers = 8
    static let messageQueueSize = 500
    static let gatewayBroadcastInterval: TimeInterval = 30
    static let securityBroadcastInterval: TimeInterval = 15
    static let witnessCooldown: TimeInterval = 300
    static let panicEscalationThreshold = 3
}

// MARK: - Philadelphia Locations

enum PhillyLocations {
    static let center = CLLocationCoordinate2D(latitude: 39.9526, longitude: -75.1635)
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)

    static let universities: [(name: String, org: Organization, coord: CLLocationCoordinate2D)] = [
        ("Drexel University", .drexel, CLLocationCoordinate2D(latitude: 39.9566, longitude: -75.1899)),
        ("Temple University", .temple, CLLocationCoordinate2D(latitude: 39.9812, longitude: -75.1553)),
        ("University of Pennsylvania", .upenn, CLLocationCoordinate2D(latitude: 39.9522, longitude: -75.1932)),
        ("Villanova University", .villanova, CLLocationCoordinate2D(latitude: 40.0379, longitude: -75.3454)),
    ]

    static let septaStations: [(name: String, coord: CLLocationCoordinate2D)] = [
        ("City Hall Station", CLLocationCoordinate2D(latitude: 39.9526, longitude: -75.1635)),
        ("30th Street Station", CLLocationCoordinate2D(latitude: 39.9557, longitude: -75.1822)),
        ("Suburban Station", CLLocationCoordinate2D(latitude: 39.9538, longitude: -75.1680)),
        ("Jefferson Station", CLLocationCoordinate2D(latitude: 39.9525, longitude: -75.1581)),
        ("Temple University Station", CLLocationCoordinate2D(latitude: 39.9812, longitude: -75.1494)),
        ("University City Station", CLLocationCoordinate2D(latitude: 39.9483, longitude: -75.1903)),
    ]

    static let landmarks: [(name: String, coord: CLLocationCoordinate2D, icon: String)] = [
        ("Rittenhouse Square", CLLocationCoordinate2D(latitude: 39.9496, longitude: -75.1718), "leaf.fill"),
        ("Philadelphia Museum of Art", CLLocationCoordinate2D(latitude: 39.9656, longitude: -75.1810), "building.fill"),
        ("South Street", CLLocationCoordinate2D(latitude: 39.9429, longitude: -75.1499), "storefront.fill"),
        ("Reading Terminal Market", CLLocationCoordinate2D(latitude: 39.9533, longitude: -75.1592), "cart.fill"),
        ("Independence Hall", CLLocationCoordinate2D(latitude: 39.9489, longitude: -75.1500), "building.columns.fill"),
    ]

    /// Get the center coordinate for an organization
    static func center(for org: Organization) -> CLLocationCoordinate2D {
        switch org {
        case .drexel: return CLLocationCoordinate2D(latitude: 39.9566, longitude: -75.1899)
        case .temple: return CLLocationCoordinate2D(latitude: 39.9812, longitude: -75.1553)
        case .upenn: return CLLocationCoordinate2D(latitude: 39.9522, longitude: -75.1932)
        case .villanova: return CLLocationCoordinate2D(latitude: 40.0379, longitude: -75.3454)
        case .septa: return center
        case .universityCity: return CLLocationCoordinate2D(latitude: 39.9530, longitude: -75.1900)
        case .community: return center
        }
    }
}
