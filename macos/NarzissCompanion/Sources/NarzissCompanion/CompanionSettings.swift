import Foundation
import NarzissCompanionCore

@MainActor
final class CompanionSettings: ObservableObject {
    @Published var profile: CompanionProfile
    @Published var saveMessage = ""

    private let defaults: UserDefaults
    private static let profileKey = "companion.profile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let data = defaults.data(forKey: Self.profileKey),
            let decoded = try? JSONDecoder().decode(CompanionProfile.self, from: data)
        {
            profile = decoded
        } else {
            profile = CompanionProfile()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.profileKey)
        }

        saveMessage = "设置已保存。"
    }
}
