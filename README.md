# AccessHub Test — SideStore

An iPhone test wrapper for https://3377speedincreese.fejiofasj.workers.dev/. It displays a permanent white **Testing Phase Demo build** label with no background. This is an independent demonstration, not an official government application or valid identification.

## Get the IPA

1. Open this repository's **Actions** tab.
2. Open **Build SideStore IPA**. A push to `main` starts a build automatically. To rebuild or change the website, select **Run workflow** and enter the HTTPS website address.
3. Wait for a green build, open that run, and download **AccessHubTest-SideStore** under Artifacts.
4. Extract the downloaded ZIP. The app file is **AccessHubTest.ipa**.
5. Transfer the IPA to Files on your iPhone. In SideStore's My Apps screen, use **+** to select it. SideStore signs the app with your own Apple account.

No Apple password, signing certificate, website admin PIN or Cloudflare credentials are required by this repository or its GitHub workflow. SideStore itself handles signing. Follow its current [installation instructions](https://docs.sidestore.io/docs/installation/install) and keep its required VPN enabled when installing or refreshing. Free-account apps normally need refreshing within seven days.

## What to test

### Open from the separate storefront

The receiving app registers **`storefrontdemo://open`**. The storefront link stays unchanged. SwiftUI's `.onOpenURL` validates the scheme and `open` host and sends a Home navigation intent to the existing browser screen. Cold launches queue that intent until the website is ready; running and backgrounded launches reuse the existing browser. If locked or unactivated, normal key/PIN/Face ID login is still required, then the existing login flow opens Home. URLs cannot supply credentials, arbitrary destinations or bypass authentication.

**Uninstall “Launcher Demo” before installing this app** because it registers the same scheme. iOS does not guarantee which app receives a URL when multiple installed apps claim it. Keep the separate storefront installed. When updating this receiving app, install over its existing copy with the same signing account; do not delete it if you want to preserve settings. Its bundle ID remains `dev.accesshub.sidestoretest`, distinct from storefront `com.example.NativeStorefront`. Do not let the signing tool rename this app to the storefront bundle ID or remove its URL registration.

The macOS Actions workflow builds an unsigned arm64 **device** IPA, inspects its final Info.plist for `CFBundleURLTypes` → `CFBundleURLSchemes` → `storefrontdemo`, and runs a separate **simulator** build to exercise cold, already-running, background and terminated-process URL delivery. JavaScript tests separately check Home routing and that locked/revoked sessions cannot be unlocked by the URL. The simulator's diagnostic receipt exists only in Debug builds; the released IPA does not include it. No App Store publishing or Apple signing credentials are used.

After signing and installing on your iPhone:

1. Sign into the receiving app normally. Open a page other than Home.
2. Return to the storefront and use its existing Open button. The receiving app should appear on Home.
3. Force-close the receiving app, then use the same storefront button. Complete login if prompted; Home should open.
4. With the receiver already active, open `storefrontdemo://open` using an iOS Shortcuts **Open URLs** action; check Home opens without a new browser or extra toolbar.
5. Repeat while locked and with invalid/revoked access: normal authentication must still be enforced.
6. Recheck safe areas, Face ID, preserved settings, and licence-only app-switcher privacy on the physical device after the SwiftUI lifecycle change.

Simulator URL delivery is not a substitute for these real-iPhone checks or confirmation that your signing tool preserves Info.plist. The integration follows [Apple’s SwiftUI URL handling documentation](https://developer.apple.com/documentation/swiftui/view/onopenurl%28perform%3A%29).

- Open the app with 3377test's existing home-screen name and icon, enter a valid unused key and complete the usual website login.
- Close and reopen: website cookies and local storage should remain. Safari's existing login is separate and will not be copied. A fresh activation is subject to the server's user cap and key rules.
- Choose an iPhone photo and save it through the website's normal upload flow.
- Check scrolling, the safe area, keyboard, refresh and the existing server-full / revoked-key behavior.
- Turn off networking and reload: a retry message should appear. Reconnect and select Try again.

This build requires iOS 16 or newer. The website still needs a working internet connection. There is no native toolbar or extra top inset: the website handles the iPhone safe area itself. External links, including the website's JavaScript link buttons, open outside the app. Server authentication, keys, user caps, billing and admin features remain on the existing server.

**Face ID:** enter a valid key, tap Set up Face ID, then enter the website PIN. Apple handles the biometric prompt. Enrollment is stored in this installation's Keychain, tied to the key, website and current biometric enrollment. Returning users can unlock with Face ID (or Touch ID on supported devices); the server is checked before and after authentication, so a deleted, banned or expired key does not regain access. PIN remains the fallback. Use the existing signature settings toggle to disable Face ID. Safari passkeys are separate and are not imported or simulated.

**Motion:** the first motion request offers Allow / Don't Allow. The wrapper remembers either choice for that website on this installation. Changing websites or reinstalling can require a new choice.

**Privacy:** a local opaque cover is shown when iOS reports the app becoming inactive **only while the licence page is open**, and remains through backgrounding. Home, Services and Wallet keep their normal previews. The cover is removed on return to the foreground. Actual backgrounding cancels pending login, while the Face ID system prompt does not cancel itself. Test app-switcher snapshots on a real iPhone; the cover cannot prevent screenshots taken while the app is active or replace iOS lifecycle timing. The permanent demo label stays visible over the cover.

**Preloading:** after successful login, the main Home, Wallet and Services artwork and navigation images are loaded and decoded in the background, two queued images at a time. Login does not wait for them. Only same-origin static image URLs are warmed, without fetching APIs, videos or customer photo URLs. Queued work stops while hidden or logged out and can resume on return. A first visit still depends on network speed; iOS can discard decoded images under memory pressure.

**Reinstalling after signing expires:** install the IPA over the existing app, using the same signing Apple account, bundle ID and website. Do not delete the old app first. The wrapper keeps WebKit's persistent data store and also saves a device-bound, AES-GCM encrypted recovery copy of the activation token, licence details/photo, local PIN settings, security preferences, service order and saved demo email. The encryption key is in Keychain, available only when this device is unlocked. No admin login/session is copied. Before page scripts run, missing web storage can be restored from that copy; existing data for another activation is never overwritten. Restoring uses the original activation token and the website's regular server validation, never `/api/activate`, so it does not consume another key or user slot. Deleted, banned, paused and expired access remains denied. Explicitly removing the activation token or clearing storage forgets the recovery copy. Server-saved contact/signature/customer data remains attached to the same activation.

This is protection for an **in-place reinstall/update**, not an uninstall, device transfer or domain migration. Deleting the app removes its local files; changing the signing account can make its Keychain inaccessible. The recovery copy is excluded from iCloud backup because its encryption key is device-bound. Install this build and open it once before relying on its recovery copy. Automated tests exercise storage recovery, encryption, customer isolation and forgetting; final installation-over-expiry behavior still needs testing on a physical iPhone with your chosen PC installer.

**Security boundaries:** the app and its frames stay on the configured HTTPS origin; external links use a bounded scheme allowlist and open outside the app. Native bridges and website dialogs accept only the trusted main frame. Authentication POSTs are uncached and never follow redirects. Link previews and Safari inspection are disabled, but this does not make the server URL secret: it remains recoverable from an IPA or an inspected device. Server-side authorization is the protection. Native UserDefaults contains only motion-permission choices, not keys or PINs. The website's own storage and server security require separate review; a static IPA scanner is not a complete audit.

Photo selection uses WKWebView's system picker; there is no custom upload bridge or bypass. After installing an update, test Face ID cancellation, key revocation, returning from the app switcher, motion on repeated visits, and both regular links and buttons that open a new window.

## Build locally on a Mac

Install Xcode and its iOS SDK, then run:

```sh
bash scripts/build-ipa.sh
```

Output: `dist/AccessHubTest.ipa`. It is an unsigned device package for SideStore to re-sign, not an App Store release. The build checks the executable's arm64 architecture and IPA structure before publishing its artifact. Only a real device can confirm SideStore installation and all website behavior.

The website can be changed with `WEBSITE_URL=https://your-worker.example/ bash scripts/build-ipa.sh` or the Actions workflow input. Keep the bundle ID and signing Apple account consistent across updates to preserve the app's local data. Changing domains does not automatically move website cookies or profiles.

GitHub-hosted macOS builds may use your account's Actions allowance for private repositories. Production Worker files and data are not uploaded here or changed by this build.
