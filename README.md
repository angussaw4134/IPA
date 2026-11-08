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

- Open the app with 3377test's existing home-screen name and icon, enter a valid unused key and complete the usual website login.
- Close and reopen: website cookies and local storage should remain. Safari's existing login is separate and will not be copied. A fresh activation is subject to the server's user cap and key rules.
- Choose an iPhone photo and save it through the website's normal upload flow.
- Check scrolling, the safe area, keyboard, refresh and the existing server-full / revoked-key behavior.
- Turn off networking and reload: a retry message should appear. Reconnect and select Try again.

This build requires iOS 16 or newer. The website still needs a working internet connection. There is no native toolbar or extra top inset: the website handles the iPhone safe area itself. External links, including the website's JavaScript link buttons, open outside the app. Server authentication, keys, user caps, billing and admin features remain on the existing server.

**Face ID:** enter a valid key, tap Set up Face ID, then enter the website PIN. Apple handles the biometric prompt. Enrollment is stored in this installation's Keychain, tied to the key, website and current biometric enrollment. Returning users can unlock with Face ID (or Touch ID on supported devices); the server is checked before and after authentication, so a deleted, banned or expired key does not regain access. PIN remains the fallback. Use the existing signature settings toggle to disable Face ID. Safari passkeys are separate and are not imported or simulated.

**Motion:** the first motion request offers Allow / Don't Allow. The wrapper remembers either choice for that website on this installation. Changing websites or reinstalling can require a new choice.

**Privacy:** a local opaque cover is shown when iOS reports the app becoming inactive, and remains through backgrounding. It is removed on return to the foreground. Actual backgrounding cancels pending login, while the Face ID system prompt does not cancel itself. Test app-switcher snapshots on a real iPhone; the cover cannot prevent screenshots taken while the app is active or replace iOS lifecycle timing. The permanent demo label stays visible over the cover.

Photo selection uses WKWebView's system picker; there is no custom upload bridge or bypass. After installing an update, test Face ID cancellation, key revocation, returning from the app switcher, motion on repeated visits, and both regular links and buttons that open a new window.

## Build locally on a Mac

Install Xcode and its iOS SDK, then run:

```sh
bash scripts/build-ipa.sh
```

Output: `dist/AccessHubTest.ipa`. It is an unsigned device package for SideStore to re-sign, not an App Store release. The build checks the executable's arm64 architecture and IPA structure before publishing its artifact. Only a real device can confirm SideStore installation and all website behavior.

The website can be changed with `WEBSITE_URL=https://your-worker.example/ bash scripts/build-ipa.sh` or the Actions workflow input. Keep the bundle ID and signing Apple account consistent across updates to preserve the app's local data. Changing domains does not automatically move website cookies or profiles.

GitHub-hosted macOS builds may use your account's Actions allowance for private repositories. Production Worker files and data are not uploaded here or changed by this build.
