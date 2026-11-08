# AccessHub Test — SideStore

An iPhone test wrapper for https://3377test.erg3be.workers.dev/. It displays a permanent white **Testing Phase Demo build** label with no background. This is an independent demonstration, not an official government application or valid identification.

## Get the IPA

1. Open this repository's **Actions** tab.
2. Open **Build SideStore IPA**. A push to `main` starts a build automatically. To rebuild or change the website, select **Run workflow** and enter the HTTPS website address.
3. Wait for a green build, open that run, and download **AccessHubTest-SideStore** under Artifacts.
4. Extract the downloaded ZIP. The app file is **AccessHubTest.ipa**.
5. Transfer the IPA to Files on your iPhone. In SideStore's My Apps screen, use **+** to select it. SideStore signs the app with your own Apple account.

No Apple password, signing certificate, website admin PIN or Cloudflare credentials are required by this repository or its GitHub workflow. SideStore itself handles signing. Follow its current [installation instructions](https://docs.sidestore.io/docs/installation/install) and keep its required VPN enabled when installing or refreshing. Free-account apps normally need refreshing within seven days.

## What to test

- Open **AccessHub Test**, enter a valid unused key and complete the usual website login.
- Close and reopen: website cookies and local storage should remain. Safari's existing login is separate and will not be copied. A fresh activation is subject to the server's user cap and key rules.
- Choose an iPhone photo and save it through the website's normal upload flow.
- Check scrolling, the safe area, keyboard, refresh and the existing server-full / revoked-key behavior.
- Turn off networking and reload: a retry message should appear. Reconnect and select Try again.

This build requires iOS 16 or newer. The website still needs a working internet connection. There is no native toolbar: the website starts directly below the iPhone status area. External user-selected HTTPS links open outside the app. Server authentication, keys, user caps, billing and admin features remain on the existing server.

**Face ID/passkeys:** this build does not add native Face ID or associated-domain entitlements. Use the website's key/PIN login for initial testing. Existing Safari passkeys are not guaranteed to work inside this wrapper; that requires a separate associated-domain and signing configuration. Photo selection uses WKWebView's system picker; there is no custom upload bridge or bypass.

## Build locally on a Mac

Install Xcode and its iOS SDK, then run:

```sh
bash scripts/build-ipa.sh
```

Output: `dist/AccessHubTest.ipa`. It is an unsigned device package for SideStore to re-sign, not an App Store release. The build checks the executable's arm64 architecture and IPA structure before publishing its artifact. Only a real device can confirm SideStore installation and all website behavior.

The website can be changed with `WEBSITE_URL=https://your-worker.example/ bash scripts/build-ipa.sh` or the Actions workflow input. Keep the bundle ID and signing Apple account consistent across updates to preserve the app's local data. Changing domains does not automatically move website cookies or profiles.

GitHub-hosted macOS builds may use your account's Actions allowance for private repositories. Production Worker files and data are not uploaded here or changed by this build.
