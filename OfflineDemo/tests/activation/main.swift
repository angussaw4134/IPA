import Foundation

struct Fixture: Decodable {
    let publicKey: Data
    let device: Data
    let valid: String
    let tampered: String
    let overCap: String
}

let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let fixture = try JSONDecoder().decode(Fixture.self, from: data)
precondition(DemoAccess.verifies(fixture.valid, deviceID: fixture.device, publicKey: fixture.publicKey))
precondition(!DemoAccess.verifies(fixture.valid, deviceID: Data(repeating: 0, count: 32), publicKey: fixture.publicKey))
precondition(!DemoAccess.verifies(fixture.tampered, deviceID: fixture.device, publicKey: fixture.publicKey))
precondition(!DemoAccess.verifies(fixture.overCap, deviceID: fixture.device, publicKey: fixture.publicKey))
precondition(DemoAccess.accept("WINTER-UI-TEST-ONLY") == nil)
print("Verified issuer signatures, device binding, tamper rejection and the 200-slot limit in Swift.")
