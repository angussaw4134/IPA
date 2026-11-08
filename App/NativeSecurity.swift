import UIKit
import WebKit
import LocalAuthentication
import Security
import CryptoKit

// Device biometrics unlock this installation only. The server remains authoritative
// for key expiry, deletion, bans, migration and capacity; no WebAuthn is simulated.
final class NativeSecurity: NSObject, WKScriptMessageHandlerWithReply {
    private let origin: URL
    private let service = "dev.accesshub.sidestoretest.biometry"
    private var generation = 0
    private var context: LAContext?
    private var task: URLSessionDataTask?
    private var pendingReply: ((Any?, String?) -> Void)?
    private var deferredSuccess: (() -> Void)?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    init(origin: URL) { self.origin = origin }

    func trusts(_ frame: WKFrameInfo) -> Bool {
        let source = frame.securityOrigin
        return frame.isMainFrame && source.protocol == "https" && source.host == origin.host
            && [0, 443].contains(source.port)
    }

    private func account(_ token: String) -> String {
        SHA256.hash(data: Data((origin.absoluteString + "\n" + token).utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    private func enrolled(_ account: String) -> Bool {
        var request = query(account)
        request[kSecReturnAttributes as String] = true
        request[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        return SecItemCopyMatching(request as CFDictionary, nil) == errSecSuccess
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard trusts(message.frameInfo), let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            replyHandler(nil, "This request is not from the test website."); return
        }
        if action == "cancel" { cancel(); replyHandler(["cancelled": true], nil); return }
        guard let token = body["token"] as? String, !token.isEmpty, token.utf8.count <= 4096 else {
            replyHandler(nil, "Sign in with your access key first."); return
        }
        let key = account(token)
        if action == "status" {
            let probe = LAContext()
            let available = probe.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            replyHandler(["supported": available, "enabled": enrolled(key)], nil)
            return
        }
        guard UIApplication.shared.applicationState == .active else {
            replyHandler(nil, "Return to the app and try again."); return
        }
        guard pendingReply == nil else { replyHandler(nil, "An authentication request is already running."); return }
        guard ["enroll", "authenticate", "remove"].contains(action) else {
            replyHandler(nil, "Unknown authentication action."); return
        }
        generation += 1
        let run = generation
        pendingReply = replyHandler
        validateSession(token, run: run) { [weak self] in
            guard let self = self else { return }
            if action == "remove" {
                let result = SecItemDelete(self.query(key) as CFDictionary)
                if result == errSecSuccess || result == errSecItemNotFound {
                    self.complete(["enabled": false], run: run)
                } else { self.fail("Could not turn Face ID off. Try again.", run: run) }
                return
            }
            self.authenticate(action: action, token: token, account: key, run: run)
        }
    }

    private func validateSession(_ token: String, run: Int, success: @escaping () -> Void) {
        var request = URLRequest(url: origin.appendingPathComponent("api/session"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://" + (origin.host ?? ""), forHTTPHeaderField: "Origin")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token])
        task = session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self, run == self.generation, self.pendingReply != nil else { return }
                self.task = nil
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let result = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                guard error == nil, code == 200, result?["active"] as? Bool == true else {
                    if code == 401 || code == 403 {
                        SecItemDelete(self.query(self.account(token)) as CFDictionary)
                    }
                    self.fail(result?["error"] as? String ?? "Could not verify your key. Check your connection and try again.", run: run)
                    return
                }
                success()
            }
        }
        task?.resume()
    }

    private func authenticate(action: String, token: String, account: String, run: Int) {
        guard UIApplication.shared.applicationState == .active else {
            fail("Return to the app and try again.", run: run); return
        }
        let authentication = LAContext()
        authentication.localizedFallbackTitle = ""
        authentication.localizedCancelTitle = "Use PIN"
        var error: NSError?
        guard authentication.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            fail("Face ID or Touch ID is unavailable. Use your PIN, or check this app’s Face ID permission in Settings.", run: run)
            return
        }
        context = authentication
        authentication.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
            localizedReason: action == "enroll" ? "Enable biometric unlock for this test app." : "Unlock your test app.") { [weak self] authenticated, error in
            guard let self = self else { return }
            guard authenticated else {
                DispatchQueue.main.async { self.fail("Authentication was not completed. Use your PIN or try again.", run: run) }
                return
            }
            // Reuse the successful context for the protected Keychain operation.
            var request = self.query(account)
            var result: OSStatus
            if action == "enroll" {
                guard let access = SecAccessControlCreateWithFlags(nil,
                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .biometryCurrentSet, nil) else {
                    DispatchQueue.main.async { self.fail("Could not secure biometric unlock.", run: run) }; return
                }
                request[kSecAttrAccessControl as String] = access
                request[kSecValueData as String] = Data(token.utf8)
                request[kSecUseAuthenticationContext as String] = authentication
                // Save only after the request's generation is checked on the main queue.
                DispatchQueue.main.async {
                    guard run == self.generation, self.pendingReply != nil else { return }
                    SecItemDelete(self.query(account) as CFDictionary)
                    let saved = SecItemAdd(request as CFDictionary, nil)
                    if saved == errSecSuccess { self.complete(["verified": true, "enabled": true], run: run) }
                    else { self.fail("Could not save Face ID for this installation. Use your PIN.", run: run) }
                }
                return
            } else {
                request[kSecReturnData as String] = true
                request[kSecUseAuthenticationContext as String] = authentication
                request[kSecUseOperationPrompt as String] = "Unlock your test app."
                var stored: CFTypeRef?
                result = SecItemCopyMatching(request as CFDictionary, &stored)
                guard result == errSecSuccess, let value = stored as? Data, value == Data(token.utf8) else {
                    DispatchQueue.main.async {
                        if run == self.generation && result == errSecItemNotFound { SecItemDelete(self.query(account) as CFDictionary) }
                        self.fail("Face ID setup is unavailable or has changed. Use your PIN and set it up again.", run: run)
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                guard run == self.generation, self.pendingReply != nil else { return }
                // Recheck after the biometric prompt: the key may have been revoked meanwhile.
                self.validateSession(token, run: run) {
                    self.complete(["verified": true, "enabled": true], run: run)
                }
            }
        }
    }

    private func complete(_ result: [String: Any], run: Int) {
        guard run == generation, pendingReply != nil else { return }
        if UIApplication.shared.applicationState != .active {
            deferredSuccess = { [weak self] in self?.complete(result, run: run) }
            return
        }
        let reply = pendingReply
        pendingReply = nil
        deferredSuccess = nil
        context?.invalidate(); context = nil
        reply?(result, nil)
    }

    private func fail(_ message: String, run: Int) {
        guard run == generation else { return }
        let reply = pendingReply
        pendingReply = nil
        deferredSuccess = nil
        context?.invalidate(); context = nil
        reply?(nil, message)
    }

    func cancel() {
        generation += 1
        task?.cancel(); task = nil
        context?.invalidate(); context = nil
        deferredSuccess = nil
        let reply = pendingReply
        pendingReply = nil
        reply?(nil, "Authentication cancelled. Use your PIN or try again.")
    }

    func becameActive() {
        let completion = deferredSuccess
        deferredSuccess = nil
        completion?()
    }
}
