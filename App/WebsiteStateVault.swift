import Foundation
import CryptoKit
import Security

struct WebsiteStateSnapshot: Codable {
    let origin: String
    let values: [String: String]
    static let limits = ["demoActivationToken": 4096, "licenceDetails": 6 * 1024 * 1024,
                         "demoProfileSettings": 65536, "demoProfileSettingsOwner": 4096,
                         "demoSecuritySettings": 4096, "svcOrder": 4096, "accessHubDemoAccountEmail": 1024]
    static let maxBytes = 8 * 1024 * 1024

    static func filtered(_ input: Any) -> [String: String]? {
        guard let values = input as? [String: String], values.count <= limits.count,
              values.allSatisfy({ key, value in limits[key].map { value.utf8.count <= $0 } ?? false }) else { return nil }
        // An explicit token removal also forgets the backup, so logout/revocation
        // cannot resurrect an old session or attach settings to another customer.
        guard let token = values["demoActivationToken"], !token.isEmpty else { return [:] }
        return values
    }
}

// A same-installation recovery copy for WebKit storage loss. App replacement keeps
// Application Support and Keychain; deleting the app is not a supported recovery path.
final class WebsiteStateVault {
    private let origin: String
    private let file: URL
    private let keyProvider: () throws -> SymmetricKey
    private let writer = DispatchQueue(label: "dev.accesshub.website-state", qos: .utility)
    private(set) var values: [String: String] = [:]

    init(origin: URL, directory: URL? = nil, keyProvider: (() throws -> SymmetricKey)? = nil) {
        self.origin = origin.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let identity = SHA256.hash(data: Data(self.origin.utf8)).map { String(format: "%02x", $0) }.joined()
        let folder = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WebsiteState", isDirectory: true)
        self.file = folder.appendingPathComponent(identity + ".sealed")
        self.keyProvider = keyProvider ?? { try Self.encryptionKey(account: identity) }
        if let data = try? Data(contentsOf: file), data.count <= WebsiteStateSnapshot.maxBytes,
           let key = try? self.keyProvider(), let box = try? AES.GCM.SealedBox(combined: data),
           let plain = try? AES.GCM.open(box, using: key, authenticating: Data(self.origin.utf8)),
           let saved = try? JSONDecoder().decode(WebsiteStateSnapshot.self, from: plain), saved.origin == self.origin,
           let filtered = WebsiteStateSnapshot.filtered(saved.values) { values = filtered }
    }

    func script(template: String) -> String? {
        guard let data = try? JSONEncoder().encode(WebsiteStateSnapshot(origin: origin, values: values)),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return template.replacingOccurrences(of: "__WEBSITE_STATE__", with: json
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029"))
    }

    @discardableResult func accept(_ input: Any) -> Bool {
        guard let next = WebsiteStateSnapshot.filtered(input) else { return false }
        if next == values { return true }
        values = next
        let snapshot = WebsiteStateSnapshot(origin: origin, values: next)
        writer.async { [self] in
            do {
                if snapshot.values.isEmpty {
                    if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
                    return
                }
                let plain = try JSONEncoder().encode(snapshot)
                guard plain.count <= WebsiteStateSnapshot.maxBytes else { return }
                let key = try keyProvider()
                let encrypted = try AES.GCM.seal(plain, using: key, authenticating: Data(origin.utf8)).combined!
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                #if os(iOS)
                try encrypted.write(to: file, options: [.atomic, .completeFileProtection])
                #else
                try encrypted.write(to: file, options: .atomic)
                #endif
                // This copy is device-bound; an iCloud restore cannot decrypt it.
                var target = file
                var flags = URLResourceValues(); flags.isExcludedFromBackup = true
                try target.setResourceValues(flags)
            } catch { NSLog("Website recovery copy could not be saved; persistent website storage remains unchanged.") }
        }
        return true
    }

    func flush() { writer.sync {} }

    private static func encryptionKey(account: String) throws -> SymmetricKey {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.accesshub.sidestoretest.website-state",
            kSecAttrAccount as String: account]
        var lookup = query; lookup[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 { return SymmetricKey(data: data) }
        guard status == errSecItemNotFound else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        let key = SymmetricKey(size: .bits256)
        var save = query
        save[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        save[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let saved = SecItemAdd(save as CFDictionary, nil)
        guard saved == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(saved)) }
        return key
    }
}
