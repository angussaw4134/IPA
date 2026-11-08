(() => {
  'use strict';
  const backup = __WEBSITE_STATE__;
  if (location.origin !== backup.origin || window.top !== window) return;
  const bridge = window.webkit?.messageHandlers?.websiteState;
  if (!bridge) return;
  const keys = ['demoActivationToken', 'licenceDetails', 'demoProfileSettings',
    'demoProfileSettingsOwner', 'demoSecuritySettings', 'svcOrder', 'accessHubDemoAccountEmail'];
  const tokenKey = keys[0];
  let storage;
  try { storage = window.localStorage; } catch { return; }
  const proto = Storage.prototype;
  const get = proto.getItem, set = proto.setItem, remove = proto.removeItem, clear = proto.clear;
  let restoreFailed = false;
  // Run before website scripts read their settings. The normal /api/session check
  // remains in charge: restoring an activation never redeems another access key.
  try {
    const existingToken = get.call(storage, tokenKey);
    const savedToken = backup.values[tokenKey];
    if (savedToken && (!existingToken || existingToken === savedToken)) {
      const before = new Map();
      try {
        // Restore the token last, after the rest of the profile succeeds.
        for (const key of [...keys.slice(1), tokenKey]) {
          const current = get.call(storage, key);
          if (existingToken && current !== null) continue;
          if (typeof backup.values[key] !== 'string') continue;
          before.set(key, current);
          set.call(storage, key, backup.values[key]);
        }
      } catch {
        for (const [key, value] of before) {
          try { value === null ? remove.call(storage, key) : set.call(storage, key, value); } catch {}
        }
        restoreFailed = true;
      }
    }
  } catch { restoreFailed = true; }
  function snapshot() {
    if (restoreFailed) return; // Do not replace a good backup after quota/storage failure.
    try {
      const values = {};
      if (get.call(storage, tokenKey)) {
        for (const key of keys) {
          const value = get.call(storage, key);
          if (value !== null) values[key] = value;
        }
      }
      bridge.postMessage(values);
    } catch {}
  }
  proto.setItem = function(key, value) {
    const name = String(key);
    const result = set.call(this, name, value);
    if (this === storage && keys.includes(name)) snapshot();
    return result;
  };
  proto.removeItem = function(key) {
    const name = String(key);
    const result = remove.call(this, name);
    if (this === storage && keys.includes(name)) {
      if (name === tokenKey) restoreFailed = false;
      snapshot();
    }
    return result;
  };
  proto.clear = function() {
    const result = clear.call(this);
    if (this === storage) { restoreFailed = false; snapshot(); }
    return result;
  };
  window.addEventListener('pagehide', snapshot);
  document.addEventListener('visibilitychange', snapshot);
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', snapshot, {once:true});
  else snapshot();
})();
