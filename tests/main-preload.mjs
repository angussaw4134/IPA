import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {test} from 'node:test';
const source = await readFile(new URL('../App/MainPagePreload.js', import.meta.url), 'utf8');
const flush = async () => { for (let i=0; i<5; i++) await new Promise(setImmediate); };

function setup() {
  const started = [], decoded = [], privacy = [], frames = [], timers = new Map(), events = {}, docEvents = {};
  let timerID=0, observer, savedToken='one', license=false;
  class Image {
    constructor(src='') { this.source=src; this.events={}; this.complete=false; this.naturalWidth=0; }
    getAttribute(name) { return name==='src' ? this.source : null; }
    set src(value) { this.source=value; if(this.eager) started.push(this); }
    get src() { return this.source; }
    set loading(value) { this.eager=value==='eager'; if(this.source&&this.eager) started.push(this); }
    addEventListener(type,fn) { this.events[type]=fn; }
    removeEventListener(type) { delete this.events[type]; }
    decode() { decoded.push(this.source); return Promise.resolve(); }
    finish(ok=true) { this.complete=true;this.naturalWidth=ok?100:0;this.events[ok?'load':'error']?.(); }
  }
  const header=new Image('/header.png'),wallet=new Image('/wallet.png'),services=new Image('/services.png'),home=new Image('/featured.png');
  const unsafe=[new Image('https://other.example/a.png'),new Image('/api/session'),new Image('data:image/png,AAAA'),new Image('blob:https://site.test/a')];
  const selectors={'#screen-home .topbar img':[header], '#screen-wallet img':[wallet], '#screen-services img':[services], '#screen-home img':[header,home,...unsafe]};
  const context=vm.createContext({
    URL,Image,location:{href:'https://site.test/',origin:'https://site.test'},localStorage:{getItem:()=>savedToken},
    demoLoggedIn:false,demoActivated:true,NAV_IMG:{home:'/nav-home.png',services:'/nav-services.png',wallet:'/nav-wallet.png'},
    document:{readyState:'loading',hidden:false,body:{},querySelectorAll:s=>selectors[s]||[],getElementById:()=>({classList:{contains:()=>license}}),addEventListener:(t,f)=>docEvents[t]=f},
    window:{addEventListener:(t,f)=>events[t]=f,webkit:{messageHandlers:{privacyState:{postMessage:value=>privacy.push(value)}}}},
    MutationObserver:class {constructor(fn){observer=fn;} observe(){}},
    requestAnimationFrame:fn=>frames.push(fn),setTimeout:(fn,delay)=>{timers.set(++timerID,{fn,delay});return timerID;},clearTimeout:id=>timers.delete(id)
  });
  vm.runInContext(source,context);docEvents.DOMContentLoaded();
  return {context,started,decoded,privacy,events,docEvents,header,wallet,services,home,
    api:context.window.MainPagePreload,setLicense(value){license=value;observer();},setToken:value=>savedToken=value,
    paint(){while(frames.length)frames.shift()();for(const [id,t] of [...timers])if(t.delay===0){timers.delete(id);t.fn();}},
    timeout(){for(const [id,t] of [...timers]){timers.delete(id);t.fn();}}};
}
test('preload waits for login and first paint, then warms two safe images at a time', async()=>{
  const t=setup();t.api.warm();t.paint();assert.equal(t.started.length,0);
  t.context.demoLoggedIn=true;t.api.warm();assert.equal(t.started.length,0);
  t.paint();assert.deepEqual(t.started.map(i=>i.src),['/header.png','/wallet.png']);
  t.header.finish();await flush();assert.equal(t.started[2],t.services);
  t.wallet.finish();await flush();assert.equal(t.started[3],t.home);
  let completed=2;
  while(completed<t.started.length){t.started[completed++].finish();await flush();}
  assert.equal(t.started.length,7,'Four artwork images plus three navigation variants, without duplicates');
  assert.equal(t.decoded.length,7);
  t.api.warm();t.paint();assert.equal(t.started.length,7,'Already warmed images do not start again');
});
test('backgrounding and logout stop queued preloading; foreground resumes safely', async()=>{
  const t=setup();t.context.demoLoggedIn=true;t.api.warm();t.paint();t.context.document.hidden=true;
  t.header.finish();t.wallet.finish();await flush();assert.equal(t.started.length,2);
  t.context.document.hidden=false;t.events['accesshub-native-foreground']();t.paint();assert.equal(t.started.length,4);
  t.context.demoLoggedIn=false;t.api.cancel();t.services.finish();t.home.finish();await flush();assert.equal(t.started.length,4);
});
test('changed keys and failed downloads never continue the old queue or block login', async()=>{
  const t=setup();t.context.demoLoggedIn=true;t.api.warm();t.paint();t.setToken('replacement');
  t.header.finish(false);t.wallet.finish();await flush();assert.equal(t.started.length,2);
  t.api.cancel();t.api.warm();t.paint();await flush();
  t.timeout();await flush();assert.equal(t.context.demoLoggedIn,true);
});
test('privacy state follows only the licence route and suppresses duplicate messages',()=>{
  const t=setup();assert.deepEqual(t.privacy,[false]);
  t.setLicense(false);assert.deepEqual(t.privacy,[false]);
  t.setLicense(true);t.setLicense(true);t.setLicense(false);
  assert.deepEqual(t.privacy,[false,true,false]);
});
