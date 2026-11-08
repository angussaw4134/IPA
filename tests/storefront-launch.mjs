import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {test} from 'node:test';
const source = readFileSync(new URL('../App/StorefrontLaunch.js', import.meta.url), 'utf8');
function setup(values = {}) {
  const calls = [];
  const window = {MainPagePreload:{warm:()=>calls.push('preload')}};
  window.top = window;
  const context = vm.createContext({window, ...values});
  vm.runInContext(source, context);
  return {context, calls, open:()=>window.StorefrontLaunch.openHome()};
}
test('cold launch waits through access entry and opens home after router initialization', () => {
  const t = setup();
  assert.equal(t.open(), false);
  Object.assign(t.context, {demoActivated:true, demoLoggedIn:true, show:page=>t.calls.push(page)});
  assert.equal(t.open(), true);
  assert.deepEqual(t.calls, ['home','preload']);
});
test('warm and repeated launches route to home without reloading or changing authentication', () => {
  const t = setup({demoActivated:true, demoLoggedIn:true});
  t.context.show = page=>t.calls.push(page);
  t.open();t.open();
  assert.deepEqual(t.calls, ['home','preload','home','preload']);
  assert.equal(t.context.demoLoggedIn, true);
});
test('locked, unactivated and revoked sessions cannot be unlocked by a launch URL', () => {
  for (const [demoActivated,demoLoggedIn] of [[false,false],[true,false],[false,true]]) {
    const t = setup({demoActivated,demoLoggedIn});
    t.context.show = page=>t.calls.push(page);
    assert.equal(t.open(), true);
    assert.deepEqual(t.calls, []);
    assert.equal(t.context.demoActivated, demoActivated);
    assert.equal(t.context.demoLoggedIn, demoLoggedIn);
  }
});
test('subframes do not install a launch bridge', () => {
  const window = {top:{}};
  vm.runInNewContext(source, {window});
  assert.equal(window.StorefrontLaunch, undefined);
});
