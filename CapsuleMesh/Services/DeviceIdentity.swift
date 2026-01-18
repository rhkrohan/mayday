import Foundation
import UIKit

class DeviceIdentity: ObservableObject {
    static let shared = DeviceIdentity()

    private let deviceIdKey = "CapsuleMesh.DeviceId"
    private let deviceNameKey = "CapsuleMesh.DeviceName"
    private let onboardingCompleteKey = "CapsuleMesh.OnboardingComplete"
    private let userRoleKey = "CapsuleMesh.UserRole"
    private let dutyStatusKey = "CapsuleMesh.DutyStatus"
    private let userSkillsKey = "CapsuleMesh.UserSkills"
    private let securityCodeKey = "CapsuleMesh.SecurityCode"
    private let organizationKey = "CapsuleMesh.Organization"
    private let securityOrgKey = "CapsuleMesh.SecurityOrg"

    var deviceId: String {
        if let stored = UserDefaults.standard.string(forKey: deviceIdKey) {
            return stored
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: deviceIdKey)
        return newId
    }

    var deviceName: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: deviceNameKey) {
                return stored
            }
            let suffix = String(deviceId.prefix(4))
            return "Mayday-\(suffix)"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: deviceNameKey)
            objectWillChange.send()
        }
    }

    var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: onboardingCompleteKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: onboardingCompleteKey)
        }
    }

    // MARK: - Role & Security

    @Published var userRole: UserRole = .civilian {
        didSet {
            UserDefaults.standard.set(userRole.rawValue, forKey: userRoleKey)
        }
    }

    @Published var dutyStatus: DutyStatus = .offDuty {
        didSet {
            UserDefaults.standard.set(dutyStatus.rawValue, forKey: dutyStatusKey)
        }
    }

    @Published var userSkills: [UserSkill] = [] {
        didSet {
            let rawValues = userSkills.map { $0.rawValue }
            UserDefaults.standard.set(rawValues, forKey: userSkillsKey)
        }
    }

    @Published var organization: Organization = .community {
        didSet {
            UserDefaults.standard.set(organization.rawValue, forKey: organizationKey)
        }
    }

    @Published var securityOrganization: SecurityOrganization? = nil {
        didSet {
            UserDefaults.standard.set(securityOrganization?.rawValue, forKey: securityOrgKey)
        }
    }

    /// Whether this device belongs to security personnel
    var isSecurity: Bool {
        userRole == .security || userRole == .admin
    }

    /// Whether security is currently on duty
    var isOnDuty: Bool {
        isSecurity && dutyStatus == .onDuty
    }

    /// Validate a security access code and assign security organization
    func activateSecurityRole(code: String, securityOrg: SecurityOrganization) -> Bool {
        let validPrefixes = ["SEC-", "GUARD-", "CAMPUS-", "SEPTA-", "PPD-", "DREXEL-", "PENN-", "TEMPLE-"]
        let isValid = validPrefixes.contains { code.uppercased().hasPrefix($0) }

        if isValid {
            userRole = .security
            securityOrganization = securityOrg
            UserDefaults.standard.set(code, forKey: securityCodeKey)
        }

        return isValid
    }

    /// Deactivate security role
    func deactivateSecurityRole() {
        userRole = .civilian
        dutyStatus = .offDuty
        UserDefaults.standard.removeObject(forKey: securityCodeKey)
    }

    private init() {
        // Load saved role
        if let roleRaw = UserDefaults.standard.string(forKey: userRoleKey),
           let role = UserRole(rawValue: roleRaw) {
            self.userRole = role
        }

        // Load saved duty status
        if let statusRaw = UserDefaults.standard.string(forKey: dutyStatusKey),
           let status = DutyStatus(rawValue: statusRaw) {
            self.dutyStatus = status
        }

        // Load saved skills
        if let rawValues = UserDefaults.standard.stringArray(forKey: userSkillsKey) {
            self.userSkills = rawValues.compactMap { UserSkill(rawValue: $0) }
        }

        // Load saved organization
        if let orgRaw = UserDefaults.standard.string(forKey: organizationKey),
           let org = Organization(rawValue: orgRaw) {
            self.organization = org
        }

        // Load saved security organization
        if let secOrgRaw = UserDefaults.standard.string(forKey: securityOrgKey),
           let secOrg = SecurityOrganization(rawValue: secOrgRaw) {
            self.securityOrganization = secOrg
        }
    }
}
