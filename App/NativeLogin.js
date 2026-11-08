(() => {
  'use strict';
  if (!window.webkit?.messageHandlers?.nativeSecurity) return;
  const listeners = new Set();
  let implementation;
  const emptyState = () => ({supported: false, enabled: false, busy: false, message: ''});
  const api = window.DemoLogin = {
    ready: () => implementation?.ready(),
    afterPin: () => implementation?.afterPin(),
    cancel: () => implementation?.cancel(),
    toggle: () => implementation?.toggle(),
    lock: () => implementation?.lock(),
    state: () => implementation?.state() || emptyState(),
    subscribe(listener) { listeners.add(listener); listener(api.state()); return () => listeners.delete(listener); }
  };
  async function native(action, token) {
    try { return await window.webkit.messageHandlers.nativeSecurity.postMessage({action, token}); }
    catch (error) { throw error instanceof Error ? error : new Error(String(error)); }
  }
  function initialize() {
    const $ = id => document.getElementById(id);
    if (!$('passkey-login') || typeof demoActivated === 'undefined') return;
    const button = $('passkey-login'), setup = $('passkey-setup'), remove = $('passkey-remove');
    const message = $('passkey-message'), settingsMessage = $('passkey-settings-message');
    const heading = $('pin-heading'), progress = $('login-progress');
    const token = () => localStorage.getItem('demoActivationToken');
    const reduced = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    let supported = false, enabled = false, busy = false, enrollAfterPin = false, transitioning = false;
    let epoch = 0, refreshedToken = '', automaticAttempt = false, animations = [];
    const state = () => ({supported, enabled, busy, message: settingsMessage.textContent || ''});

    function paint() {
      button.hidden = !supported || !demoActivated;
      $('passkey-login-label').textContent = enabled ? 'Use Face ID' : 'Set up Face ID';
      $('passkey-login-label').hidden = enabled;
      button.setAttribute('aria-label', enabled ? 'Use Face ID' : 'Set up Face ID');
      button.disabled = busy;
      // A native device has one biometric enrollment for this activation.
      setup.hidden = true;
      remove.hidden = false; remove.disabled = busy || (!supported && !enabled);
      remove.textContent = enabled ? 'Face ID: On' : 'Face ID: Off';
      remove.setAttribute('aria-checked', String(enabled));
      listeners.forEach(listener => listener(state()));
    }
    function checking(on) {
      pinScreen.classList.toggle('login-checking', on);
      progress.hidden = !on;
      heading.textContent = on ? 'Logging in' : 'Log in with PIN';
      pinEntry.inert = on; $('pin-keypad').inert = on;
      pinScreen.setAttribute('aria-busy', String(on));
    }
    function finish() {
      if (!demoActivated || document.hidden) { pinBusy = false; checking(false); return; }
      transitioning = true; pinBusy = true; checking(true);
      const run = epoch, savedToken = token();
      clearTimeout(pinSubmitTimer);
      pinSubmitTimer = setTimeout(() => {
        if (run !== epoch || savedToken !== token() || !demoActivated || document.hidden) {
          transitioning = false; pinBusy = false; checking(false); return;
        }
        demoLoggedIn = true; pinInput.value = ''; updatePinDots(); show('home');
        const home = $('screen-home');
        if (!reduced() && typeof pinScreen.animate === 'function') {
          pinScreen.classList.add('login-exit-layer');
          const exit = pinScreen.animate([{opacity:1,transform:'translateY(0)'},{opacity:0,transform:'translateY(-8px)'}],{duration:280,easing:'cubic-bezier(.22,1,.36,1)'});
          const enter = home.animate([{opacity:.4,transform:'translateY(8px)'},{opacity:1,transform:'none'}],{duration:360,easing:'cubic-bezier(.22,1,.36,1)'});
          animations = [exit,enter];
          exit.onfinish = () => { pinScreen.classList.remove('login-exit-layer'); checking(false); exit.cancel(); };
          enter.onfinish = () => { enter.cancel(); animations = []; };
        } else checking(false);
        transitioning = false; pinBusy = false;
      }, 0);
    }
    async function ceremony(registering) {
      if (busy || !supported || !demoActivated || (registering && !demoLoggedIn && !pinBusy)) return false;
      busy = true; pinBusy = true; paint();
      const run = epoch, savedToken = token();
      const current = () => run === epoch && savedToken === token() && demoActivated;
      const output = registering && demoLoggedIn ? settingsMessage : message;
      output.textContent = '';
      try {
        const result = await native(registering ? 'enroll' : 'authenticate', savedToken);
        if (!current() || result?.verified !== true) return false;
        // Retain the website's session check too; native success never creates access.
        const session = await demoRequest('/api/session', {token: savedToken});
        if (session?.active !== true) throw new Error('Your key is no longer active. Sign in with a valid key.');
        if (!current()) return false;
        enabled = true; output.textContent = ''; message.textContent = '';
        if (!registering) finish();
        return true;
      } catch (error) {
        if (current()) {
          output.textContent = error.message || 'Face ID was not completed. Use your PIN or try again.';
          if (error.status === 401 || error.status === 403) await checkBrowserAccess();
        }
        return false;
      } finally {
        if (run === epoch) { busy = false; pinBusy = transitioning; paint(); }
      }
    }
    async function ready() {
      if (!demoActivated || refreshedToken === token()) return;
      const run = epoch, savedToken = token(); refreshedToken = savedToken;
      try {
        const result = await native('status', savedToken);
        if (run !== epoch || savedToken !== token()) return;
        supported = result.supported === true; enabled = result.enabled === true;
        settingsMessage.textContent = supported ? '' : 'Face ID or Touch ID is unavailable. Use your PIN or check this app’s permission in Settings.';
        paint();
        if ((window.SecuritySettings?.automaticFaceId() ?? true) && supported && enabled && !automaticAttempt
            && !demoLoggedIn && pinScreen.classList.contains('active') && !document.hidden && !pinInput.value && !pinBusy) {
          automaticAttempt = true; ceremony(false);
        }
      } catch {
        if (run === epoch) { refreshedToken = ''; settingsMessage.textContent = 'Could not check Face ID. PIN login is still available.'; paint(); }
      }
    }
    async function afterPin() {
      const run = epoch, savedToken = token();
      if (enrollAfterPin) { enrollAfterPin = false; await ceremony(true); }
      if (run === epoch && savedToken === token()) finish();
    }
    function cancel() {
      epoch++; native('cancel', token()).catch(() => {});
      busy = false; pinBusy = false; transitioning = false; enrollAfterPin = false; refreshedToken = ''; enabled = false;
      clearTimeout(pinSubmitTimer); animations.forEach(a => a.cancel()); animations = [];
      pinScreen.classList.remove('login-exit-layer'); checking(false); message.textContent = ''; paint();
    }
    async function toggle() {
      if (!demoLoggedIn || busy) return;
      if (!enabled) { await ceremony(true); return; }
      busy = true; paint(); const run = epoch, savedToken = token();
      try {
        await native('remove', savedToken);
        if (run === epoch && savedToken === token()) {
          enabled = false; enrollAfterPin = false; message.textContent = '';
          settingsMessage.textContent = 'Face ID is off. Use your PIN to log in.';
        }
      } catch (error) { if (run === epoch) settingsMessage.textContent = error.message; }
      finally { if (run === epoch) { busy = false; paint(); } }
    }
    button.addEventListener('click', () => {
      if (busy || pinBusy) return;
      if (enabled) ceremony(false);
      else { enrollAfterPin = true; message.textContent = 'Enter your PIN first, then follow the Face ID prompt.'; pinInput.focus({preventScroll:true}); }
    });
    remove.addEventListener('click', toggle);
    implementation = {ready, afterPin, cancel, toggle, state, lock() { automaticAttempt = true; cancel(); }};
    window.addEventListener('accesshub-native-background', () => { if (busy || transitioning) cancel(); });
    paint(); ready();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize, {once: true});
  else initialize();
})();
