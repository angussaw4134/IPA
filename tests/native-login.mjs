import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {test} from 'node:test';

const code = await readFile(new URL('../App/NativeLogin.js', import.meta.url), 'utf8');
const flush = async () => { for (let i = 0; i < 8; i++) await new Promise(setImmediate); };
class Element {
  constructor() {
    this.attributes = {}; this.events = {}; this.textContent = ''; this.value = ''; this.classes = new Set();
    this.classList = {contains: x => this.classes.has(x), add: x => this.classes.add(x), remove: x => this.classes.delete(x), toggle: (x, on) => on ? this.classes.add(x) : this.classes.delete(x)};
  }
  addEventListener(type, fn) { this.events[type] = fn; }
  setAttribute(k, v) { this.attributes[k] = v; }
  focus() {}
  click() { if (!this.disabled) return this.events.click?.(); }
}
function setup({enabled = false, supported = true, automatic = false} = {}) {
  const nodes = new Map(); const $ = id => { if (!nodes.has(id)) nodes.set(id, new Element()); return nodes.get(id); };
  $('screen-splash').classes.add('active');
  let savedToken = 'activation', pending, authError, removeError, sessionError;
  let serverActive = true;
  const calls = [], shows = [], timers = new Map(), events = {}, documentEvents = {}; let timerID = 0;
  const context = vm.createContext({
    document: {getElementById: $, readyState: 'loading', hidden: false, addEventListener: (type, fn) => documentEvents[type] = fn},
    window: {
      matchMedia: () => ({matches: true}), addEventListener: (type, fn) => events[type] = fn,
      SecuritySettings: {automaticFaceId: () => automatic},
      webkit: {messageHandlers: {nativeSecurity: {postMessage: async ({action, token}) => {
        calls.push({action, token});
        if (action === 'status') return {supported, enabled};
        if (action === 'cancel') return {cancelled: true};
        if (action === 'remove') { if (removeError) throw removeError; enabled = false; return {enabled}; }
        if (pending) return pending;
        if (authError) throw authError;
        enabled = true; return {verified: true, enabled};
      }}}}
    },
    localStorage: {getItem: () => savedToken},
    demoActivated: true, demoLoggedIn: false, pinBusy: false, pinSubmitTimer: null,
    pinInput: $('login-pin'), pinEntry: $('pin-entry'), pinScreen: $('screen-splash'), updatePinDots() {},
    show: page => shows.push(page),
    demoRequest: async (path, body) => {
      calls.push({path, body}); if (sessionError) throw sessionError; return {active: serverActive};
    },
    checkBrowserAccess: async () => { context.demoActivated = false; context.window.DemoLogin.cancel(); },
    setTimeout: fn => { timers.set(++timerID, fn); return timerID; }, clearTimeout: id => timers.delete(id)
  });
  vm.runInContext(code, context);
  return {context, $, calls, shows, events, api: context.window.DemoLogin,
    initialize: () => documentEvents.DOMContentLoaded(),
    runTimers() { for (const [id, fn] of [...timers]) { timers.delete(id); fn(); } },
    setToken: value => savedToken = value, setPending: value => pending = value,
    setAuthError: value => authError = value, setRemoveError: value => removeError = value,
    setSessionError: value => sessionError = value, setServerActive: value => serverActive = value};
}
test('early settings subscription survives initialization; enrollment waits for PIN', async () => {
  const t = setup(); const states = []; t.api.subscribe(value => states.push(value));
  assert.equal(t.api.state().supported, false);
  t.initialize(); await flush();
  assert.equal(states.at(-1).supported, true);
  t.$('passkey-login').click(); await flush();
  assert.equal(t.calls.some(c => c.action === 'enroll'), false);
  t.context.pinBusy = true; await t.api.afterPin(); t.runTimers();
  assert.equal(t.calls.filter(c => c.action === 'enroll').length, 1);
  assert.deepEqual(t.shows, ['home']);
  assert.equal(t.$('passkey-login-label').hidden, true);
  assert.equal(t.$('passkey-remove').attributes['aria-checked'], 'true');
});
test('biometric success requires a live server session and cannot unlock a revoked key', async () => {
  const t = setup({enabled: true}); t.initialize(); await flush();
  t.setSessionError({message: 'Key revoked', status: 403});
  t.$('passkey-login').click(); await flush(); t.runTimers();
  assert.deepEqual(t.shows, []); assert.equal(t.context.demoActivated, false);
});
test('a non-active session response also refuses unlock', async () => {
  const t = setup({enabled: true}); t.initialize(); await flush(); t.setServerActive(false);
  t.$('passkey-login').click(); await flush(); t.runTimers(); assert.deepEqual(t.shows, []);
});
test('cancellation and backgrounding ignore stale biometric success', async () => {
  for (const interrupt of ['background', 'revoked', 'token']) {
    const t = setup({enabled: true}); t.initialize(); await flush();
    let resolve; t.setPending(new Promise(r => resolve = r));
    t.$('passkey-login').click(); await flush();
    if (interrupt === 'background') t.events['accesshub-native-background']();
    if (interrupt === 'revoked') { t.context.demoActivated = false; t.api.cancel(); }
    if (interrupt === 'token') t.setToken('other-key');
    resolve({verified: true}); await flush(); t.runTimers(); assert.deepEqual(t.shows, [], interrupt);
  }
});
test('system cancellation leaves PIN usable; an unverified reply cannot unlock', async () => {
  const t = setup({enabled: true}); t.initialize(); await flush();
  t.setAuthError('Cancelled'); t.$('passkey-login').click(); await flush(); t.runTimers();
  assert.deepEqual(t.shows, []); assert.equal(t.context.pinBusy, false);
  t.setAuthError(null); t.setPending(Promise.resolve({verified: false}));
  t.$('passkey-login').click(); await flush(); t.runTimers(); assert.deepEqual(t.shows, []);
  t.context.pinBusy = true; await t.api.afterPin(); t.runTimers(); assert.deepEqual(t.shows, ['home']);
});
test('manual login, persistent disable, failed disable, and reenrollment use native bridge', async () => {
  const t = setup({enabled: true}); t.initialize(); await flush();
  assert.equal(t.calls.some(c => c.action === 'authenticate'), false);
  t.$('passkey-login').click(); await flush(); t.runTimers(); assert.deepEqual(t.shows, ['home']);
  t.setRemoveError('Offline'); await t.api.toggle(); assert.equal(t.api.state().enabled, true);
  t.setRemoveError(null); await t.api.toggle(); assert.equal(t.api.state().enabled, false);
  t.api.cancel(); await t.api.ready(); assert.equal(t.api.state().enabled, false);
  await t.api.toggle(); assert.equal(t.api.state().enabled, true);
});
test('automatic login runs once and idle lock does not immediately unlock again', async () => {
  const t = setup({enabled: true, automatic: true}); t.initialize(); await flush(); t.runTimers();
  assert.deepEqual(t.shows, ['home']); assert.equal(t.calls.filter(c => c.action === 'authenticate').length, 1);
  t.context.demoLoggedIn = false; t.api.lock(); await t.api.ready(); await flush(); t.runTimers();
  assert.equal(t.calls.filter(c => c.action === 'authenticate').length, 1);
  assert.equal(t.$('passkey-login').hidden, false);
});
test('unsupported device keeps PIN login; changed token cancels pending transition', async () => {
  const t = setup({supported: false}); t.initialize(); await flush();
  assert.equal(t.$('passkey-login').hidden, true);
  t.context.pinBusy = true; await t.api.afterPin(); t.setToken('other'); t.runTimers(); assert.deepEqual(t.shows, []);
  t.context.pinBusy = true; await t.api.afterPin(); t.runTimers(); assert.deepEqual(t.shows, ['home']);
});
