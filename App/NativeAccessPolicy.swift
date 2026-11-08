import Foundation

struct NativeAccessPolicy {
    let origin: URL
    func trusts(protocol scheme: String, host: String, port: Int) -> Bool {
        scheme.lowercased() == "https" && host.lowercased() == origin.host?.lowercased()
            && [0, 443].contains(port)
    }
    func isWebsite(_ url: URL) -> Bool {
        url.user == nil && url.password == nil
            && trusts(protocol: url.scheme ?? "", host: url.host ?? "", port: url.port ?? 443)
    }
    func permitsExternal(_ url: URL) -> Bool {
        guard url.absoluteString.utf8.count <= 4096, url.user == nil, url.password == nil else { return false }
        switch url.scheme?.lowercased() {
        case "https", "http": return !(url.host ?? "").isEmpty
        case "mailto", "tel":
            // Foundation leaves path empty for opaque URLs such as mailto: and tel:.
            let target = url.absoluteString.dropFirst((url.scheme?.count ?? 0) + 1)
                .prefix { $0 != "?" && $0 != "#" }
            return !target.isEmpty && !target.hasPrefix("//")
        default: return false
        }
    }
}

// Authentication POST bodies must never follow redirects to another endpoint.
final class NoAuthenticationRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
