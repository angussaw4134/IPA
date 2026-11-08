import Foundation

enum NativeContentRules {
    static func json(for origin: URL) throws -> String {
        let prefix = NSRegularExpression.escapedPattern(for: origin.absoluteString)
        // WebKit content rules do not support regex alternation (a|b). Each
        // replacement script therefore gets its own independently compiled rule.
        let rules: [[String: Any]] = ["login-ui.js", "app-privacy.js"].map { script in
            let file = NSRegularExpression.escapedPattern(for: script)
            return ["trigger": ["url-filter": "^" + prefix + file + "([?#].*)?$",
                                "resource-type": ["script"]],
                    "action": ["type": "block"]]
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: rules), as: UTF8.self)
    }
}
