import Foundation

@main
enum AccessPolicyCheck {
    static func main() {
        let policy = NativeAccessPolicy(origin: URL(string: "https://3377test.erg3be.workers.dev/")!)
        for url in ["https://3377test.erg3be.workers.dev/", "https://3377test.erg3be.workers.dev:443/path?a=1"] {
            precondition(policy.isWebsite(URL(string: url)!))
        }
        for url in ["http://3377test.erg3be.workers.dev/", "https://3377test.erg3be.workers.dev.attacker.example/",
                    "https://attacker.example/", "https://user:password@3377test.erg3be.workers.dev/",
                    "https://3377test.erg3be.workers.dev:8443/", "file:///private/data", "javascript:alert(1)"] {
            precondition(!policy.isWebsite(URL(string: url)!), url)
        }
        for url in ["https://example.org/help", "http://example.org/help", "mailto:help@example.org", "tel:+61412345678"] {
            precondition(policy.permitsExternal(URL(string: url)!), url)
        }
        for url in ["file:///private/data", "javascript:alert(1)", "data:text/html,test", "app-settings:",
                    "https://user:password@example.org/", "https://example.org/" + String(repeating: "x", count: 4096)] {
            precondition(!policy.permitsExternal(URL(string: url)!), url)
        }
        precondition(policy.trusts(protocol: "https", host: "3377test.erg3be.workers.dev", port: 0))
        precondition(!policy.trusts(protocol: "http", host: "3377test.erg3be.workers.dev", port: 0))
        print("PASS: exact HTTPS origin, credentials/port/scheme rejection and bounded external links")
        if CommandLine.arguments.count == 2 {
            let session = URLSession(configuration: .ephemeral, delegate: NoAuthenticationRedirects(), delegateQueue: .main)
            var request = URLRequest(url: URL(string: CommandLine.arguments[1])!)
            request.httpMethod = "POST"
            request.httpBody = Data("test-credential".utf8)
            var completed = false
            var status = 0
            session.dataTask(with: request) { _, response, _ in
                status = (response as? HTTPURLResponse)?.statusCode ?? 0
                completed = true
            }.resume()
            let deadline = Date().addingTimeInterval(10)
            while !completed && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            session.invalidateAndCancel()
            precondition(completed && status == 307, "Authentication redirect was followed or test failed")
            print("PASS: authentication POST redirect rejected by URLSession")
        }
    }
}
