import Foundation

/// The role of a user in the safety mesh network
enum UserRole: String, Codable, CaseIterable, Identifiable {
    case civilian = "civilian"
    case security = "security"
    case admin = "admin"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .civilian: return "Community Member"
        case .security: return "Security Personnel"
        case .admin: return "Administrator"
        }
    }

    var icon: String {
        switch self {
        case .civilian: return "person.fill"
        case .security: return "shield.checkered"
        case .admin: return "person.badge.key.fill"
        }
    }
}

/// Duty status for security personnel
enum DutyStatus: String, Codable, CaseIterable, Identifiable {
    case offDuty = "off_duty"
    case onDuty = "on_duty"
    case responding = "responding"  // Actively responding to an incident
    case unavailable = "unavailable"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .offDuty: return "Off Duty"
        case .onDuty: return "On Duty"
        case .responding: return "Responding"
        case .unavailable: return "Unavailable"
        }
    }
}

/// Skills that can be tagged on a user profile for first-responder matching
enum UserSkill: String, Codable, CaseIterable, Identifiable {
    case cpr = "cpr"
    case firstAid = "first_aid"
    case emt = "emt"
    case security = "security"
    case lawEnforcement = "law_enforcement"
    case firefighter = "firefighter"
    case mentalHealth = "mental_health"
    case campusPolice = "campus_police"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cpr: return "CPR Certified"
        case .firstAid: return "First Aid"
        case .emt: return "EMT / Paramedic"
        case .security: return "Security Guard"
        case .lawEnforcement: return "Law Enforcement"
        case .firefighter: return "Firefighter"
        case .mentalHealth: return "Mental Health"
        case .campusPolice: return "Campus Police"
        }
    }

    var icon: String {
        switch self {
        case .cpr: return "heart.fill"
        case .firstAid: return "cross.case.fill"
        case .emt: return "staroflife.fill"
        case .security: return "shield.checkered"
        case .lawEnforcement: return "star.shield.fill"
        case .firefighter: return "flame.fill"
        case .mentalHealth: return "brain.head.profile"
        case .campusPolice: return "building.columns.fill"
        }
    }
}

/// Incident types for classification
enum IncidentType: String, Codable, CaseIterable, Identifiable {
    case robbery = "robbery"
    case assault = "assault"
    case carBreakIn = "car_break_in"
    case harassment = "harassment"
    case suspicious = "suspicious_activity"
    case medical = "medical_emergency"
    case theft = "theft"
    case vandalism = "vandalism"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .robbery: return "Robbery"
        case .assault: return "Assault"
        case .carBreakIn: return "Car Break-In"
        case .harassment: return "Harassment"
        case .suspicious: return "Suspicious Activity"
        case .medical: return "Medical Emergency"
        case .theft: return "Theft"
        case .vandalism: return "Vandalism"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .robbery: return "banknote.fill"
        case .assault: return "exclamationmark.shield.fill"
        case .carBreakIn: return "car.fill"
        case .harassment: return "hand.raised.slash.fill"
        case .suspicious: return "eye.trianglebadge.exclamationmark.fill"
        case .medical: return "staroflife.fill"
        case .theft: return "bag.fill"
        case .vandalism: return "hammer.fill"
        case .other: return "questionmark.circle.fill"
        }
    }

    /// Base severity score for this incident type
    var baseSeverity: Int {
        switch self {
        case .assault: return 8
        case .robbery: return 7
        case .medical: return 7
        case .carBreakIn: return 4
        case .harassment: return 5
        case .suspicious: return 3
        case .theft: return 5
        case .vandalism: return 3
        case .other: return 4
        }
    }
}

// MARK: - Organization / Community

/// The organization or community a user belongs to
enum Organization: String, Codable, CaseIterable, Identifiable {
    case drexel = "drexel"
    case temple = "temple"
    case upenn = "upenn"
    case villanova = "villanova"
    case septa = "septa"
    case universityCity = "university_city"
    case community = "community"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .drexel: return "Drexel University"
        case .temple: return "Temple University"
        case .upenn: return "University of Pennsylvania"
        case .villanova: return "Villanova University"
        case .septa: return "SEPTA Transit"
        case .universityCity: return "University City"
        case .community: return "Philadelphia Community"
        }
    }

    var shortName: String {
        switch self {
        case .drexel: return "Drexel"
        case .temple: return "Temple"
        case .upenn: return "UPenn"
        case .villanova: return "Villanova"
        case .septa: return "SEPTA"
        case .universityCity: return "Univ. City"
        case .community: return "Philly"
        }
    }

    var icon: String {
        switch self {
        case .drexel, .temple, .upenn, .villanova: return "building.columns.fill"
        case .septa: return "tram.fill"
        case .universityCity: return "map.fill"
        case .community: return "person.3.fill"
        }
    }
}

// MARK: - Security Organization

/// The security organization a guard belongs to — separate from community org
enum SecurityOrganization: String, Codable, CaseIterable, Identifiable {
    case phillyPD = "philly_pd"
    case drexelPolice = "drexel_police"
    case upennPolice = "upenn_police"
    case templePolice = "temple_police"
    case septaPolice = "septa_police"
    case campusSecurity = "campus_security"
    case privateSecurity = "private_security"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .phillyPD: return "Philadelphia Police"
        case .drexelPolice: return "Drexel Public Safety"
        case .upennPolice: return "Penn Police"
        case .templePolice: return "Temple Police"
        case .septaPolice: return "SEPTA Transit Police"
        case .campusSecurity: return "Campus Security"
        case .privateSecurity: return "Private Security"
        }
    }

    var shortName: String {
        switch self {
        case .phillyPD: return "Philly PD"
        case .drexelPolice: return "Drexel PS"
        case .upennPolice: return "Penn PD"
        case .templePolice: return "Temple PD"
        case .septaPolice: return "SEPTA PD"
        case .campusSecurity: return "Campus Sec"
        case .privateSecurity: return "Private Sec"
        }
    }

    var icon: String {
        switch self {
        case .phillyPD: return "star.shield.fill"
        case .drexelPolice, .upennPolice, .templePolice: return "building.columns.fill"
        case .septaPolice: return "tram.fill"
        case .campusSecurity: return "shield.checkered"
        case .privateSecurity: return "shield.fill"
        }
    }

    /// Which community orgs this security org covers
    var coverageArea: [Organization] {
        switch self {
        case .phillyPD: return Organization.allCases // City-wide
        case .drexelPolice: return [.drexel, .universityCity]
        case .upennPolice: return [.upenn, .universityCity]
        case .templePolice: return [.temple]
        case .septaPolice: return [.septa]
        case .campusSecurity: return [.drexel, .temple, .upenn, .villanova]
        case .privateSecurity: return Organization.allCases
        }
    }
}
