import Foundation
import Security

protocol SpotifyTokenStore: Sendable {
    func load() throws -> SpotifyTokens?
    func save(_ tokens: SpotifyTokens) throws
    func delete() throws
}

/// Immutable query identity; Security operations are synchronous/thread-safe. No shared access group.
final class KeychainSpotifyTokenStore: SpotifyTokenStore, @unchecked Sendable {
    private let service: String
    private let account: String
    init(service: String, clientID: String) { self.service = service; account = clientID }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false]
    }
    func load() throws -> SpotifyTokens? {
        var query = self.query
        query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let tokens = try? JSONDecoder().decode(SpotifyTokens.self, from: data) else { throw SpotifyWebError.secureStorage }
        return tokens
    }
    func save(_ tokens: SpotifyTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; attributes.forEach { item[$0.key] = $0.value }
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw SpotifyWebError.secureStorage }
    }
    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SpotifyWebError.secureStorage }
    }
}
