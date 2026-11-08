import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = BrowserViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class BrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let startURL = URL(string: Bundle.main.object(forInfoDictionaryKey: "TestWebsiteURL") as! String)!
    private var webView: WKWebView!
    private let errorPanel = UIStackView()
    private let errorMessage = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.065, alpha: 1)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        // No access tokens, admin PINs, or native authentication bypasses are bundled.
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = view.backgroundColor
        webView.scrollView.backgroundColor = view.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        let toolbar = UIStackView()
        toolbar.axis = .horizontal
        toolbar.spacing = 14
        toolbar.alignment = .center
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.text = "AccessHub Test"
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .secondaryLabel
        let home = UIButton(type: .system)
        home.setImage(UIImage(systemName: "house"), for: .normal)
        home.accessibilityLabel = "Open website home"
        home.addTarget(self, action: #selector(goHome), for: .touchUpInside)
        let reload = UIButton(type: .system)
        reload.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        reload.accessibilityLabel = "Reload website"
        reload.addTarget(self, action: #selector(retry), for: .touchUpInside)
        [title, spinner, home, reload].forEach { toolbar.addArrangedSubview($0) }
        home.widthAnchor.constraint(equalToConstant: 44).isActive = true
        reload.widthAnchor.constraint(equalToConstant: 44).isActive = true
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            webView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        errorPanel.axis = .vertical
        errorPanel.spacing = 16
        errorPanel.alignment = .center
        errorPanel.backgroundColor = UIColor(white: 0.08, alpha: 1)
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
        retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
        errorPanel.addArrangedSubview(retryButton)
        view.addSubview(errorPanel)
        NSLayoutConstraint.activate([
            errorPanel.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            errorPanel.centerYAnchor.constraint(equalTo: webView.centerYAnchor),
            errorPanel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.88)
        ])
        errorPanel.isHidden = true

        // A native label stays visible on every page, without covering touch targets.
        let demo = UILabel()
        demo.text = "TEST DEMO BUILD"
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
        goHome()
    }

    @objc private func goHome() { webView.load(URLRequest(url: startURL)) }
    @objc private func retry() {
        errorPanel.isHidden = true
        if webView.url != nil { webView.reload() } else { goHome() }
    }

    private func isWebsite(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == startURL.host && url.port == startURL.port
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
            return
        }
        if isWebsite(url) {
            if navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
                webView.load(navigationAction.request)
            } else { decisionHandler(.allow) }
            return
        }
        decisionHandler(.cancel)
        // Only user-selected, standard external links may leave the app.
        if navigationAction.navigationType == .linkActivated,
           ["https", "mailto", "tel"].contains(url.scheme ?? "") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorPanel.isHidden = true
        spinner.startAnimating()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { spinner.stopAnimating() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showFailure(error)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { showFailure(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        spinner.stopAnimating()
        errorMessage.text = "The website stopped responding. Tap Try again to reload it."
        errorPanel.isHidden = false
    }
    private func showFailure(_ error: Error) {
        spinner.stopAnimating()
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        errorMessage.text = "Could not load the website. Check your connection and try again."
        errorPanel.isHidden = false
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard presentedViewController == nil else { completionHandler(); return }
        let alert = UIAlertController(title: "Website message", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard presentedViewController == nil else { completionHandler(false); return }
        let alert = UIAlertController(title: "Website confirmation", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard presentedViewController == nil else { completionHandler(nil); return }
        let alert = UIAlertController(title: "Website input", message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(alert.textFields?.first?.text) })
        present(alert, animated: true)
    }
}
