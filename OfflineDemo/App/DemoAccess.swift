import Foundation
import CryptoKit
import Security

enum DemoAccess {
    private struct ActivationConfig: Decodable {
        let maxDevices: Int
        let publicKey: Data
    }

    private static let config: ActivationConfig? = {
        guard let url = Bundle.main.url(forResource: "activation-public-key", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(ActivationConfig.self, from: data),
              config.maxDevices == 200 else { return nil }
        return config
    }()

    private static let deviceID: Data? = {
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.accesshub.winterstudio.offline.activation",
            kSecAttrAccount as String: "device-seed-v1",
            kSecAttrSynchronizable as String: false
        ]
        func readSeed() -> (OSStatus, Data?) {
            var query = identity
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            return (status, result as? Data)
        }

        let (status, existing) = readSeed()
        if status == errSecSuccess, let existing, existing.count == 32 {
            return Data(SHA256.hash(data: existing))
        }
        guard status == errSecItemNotFound else { return nil }
        var seed = Data(count: 32)
        let generated = seed.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
            guard let address = bytes.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, bytes.count, address)
        }
        guard generated == errSecSuccess else { return nil }
        var newItem = identity
        newItem[kSecValueData as String] = seed
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let saved = SecItemAdd(newItem as CFDictionary, nil)
        if saved == errSecDuplicateItem, let duplicate = readSeed().1, duplicate.count == 32 {
            return Data(SHA256.hash(data: duplicate))
        }
        return saved == errSecSuccess ? Data(SHA256.hash(data: seed)) : nil
    }()

    static var requestCode: String? {
        deviceID.map { "WD-" + $0.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "") }
    }

    static func accept(_ code: String) -> String? {
        let cleaned = String(code.filter { !$0.isWhitespace })
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"), cleaned == "WINTER-UI-TEST-ONLY" {
            return cleaned
        }
        #endif
        guard cleaned.hasPrefix("WA-"), cleaned.utf8.count == 135, let config, let deviceID,
              verifies(cleaned, deviceID: deviceID, publicKey: config.publicKey) else { return nil }
        return cleaned
    }

    static func verifies(_ cleaned: String, deviceID: Data, publicKey publicBytes: Data) -> Bool {
        guard cleaned.hasPrefix("WA-"), cleaned.utf8.count == 135 else { return false }
        let base64 = cleaned.dropFirst(3).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        guard let signed = Data(base64Encoded: base64), signed.count == 99, signed[0] == 1 else { return false }
        let slot = Int(signed[1]) * 256 + Int(signed[2])
        guard (1...200).contains(slot), Data(signed[3..<35]) == deviceID,
              let publicKey = try? P256.Signing.PublicKey(x963Representation: publicBytes),
              let signature = try? P256.Signing.ECDSASignature(rawRepresentation: Data(signed.suffix(64))) else { return false }
        return publicKey.isValidSignature(signature, for: Data(signed.prefix(35)))
    }
}
