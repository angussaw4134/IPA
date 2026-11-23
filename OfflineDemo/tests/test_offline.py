from pathlib import Path
import json
import plistlib
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]
class OfflineBuildTests(unittest.TestCase):
    def test_no_remote_runtime(self):
        for path in (ROOT/'App').glob('*.swift'):
            text=path.read_text()
            for forbidden in ['URLSession','WebKit','WKWebView','https://','http://','workers.dev']:
                self.assertNotIn(forbidden,text,str(path))
    def test_demo_resources(self):
        hashes=json.loads((ROOT/'App/demo-key-hashes.json').read_text())
        self.assertEqual(len(hashes),150)
        self.assertEqual(len(set(hashes)),150)
        self.assertTrue(all(re.fullmatch('[a-f0-9]{64}',h) for h in hashes))
        text=(ROOT/'App/WinterStudioApp.swift').read_text()
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
        self.assertIn('hash == digest(testCode)',text[start:end])
        self.assertIn('return hashes.contains(hash)',text[end:])
if __name__=='__main__': unittest.main()
