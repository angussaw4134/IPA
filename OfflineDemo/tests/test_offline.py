import base64
from pathlib import Path
import json
import plistlib
import unittest

ROOT=Path(__file__).resolve().parents[1]
class OfflineBuildTests(unittest.TestCase):
    def test_no_remote_runtime(self):
        for path in (ROOT/'App').glob('*.swift'):
            text=path.read_text()
            for forbidden in ['URLSession','WebKit','WKWebView','https://','http://','workers.dev']:
                self.assertNotIn(forbidden,text,str(path))
    def test_demo_resources(self):
        config=json.loads((ROOT/'App/activation-public-key.json').read_text())
        self.assertEqual(set(config),{'maxDevices','publicKey'})
        self.assertEqual(config['maxDevices'],200)
        pub=base64.b64decode(config['publicKey'],validate=True)
        self.assertEqual(len(pub),65)
        self.assertEqual(pub[0],4)
        self.assertFalse((ROOT/'App/demo-key-hashes.json').exists())
        text=(ROOT/'App/WinterStudioApp.swift').read_text(encoding='utf-8')
        self.assertIn(r'DEMO TEST\nNOT REAL ID',text)
        self.assertIn('FICTIONAL SAMPLE PASS',text)
        self.assertNotIn('Service NSW',text)
    def test_bundle_is_separate(self):
        info=plistlib.loads((ROOT/'App/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleDisplayName'],'3377 Christmas Demo')
        self.assertNotIn('TestWebsiteURL',info)
        self.assertEqual(info['CFBundleURLTypes'][0]['CFBundleURLSchemes'],['winterstudiodemo'])
    def test_test_code_debug_only(self):
        text=(ROOT/'App/DemoAccess.swift').read_text()
        start=text.index('#if DEBUG')
        end=text.index('#endif',start)
        self.assertIn('cleaned == "WINTER-UI-TEST-ONLY"',text[start:end])
        self.assertIn('verifies(cleaned, deviceID:',text[end:])
if __name__=='__main__': unittest.main()
