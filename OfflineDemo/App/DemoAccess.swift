import Foundation
import CryptoKit

enum DemoAccess {
    static let testCode = "WINTER-UI-TEST-ONLY"
    static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static let hashes: Set<String> = {
        guard let url = Bundle.main.url(forResource: "demo-key-hashes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(values)
    }()
    static func contains(hash: String) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"), hash == digest(testCode) { return true }
        #endif
        return hashes.contains(hash)
    }
    static func accept(_ code: String) -> String? {
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleaned.isEmpty else { return nil }
        let hash = digest(cleaned)
        return contains(hash: hash) ? hash : nil
    }
}
