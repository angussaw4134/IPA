import Foundation

enum StorefrontLink {
    static func accepts(_ url: URL) -> Bool {
        // This route is a navigation intent, never a source of keys, tokens or redirects.
        url.scheme?.lowercased() == "storefrontdemo"
            && url.host?.lowercased() == "open"
            && url.user == nil && url.password == nil && url.port == nil
            && (url.path.isEmpty || url.path == "/")
            && url.query == nil && url.fragment == nil
    }
}
