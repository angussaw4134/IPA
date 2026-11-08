(() => {
  'use strict';
  let generation = 0, owner = '', queue = [], active = 0, scheduled = false;
  const retained = new Map();
  const permitted = () => typeof demoLoggedIn !== 'undefined' && demoLoggedIn && demoActivated && !document.hidden;
  const token = () => localStorage.getItem('demoActivationToken') || '';
  function imageURL(value) {
    try {
      const url = new URL(value, location.href);
      return url.protocol === 'https:' && url.origin === location.origin && !url.username && !url.password
        && /\.(png|jpe?g|webp|avif|gif|svg|ico)$/i.test(url.pathname) ? url.href : null;
    } catch { return null; }
  }
  function pump() {
    if (!permitted() || owner !== token()) return;
    while (active < 2 && queue.length) {
      const {img, url} = queue.shift();
      const run = generation;
      active++;
      // Work on the real page image where possible so it is decoded before the
      // tab is shown. Do not fetch APIs, videos, uploaded photos or other hosts.
      img.decoding = 'async'; img.loading = 'eager';
      if (!img.getAttribute('src')) img.src = url;
      let timer;
      const finished = new Promise(resolve => {
        if (img.complete && img.naturalWidth) { resolve(); return; }
        const done = () => {
          img.removeEventListener('load', done); img.removeEventListener('error', done);
          clearTimeout(timer); resolve();
        };
        img.addEventListener('load', done, {once: true});
        img.addEventListener('error', done, {once: true});
        timer = setTimeout(done, 20000);
      }).then(() => img.complete && img.naturalWidth && img.decode ? img.decode().catch(() => {}) : undefined);
      finished.finally(() => { if (run === generation) { active--; pump(); } });
    }
  }
  function collect() {
    const seen = new Set();
    function add(img, source) {
      const url = imageURL(source);
      if (!url || seen.has(url)) return;
      seen.add(url); retained.set(url, img); queue.push({img, url});
    }
    // Prioritize the header and the two other main tabs, then the remaining home artwork.
    for (const selector of ['#screen-home .topbar img', '#screen-wallet img', '#screen-services img', '#screen-home img']) {
      document.querySelectorAll(selector).forEach(img => add(img, img.currentSrc || img.getAttribute('src')));
    }
    if (typeof NAV_IMG !== 'undefined') Object.values(NAV_IMG).forEach(source => add(new Image(), source));
  }
  function cancel() { generation++; owner = ''; queue = []; active = 0; scheduled = false; retained.clear(); }
  function warm() {
    if (!permitted() || !token()) return;
    if (owner !== token()) { cancel(); owner = token(); collect(); }
    if (scheduled) return;
    scheduled = true; const run = generation;
    // Let the login/home paint finish first. Never hold login on image downloads.
    requestAnimationFrame(() => setTimeout(() => {
      if (run !== generation) return;
      scheduled = false; pump();
    }, 0));
  }
  window.MainPagePreload = {warm, cancel};
  window.addEventListener('accesshub-native-foreground', warm);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) warm(); });

  function observePage() {
    let last;
    const update = () => {
      const license = document.getElementById('screen-license')?.classList.contains('active') === true;
      if (license === last) return;
      last = license;
      window.webkit?.messageHandlers?.privacyState?.postMessage(license);
    };
    update();
    new MutationObserver(update).observe(document.body, {subtree: true, attributes: true, attributeFilter: ['class']});
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', observePage, {once: true});
  else observePage();
})();
