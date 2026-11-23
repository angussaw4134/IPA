import json
import plistlib
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as ipa:
    root = 'Payload/WinterStudio.app/'
    info = plistlib.loads(ipa.read(root+'Info.plist'))
    assert info['CFBundleIdentifier']=='dev.accesshub.winterstudio.offline'
    assert info['CFBundleDisplayName']=='Winter Studio Demo'
    assert 'TestWebsiteURL' not in info
    assert 'NSAppTransportSecurity' not in info
    assert info['CFBundleURLTypes'][0]['CFBundleURLSchemes']==['winterstudiodemo']
    keys = json.loads(ipa.read(root+'demo-key-hashes.json'))
    assert len(keys)==len(set(keys))==150
    assert all(len(k)==64 and all(c in '0123456789abcdef' for c in k) for k in keys)
    executable = ipa.read(root+'WinterStudio')
    assert b'DEMO TESTING BUILD' in executable
    for forbidden in [b'workers.dev',b'3377christmas',b'Service NSW',b'WKWebView',b'https://']:
        assert forbidden not in executable, f'Unexpected external/legacy dependency: {forbidden!r}'
    assert not any(n.endswith(('.html','.js','.ipa')) for n in ipa.namelist())
print('Verified arm64 package metadata, 150 demo-code hashes, permanent label and no website dependency.')
