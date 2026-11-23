3377 CHRISTMAS DEMO — fully offline iPhone app

This is a separate fictional demo, not a packaged government-licence replica.
Home, Explore, Wallet, guides, settings, sample graphics and code validation are
all compiled/bundled inside the app. No Cloudflare, website, API, admin panel,
remote fonts/images, tracking, camera scanner or identity verification is used.
The yellow DEMO TEST / NOT REAL ID label remains centred, including on sheets.

Bundle ID: dev.accesshub.winterstudio.offline
Display name: 3377 Christmas Demo
Minimum iOS: 16.0
Optional deep link: winterstudiodemo://home (does not bypass demo activation)
This app does not claim the old storefrontdemo URL scheme.

INSTALL
1. In GitHub Actions, open Build Offline Winter Studio IPA on offline-demo.
2. Open a successful run and download WinterStudioDemo-unsigned.
3. Extract the ZIP and sign/install WinterStudioDemo.ipa with your sideload tool.
4. Enter one of the separately delivered 150 demo codes.
5. Turn on Airplane Mode and browse Home, Explore and Wallet.

The repository contains SHA-256 hashes, not the original code list. Codes are
checked only on the device. There is no global usage counter, single-device
binding, revocation or real security guarantee against modifying the app.
Codes are reusable and are only a demonstration access gate.

Data stays in local app preferences. In-place updates with the same bundle ID
and signing account normally preserve it; deleting the app may remove it.
Apple signing expiry still applies. Offline operation does not bypass signing.
New content requires another IPA build; there are no live website updates.

BUILD ON MAC
  bash scripts/build-ipa.sh
  python3 scripts/test-simulator.py

CI checks the arm64 executable, bundle identity, 150 code hashes, label, absence
of a website URL/dependency, plus login/navigation/save/relaunch simulator tests.
An isolated debug-only test code works only with the --ui-testing launch flag.
It is not accepted in a release IPA.

REAL IPHONE CHECKS
- Sign/install with your tool, enter one supplied code and enable Airplane Mode.
- Verify all three tabs, saved favourites and nickname after closing/reopening.
- Confirm the centred yellow label on main screens and sample/settings sheets.
- Check large text, small screen scrolling and VoiceOver on your device.
- Check Wallet privacy cover in app switcher, and other tabs remain visible.
- Install a later build over the same app and check data remains.
- Confirm winterstudiodemo://home opens Home, with activation still enforced.

No original customer data, images, keys, credentials or licence fields are included.
