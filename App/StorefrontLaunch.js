/* A launch intent only: normal activation, PIN and biometric checks still own access. */
(() => {
  if (window.top !== window || window.StorefrontLaunch) return;
  window.StorefrontLaunch = Object.freeze({
    openHome() {
      // An access-entry document is not the app. Keep the native intent pending
      // across its redirect until the app's own router is ready.
      if (typeof demoActivated === 'undefined' || typeof demoLoggedIn === 'undefined'
          || typeof show !== 'function') return false;
      if (demoActivated && demoLoggedIn) {
        show('home');
        window.MainPagePreload?.warm();
      }
      // When locked, the existing successful login flow already opens Home.
      // Never set authentication flags or dismiss the login from a URL.
      return true;
    }
  });
})();
