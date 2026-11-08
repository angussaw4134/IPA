import Foundation
import WebKit
import AppKit

// Exercise the actual WebKit compiler, not Foundation's more permissive regex
// parser. This catches startup failures which an IPA compilation cannot detect.
@main
@MainActor
enum ContentRulesCheck {
    static func compile(_ json: String, id: String, shouldSucceed: Bool) {
        var completed = false
        var accepted = false
        var failure = ""
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: id,
            encodedContentRuleList: json) { list, error in
                accepted = list != nil && error == nil
                failure = error?.localizedDescription ?? "No rule list"
                completed = true
            }
        let deadline = Date().addingTimeInterval(30)
        while !completed && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        guard completed, accepted == shouldSucceed else {
            fatalError("WebKit startup check failed (\(id)): \(failure); completed=\(completed)")
        }
        print("PASS WebKit compiler: \(id)")
    }

    static func main() throws {
        _ = NSApplication.shared
        let origin = URL(string: "https://3377test.erg3be.workers.dev/")!
        let json = try NativeContentRules.json(for: origin)
        let rules = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [[String: Any]]
        let expressions = try rules.map { rule -> NSRegularExpression in
            let trigger = rule["trigger"] as! [String: Any]
            return try NSRegularExpression(pattern: trigger["url-filter"] as! String)
        }
        func matches(_ url: String) -> Bool {
            expressions.contains { $0.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil }
        }
        for file in ["login-ui.js", "app-privacy.js"] {
            for suffix in ["", "?v=7", "#fragment", "?v=7#fragment"] {
                precondition(matches(origin.absoluteString + file + suffix))
            }
        }
        for url in ["https://other.example/login-ui.js", origin.absoluteString + "security-settings.js",
                    origin.absoluteString + "sub/login-ui.js", origin.absoluteString + "login-ui.js.backup"] {
            precondition(!matches(url), "Must not block unrelated script: \(url)")
        }
        compile(json, id: "native-startup-fixed", shouldSucceed: true)
        let old: [[String: Any]] = [["trigger": ["url-filter": "(login-ui|app-privacy)[.]js", "resource-type": ["script"]],
                                     "action": ["type": "block"]]]
        compile(String(decoding: try JSONSerialization.data(withJSONObject: old), as: UTF8.self),
                id: "native-startup-regression", shouldSucceed: false)
        print("PASS startup rules compile, old alternation reproduces rejection, and URL scope is correct")
    }
}
