import Foundation
import CryptoKit

@main
enum WebsiteVaultCheck {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let origin = URL(string: "https://3377test.erg3be.workers.dev/")!
        let key = SymmetricKey(size: .bits256)
        let provider = { key }
        let state = ["demoActivationToken": "saved-token", "licenceDetails": "{\"photo\":\"data:image/jpeg;base64,AAAA\"}",
                     "demoProfileSettings": "{\"pin\":\"1234\"}", "demoProfileSettingsOwner": "saved-token",
                     "svcOrder": "[6,5,4,3,2,1,0]", "demoSecuritySettings": "{\"lockMinutes\":15}"]
        let first = WebsiteStateVault(origin: origin, directory: directory, keyProvider: provider)
        precondition(first.accept(state)); first.flush()
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        precondition(files.count == 1)
        let encrypted = try Data(contentsOf: files[0])
        precondition(encrypted.range(of: Data("saved-token".utf8)) == nil)
        let afterReinstall = WebsiteStateVault(origin: origin, directory: directory, keyProvider: provider)
        precondition(afterReinstall.values == state, "Same-container reinstall lost state")
        let script = afterReinstall.script(template: "const saved = __WEBSITE_STATE__;")!
        precondition(script.contains("saved-token") && !script.contains("__WEBSITE_STATE__"))
        precondition(!afterReinstall.accept(["adminToken": "never-copy"]))
        precondition(!afterReinstall.accept(["demoActivationToken": String(repeating: "x", count: 4097)]))
        precondition(!afterReinstall.accept(["demoActivationToken": 42]))
        precondition(afterReinstall.values == state)
        let otherOrigin = WebsiteStateVault(origin: URL(string: "https://other.example/")!, directory: directory, keyProvider: provider)
        precondition(otherOrigin.values.isEmpty)
        let wrongKey = WebsiteStateVault(origin: origin, directory: directory, keyProvider: { SymmetricKey(size: .bits256) })
        precondition(wrongKey.values.isEmpty)
        var damaged = encrypted; damaged[damaged.count - 1] ^= 1
        try damaged.write(to: files[0])
        precondition(WebsiteStateVault(origin: origin, directory: directory, keyProvider: provider).values.isEmpty)
        try encrypted.write(to: files[0])
        precondition(afterReinstall.accept([:])); afterReinstall.flush()
        precondition(!FileManager.default.fileExists(atPath: files[0].path))
        precondition(WebsiteStateVault(origin: origin, directory: directory, keyProvider: provider).values.isEmpty)
        print("PASS: encrypted reinstall recovery, original activation, origin isolation, tamper rejection and explicit forgetting")
    }
}
