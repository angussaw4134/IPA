import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {test} from 'node:test';
const template = await readFile(new URL('../App/WebsiteState.js', import.meta.url), 'utf8');
const origin = 'https://3377test.erg3be.workers.dev';
const profile = {
  demoActivationToken:'existing-activation', licenceDetails:JSON.stringify({name:'Sample',photo:'data:image/jpeg;base64,AA=='}),
  demoProfileSettings:'{"pin":"1234"}', demoProfileSettingsOwner:'existing-activation',
  demoSecuritySettings:'{"automaticFaceId":false,"lockMinutes":15}', svcOrder:'[6,5,4,3,2,1,0]'
};
function launch({saved=profile,current={},url=origin,iframe=false,failKey=null}={}) {
  const events={}, docEvents={}, posted=[];
  class Storage {
    constructor(values={}) { this.values=new Map(Object.entries(values)); }
    getItem(k) {return this.values.get(String(k))??null;}
    setItem(k,v) {if(k===failKey)throw new Error('Quota exceeded');this.values.set(String(k),String(v));}
    removeItem(k) {this.values.delete(String(k));}
    clear() {this.values.clear();}
  }
  const localStorage=new Storage(current),sessionStorage=new Storage();
  const window={localStorage,sessionStorage,addEventListener:(e,f)=>events[e]=f,
    webkit:{messageHandlers:{websiteState:{postMessage:v=>posted.push(JSON.parse(JSON.stringify(v)))}}}};
  window.top=iframe?{}:window;
  const document={readyState:'loading',addEventListener:(e,f)=>docEvents[e]=f};
  const context=vm.createContext({window,document,Storage,location:{origin:url}});
  vm.runInContext(template.replace('__WEBSITE_STATE__',JSON.stringify({origin,values:saved})),context);
  return {localStorage,sessionStorage,posted,events,ready:()=>docEvents.DOMContentLoaded?.(),
    state:()=>Object.fromEntries(localStorage.values)};
}

test('reinstall with retained WebKit data preserves latest settings and the same activation',()=>{
  const current={...profile,licenceDetails:'{"name":"Latest saved profile"}',adminToken:'never-copy'};
  const app=launch({current});app.ready();
  assert.deepEqual(app.state(),current);
  assert.equal(app.posted.at(-1).demoActivationToken,profile.demoActivationToken);
  assert.equal(app.posted.at(-1).licenceDetails,current.licenceDetails);
  assert.equal(app.posted.at(-1).adminToken,undefined);
});
test('empty WebKit storage restores photos, settings and existing token before page scripts run',()=>{
  const app=launch();assert.deepEqual(app.state(),profile);
  // There is deliberately no fetch or activation API in the restore integration.
  app.ready();assert.deepEqual(app.posted.at(-1),profile);
});
test('existing different activation is never overwritten or filled with the previous customer profile',()=>{
  const current={demoActivationToken:'another-customer',svcOrder:'[]'};
  const app=launch({current});app.ready();assert.deepEqual(app.state(),current);
  assert.deepEqual(app.posted.at(-1),current);
});
test('token removal and clearing forget the recovery copy rather than resurrecting revoked access',()=>{
  const app=launch();app.ready();app.localStorage.removeItem('demoActivationToken');
  assert.deepEqual(app.posted.at(-1),{});
  const next=launch({saved:app.posted.at(-1),current:app.state()});next.ready();
  assert.equal(next.localStorage.getItem('demoActivationToken'),null);
  app.localStorage.clear();assert.deepEqual(app.posted.at(-1),{});
});
test('settings changes and new activation are copied immediately, including before a redirect',()=>{
  const app=launch({saved:{},current:{}});app.ready();
  app.localStorage.setItem('demoActivationToken','new-activation');
  assert.deepEqual(app.posted.at(-1),{demoActivationToken:'new-activation'});
  app.localStorage.setItem('svcOrder','[1,0,2,3,4,5,6]');
  assert.equal(app.posted.at(-1).svcOrder,'[1,0,2,3,4,5,6]');
  app.localStorage.removeItem('svcOrder');assert.equal(app.posted.at(-1).svcOrder,undefined);
  const count=app.posted.length;
  app.sessionStorage.setItem('demoActivationToken','unrelated');
  app.localStorage.setItem('serverAdminHandoff','privileged');
  assert.equal(app.posted.length,count);
});
test('quota failure rolls back partial restoration and keeps the good native backup untouched',()=>{
  const app=launch({failKey:'demoProfileSettings'});app.ready();
  assert.deepEqual(app.state(),{});assert.equal(app.posted.length,0);
});
test('other origins and subframes cannot restore or submit profile snapshots',()=>{
  for(const opts of [{url:'https://other.example'}, {iframe:true}]){
    const app=launch(opts);app.ready();assert.deepEqual(app.state(),{});assert.equal(app.posted.length,0);
  }
});
