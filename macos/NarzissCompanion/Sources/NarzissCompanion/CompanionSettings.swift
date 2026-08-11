import Foundation
import NarzissCompanionCore

@MainActor
final class CompanionSettings: ObservableObject {
    @Published var profile: CompanionProfile
    @Published var apiKeyDraft = ""
    @Published private(set) var hasAPIKey: Bool
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
        hasAPIKey = KeychainStore.loadAPIKey() != nil
    }

    func save() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.profileKey)
        }

        let trimmedKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            do {
                try KeychainStore.saveAPIKey(trimmedKey)
                apiKeyDraft = ""
                hasAPIKey = true
                saveMessage = "设置已保存，API Key 已写入 Keychain。"
            } catch {
                saveMessage = error.localizedDescription
            }
        } else {
            saveMessage = "设置已保存。"
        }
    }

    func removeAPIKey() {
        KeychainStore.deleteAPIKey()
        apiKeyDraft = ""
        hasAPIKey = false
        saveMessage = "API Key 已从 Keychain 删除。"
    }

    func apiKey() -> String? {
        KeychainStore.loadAPIKey()
    }
}
