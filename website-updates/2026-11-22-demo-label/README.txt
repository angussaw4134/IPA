Christmas website demo-label update — 22 November 2026

This patch contains only the website label changes, not the website source,
customer data, keys, credentials or native app changes.

Changes:
- Yellow DEMO TESTING BUILD text remains centred over the app and dialogs.
- No background card behind the label.
- Hide the separate label flash only on the blank session-restoration page.
- Update the label stylesheet version and existing startup check.

Apply from the 3377christmas website source directory:
  git apply --check <path-to-demo-label.patch>
  git apply <path-to-demo-label.patch>
  node --test tests/startup-intro.test.mjs

The local 3377christmas directory already has these changes: do not apply twice.
This patch assumes the earlier removal of the Opening AccessHub loading message.
It does not remove the permanent in-app demo identification.

Uploading this patch does not deploy Cloudflare or rebuild an IPA. The native
wrapper opens the live website, so website changes require website deployment.
No 150-key batch or admin-panel removal is included in this update.
