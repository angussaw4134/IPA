import UIKit
import WebKit
import SwiftUI

@main
struct AccessHubTestApp: App {
    @StateObject private var session = BrowserSession()

    var body: some Scene {
        WindowGroup {
            BrowserScreen(controller: session.controller)
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
                .onOpenURL { session.controller.receiveStorefrontURL($0) }
                // UIKit notifications preserve the early privacy-cover timing, including
                // temporary inactive states such as the native Face ID prompt.
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    session.controller.setPrivacyVisible(true)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    session.controller.enteredBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    session.controller.becameActive()
                }
        }
    }
}

private final class BrowserSession: ObservableObject {
    let controller = BrowserViewController()
}

private struct BrowserScreen: UIViewControllerRepresentable {
    let controller: BrowserViewController
    func makeUIViewController(context: Context) -> BrowserViewController { controller }
    func updateUIViewController(_ controller: BrowserViewController, context: Context) {}
}

final class BrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private let startURL = URL(string: Bundle.main.object(forInfoDictionaryKey: "TestWebsiteURL") as! String)!
    private var webView: WKWebView!
    private let errorPanel = UIStackView()
    private let errorMessage = UILabel()
    private lazy var security = NativeSecurity(origin: startURL)
    private lazy var accessPolicy = NativeAccessPolicy(origin: startURL)
    private lazy var websiteState = WebsiteStateVault(origin: startURL)
    private let privacyCover = UIImageView(image: UIImage(named: "privacy-cover.png"))
    private let demoLabel = UILabel()
    private var nativeReady = false
    private var preparingNative = false
    private var motionReplies: [(WKPermissionDecision) -> Void] = []
    private var licenseVisible = false
    private var appInactive = false
    private var pendingStorefrontHome = false
    private var documentReady = false

    func receiveStorefrontURL(_ url: URL) {
        #if DEBUG
        NSLog("Storefront callback scheme=%@ host=%@", url.scheme ?? "", url.host ?? "")
        #endif
        guard StorefrontLink.accepts(url) else { return }
        pendingStorefrontHome = true
        #if DEBUG
        // Simulator smoke tests read this sandbox-only receipt. No customer data.
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: "storefrontLaunchCount") + 1
        defaults.set(count, forKey: "storefrontLaunchCount")
        let receipt: [String: Any] = ["count": count, "pid": ProcessInfo.processInfo.processIdentifier]
        demoLabel.accessibilityValue = "\(count):\(ProcessInfo.processInfo.processIdentifier)"
        if let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
           let data = try? JSONSerialization.data(withJSONObject: receipt) {
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: folder.appendingPathComponent("storefront-launch.json"), options: .atomic)
                NSLog("Storefront URL received: %d", count)
            } catch { NSLog("Storefront test receipt error: %@", error.localizedDescription) }
        }
        #endif
        deliverStorefrontHome()
    }

    private func deliverStorefrontHome() {
        guard pendingStorefrontHome, documentReady, let webView = webView,
              let url = webView.url, isWebsite(url),
              UIApplication.shared.applicationState == .active else { return }
        webView.evaluateJavaScript("window.StorefrontLaunch?.openHome() === true") { [weak self] value, error in
            if error == nil, value as? Bool == true { self?.pendingStorefrontHome = false }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.065, alpha: 1)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController.addScriptMessageHandler(security, contentWorld: .page, name: "nativeSecurity")
        configuration.userContentController.add(self, name: "openurl")
        configuration.userContentController.add(self, name: "privacyState")
        configuration.userContentController.add(self, name: "websiteState")
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = view.backgroundColor
        webView.scrollView.backgroundColor = view.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        if #available(iOS 16.4, *) { webView.isInspectable = false }
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            // The website already handles env(safe-area-inset-top). Do not add it twice.
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        errorPanel.axis = .vertical
        errorPanel.spacing = 16
        errorPanel.alignment = .center
        errorPanel.backgroundColor = UIColor(red: 0.06, green: 0.16, blue: 0.12, alpha: 1)
        errorPanel.layer.borderWidth = 1
        errorPanel.layer.borderColor = UIColor(red: 0.74, green: 0.64, blue: 0.39, alpha: 1).cgColor
        errorPanel.isLayoutMarginsRelativeArrangement = true
        errorPanel.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        errorPanel.layer.cornerRadius = 16
        errorPanel.translatesAutoresizingMaskIntoConstraints = false
        errorMessage.textAlignment = .center
        errorMessage.numberOfLines = 0
        errorMessage.font = .preferredFont(forTextStyle: .body)
        errorMessage.adjustsFontForContentSizeCategory = true
        errorPanel.addArrangedSubview(errorMessage)
        let retryButton = UIButton(type: .system)
        retryButton.setTitle("Try again", for: .normal)
        retryButton.tintColor = UIColor(red: 0.94, green: 0.83, blue: 0.58, alpha: 1)
        retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
        errorPanel.addArrangedSubview(retryButton)
        view.addSubview(errorPanel)
        NSLayoutConstraint.activate([
            errorPanel.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            errorPanel.centerYAnchor.constraint(equalTo: webView.centerYAnchor),
            errorPanel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.88)
        ])
        errorPanel.isHidden = true

        privacyCover.backgroundColor = UIColor(white: 0.07, alpha: 1)
        privacyCover.contentMode = .scaleAspectFit
        privacyCover.isUserInteractionEnabled = true
        privacyCover.accessibilityLabel = "App content hidden"
        privacyCover.isAccessibilityElement = true
        privacyCover.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(privacyCover)
        NSLayoutConstraint.activate([
            privacyCover.topAnchor.constraint(equalTo: view.topAnchor),
            privacyCover.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            privacyCover.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            privacyCover.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        privacyCover.isHidden = true

        // A native label stays visible on every page, without covering touch targets.
        let demo = demoLabel
        #if DEBUG
        demo.accessibilityIdentifier = "storefront-launch-receipt"
        #endif
        demo.text = "Testing Phase Demo build"
        demo.textColor = .white
        demo.font = .systemFont(ofSize: 30, weight: .heavy)
        demo.textAlignment = .center
        demo.adjustsFontSizeToFitWidth = true
        demo.minimumScaleFactor = 0.6
        demo.layer.shadowColor = UIColor.black.cgColor
        demo.layer.shadowOpacity = 0.8
        demo.layer.shadowRadius = 2
        demo.layer.shadowOffset = CGSize(width: 0, height: 1)
        demo.isUserInteractionEnabled = false
        demo.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(demo)
        NSLayoutConstraint.activate([
            demo.centerYAnchor.constraint(equalTo: webView.centerYAnchor),
            demo.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            demo.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        // Decorative only: keep the permanent demo label and all touch targets intact.
        let season = UILabel()
        season.text = "✦  CHRISTMAS EDITION  ✦"
        season.textColor = UIColor(red: 0.94, green: 0.83, blue: 0.58, alpha: 1)
        season.font = .systemFont(ofSize: 12, weight: .semibold)
        season.textAlignment = .center
        season.adjustsFontSizeToFitWidth = true
        season.minimumScaleFactor = 0.75
        season.layer.shadowColor = UIColor.black.cgColor
        season.layer.shadowOpacity = 1
        season.layer.shadowRadius = 3
        season.layer.shadowOffset = .zero
        season.isUserInteractionEnabled = false
        season.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(season)
        NSLayoutConstraint.activate([
            season.topAnchor.constraint(equalTo: demo.bottomAnchor, constant: 8),
            season.leadingAnchor.constraint(equalTo: demo.leadingAnchor),
            season.trailingAnchor.constraint(equalTo: demo.trailingAnchor)
        ])
        goHome()
    }

    @objc private func goHome() {
        guard nativeReady else { prepareNativeLogin(); return }
        webView.load(URLRequest(url: startURL))
    }
    private func prepareNativeLogin() {
        guard !preparingNative else { return }
        preparingNative = true
        // The wrapper owns biometric login and lifecycle privacy. Avoid two controllers
        // reacting to the same buttons or treating the Face ID sheet as app backgrounding.
        guard Bundle.main.url(forResource: "NativeLogin", withExtension: "js") != nil,
              let json = try? NativeContentRules.json(for: startURL) else {
            preparingNative = false
            errorMessage.text = "This build is missing its login files. Reinstall the latest test build."
            errorPanel.isHidden = false
            return
        }
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "native-test-login",
            encodedContentRuleList: json) { [weak self] list, error in
                guard let self = self else { return }
                self.preparingNative = false
                guard let list = list, error == nil else {
                    let detail = error as NSError?
                    NSLog("Native startup rule error: %@", detail?.description ?? "No compiled rule list returned")
                    self.errorMessage.text = "Could not prepare the test app (\(detail?.code ?? -1)). Tap Try again."
                    self.errorPanel.isHidden = false
                    return
                }
                self.webView.configuration.userContentController.add(list)
                self.nativeReady = true
                self.goHome()
            }
    }
    @objc private func retry() {
        errorPanel.isHidden = true
        if webView.url != nil { webView.reload() } else { goHome() }
    }

    private func isWebsite(_ url: URL) -> Bool {
        accessPolicy.isWebsite(url)
    }

    private func installWebsiteScripts() {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        for name in ["WebsiteState", "MainPagePreload", "NativeLogin", "StorefrontLaunch"] {
            guard let path = Bundle.main.url(forResource: name, withExtension: "js"),
                  let template = try? String(contentsOf: path, encoding: .utf8),
                  let script = name == "WebsiteState" ? websiteState.script(template: template) : template else { continue }
            controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
    }

    func setPrivacyVisible(_ inactive: Bool) {
        guard isViewLoaded else { return }
        appInactive = inactive
        let visible = inactive && licenseVisible
        privacyCover.isHidden = !visible
        webView.accessibilityElementsHidden = visible
        view.layoutIfNeeded()
    }
    func enteredBackground() {
        setPrivacyVisible(true)
        websiteState.flush()
        security.cancel()
        webView?.evaluateJavaScript("window.dispatchEvent(new Event('accesshub-native-background'))", completionHandler: nil)
    }
    func becameActive() {
        setPrivacyVisible(false)
        security.becameActive()
        webView?.evaluateJavaScript("window.dispatchEvent(new Event('accesshub-native-foreground'))", completionHandler: nil)
        deliverStorefrontHome()
    }

    private func openExternal(_ url: URL) {
        guard accessPolicy.permitsExternal(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard security.trusts(message.frameInfo) else { return }
        if message.name == "websiteState" {
            websiteState.accept(message.body)
            return
        }
        if message.name == "privacyState", let visible = message.body as? Bool {
            licenseVisible = visible
            setPrivacyVisible(appInactive)
            return
        }
        guard message.name == "openurl", security.trusts(message.frameInfo),
              let value = message.body as? String, value.utf8.count <= 4096,
              let url = URL(string: value, relativeTo: startURL)?.absoluteURL else { return }
        if isWebsite(url) { webView.load(URLRequest(url: url)) }
        else { openExternal(url) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.targetFrame?.isMainFrame == false {
            let blank = ["about:blank", "about:srcdoc"].contains(url.absoluteString)
                && security.trustsOrigin(navigationAction.sourceFrame.securityOrigin)
            decisionHandler(isWebsite(url) || blank ? .allow : .cancel)
            return
        }
        if isWebsite(url) {
            if navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
                webView.load(navigationAction.request)
            } else {
                // Each full navigation uses the latest copy, never an old launch snapshot.
                installWebsiteScripts()
                decisionHandler(.allow)
            }
            return
        }
        decisionHandler(.cancel)
        if security.trusts(navigationAction.sourceFrame),
           navigationAction.navigationType == .linkActivated || navigationAction.targetFrame == nil {
            openExternal(url)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil, security.trusts(navigationAction.sourceFrame),
              let url = navigationAction.request.url else { return nil }
        if isWebsite(url) { webView.load(navigationAction.request) }
        else { openExternal(url) }
        return nil
    }

    func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        guard origin.protocol == "https", origin.host == startURL.host, [0, 443].contains(origin.port),
              security.trusts(frame) else { decisionHandler(.deny); return }
        let key = "motion-permission:" + startURL.absoluteString
        if let allowed = UserDefaults.standard.object(forKey: key) as? Bool {
            decisionHandler(allowed ? .grant : .deny); return
        }
        if !motionReplies.isEmpty { motionReplies.append(decisionHandler); return }
        guard presentedViewController == nil, UIApplication.shared.applicationState == .active else {
            decisionHandler(.deny); return
        }
        motionReplies.append(decisionHandler)
        let alert = UIAlertController(title: "Allow motion effects?",
            message: "Let this test website use device motion and orientation for tilt effects. Your choice is remembered on this device.", preferredStyle: .alert)
        func choose(_ allowed: Bool) {
            UserDefaults.standard.set(allowed, forKey: key)
            let replies = self.motionReplies
            self.motionReplies.removeAll()
            replies.forEach { $0(allowed ? .grant : .deny) }
        }
        alert.addAction(UIAlertAction(title: "Don’t Allow", style: .cancel) { _ in choose(false) })
        alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in choose(true) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        documentReady = false
        errorPanel.isHidden = true
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        documentReady = true
        deliverStorefrontHome()
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        licenseVisible = false
        setPrivacyVisible(appInactive)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showFailure(error)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { showFailure(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        errorMessage.text = "The website stopped responding. Tap Try again to reload it."
        errorPanel.isHidden = false
    }
    private func showFailure(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        errorMessage.text = "Could not load the website. Check your connection and try again."
        errorPanel.isHidden = false
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard security.trusts(frame), presentedViewController == nil else { completionHandler(); return }
        let alert = UIAlertController(title: "Website message", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard security.trusts(frame), presentedViewController == nil else { completionHandler(false); return }
        let alert = UIAlertController(title: "Website confirmation", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard security.trusts(frame), presentedViewController == nil else { completionHandler(nil); return }
        let alert = UIAlertController(title: "Website input", message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(alert.textFields?.first?.text) })
        present(alert, animated: true)
    }
}
