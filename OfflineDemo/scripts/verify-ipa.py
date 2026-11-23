import base64
import json
import plistlib
import struct
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as ipa:
    root = 'Payload/WinterStudio.app/'
    info = plistlib.loads(ipa.read(root+'Info.plist'))
    assert info['CFBundleIdentifier']=='dev.accesshub.winterstudio.offline'
    assert info['CFBundleDisplayName']=='3377 Christmas Demo'
    assert info['CFBundleVersion']=='3'
    assert 'TestWebsiteURL' not in info
    assert 'NSAppTransportSecurity' not in info
    assert info['CFBundleURLTypes'][0]['CFBundleURLSchemes']==['winterstudiodemo']
    config = json.loads(ipa.read(root+'activation-public-key.json'))
    assert set(config) == {'maxDevices', 'publicKey'} and config['maxDevices'] == 200
    public_key = base64.b64decode(config['publicKey'], validate=True)
    assert len(public_key) == 65 and public_key[0] == 4
    executable = ipa.read(root+'WinterStudio')
    assert struct.unpack_from('<II', executable) == (0xfeedfacf, 0x0100000c), 'Expected a 64-bit ARM Mach-O'
    assert b'DEMO TEST\nNOT REAL ID' in executable
    for forbidden in [b'workers.dev',b'3377christmas',b'Service NSW',b'WKWebView',b'https://',b'WINTER-UI-TEST-ONLY']:
        assert forbidden not in executable, f'Unexpected external/legacy dependency: {forbidden!r}'
    assert not any(n.endswith(('.html','.js','.ipa','.pem','.sqlite','200-claim-keys.csv','demo-key-hashes.json')) for n in ipa.namelist())
print('Verified arm64 package, 200-device limit, public activation key, demo label and no website dependency.')
