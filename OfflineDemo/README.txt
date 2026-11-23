3377 CHRISTMAS DEMO — offline iPhone app

The app is a fictional, native demo with a yellow DEMO TEST / NOT REAL ID
label. Home, Explore, Wallet, guides, settings and activation run entirely on
the phone. The app needs no Cloudflare Worker, website, API or remote assets.

Bundle ID: dev.accesshub.winterstudio.offline
Minimum iOS: 16.0
Optional deep link: winterstudiodemo://home (requires activation first)

INSTALL AND ACTIVATE

1. Sign and install WinterStudioDemo.ipa with your iPhone sideloading tool.
2. Open the app, tap Copy device code and send that code to the owner.
3. Paste the WA- activation code the owner sends back and tap Open demo.
4. Once activated, the app can open and operate in Airplane Mode. Save your
   activation code if you ever need to re-enter it on the same device.

FOR THE OWNER

The separately delivered private Owner folder holds 200-claim-keys.csv,
Issue-Activation.cmd, offline-issuer.mjs and activation-ledger.sqlite.
Run Issue-Activation.cmd on Windows with Node.js 24 installed. Paste one
unused key from the CSV and the customer's WD- device code. Copy the resulting
WA- code to the customer. Keep the Owner folder private and distribute only
the IPA, these installation instructions and each customer's WA- code.

Each claim in the one local ledger can be assigned to one device. Repeating
the same pairing returns the same activation. A different claim for an
already activated device uses no extra slot. The app rejects slots above 200,
modified codes, and codes issued to a different device. Keep using the same
ledger. Older backup copies may lack recent assignments and would permit
issuing an already spent slot. Only the public verification key is in the IPA.

The cap is on issued device activations using this ledger. The app cannot
count distinct people or revoke access remotely. Re-signing under a different
Apple team, switching phones, or resetting the Keychain may require a new
activation. Old reusable demo codes no longer unlock this build. In-place
updates retain the existing nickname and favourites under the same bundle ID
and signing account. Apple signing and refresh still apply to an offline app.

BUILD

Open Build Offline Winter Studio IPA on the offline-demo GitHub branch.
Download WinterStudioDemo-unsigned from a completed build and extract the IPA.
On macOS, run bash scripts/build-ipa.sh from OfflineDemo to build locally.
CI checks issuer limits, Swift signature verification, arm64 packaging and
the simulator journey. Test signing, first activation and Airplane Mode on a
physical iPhone before sharing broadly.
