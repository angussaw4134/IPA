import json
from pathlib import Path
import subprocess

root=Path(__file__).resolve().parents[1]
devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j']))['devices']
phones=[d for runtime,rows in devices.items() if 'iOS' in runtime for d in rows if 'iPhone' in d['name']]
if not phones: raise SystemExit('No available iPhone simulator runtime')
device=next((d for d in phones if 'iPhone 16'==d['name']),phones[0])
print('Testing:',device['name'],flush=True)
subprocess.run(['xcrun','simctl','boot',device['udid']],check=False)
subprocess.run(['xcrun','simctl','bootstatus',device['udid'],'-b'],check=True)
subprocess.run(['xcodebuild','-project','WinterStudio.xcodeproj','-scheme','WinterStudio','-configuration','Debug','-destination','id='+device['udid'],'-derivedDataPath','build/Simulator','-resultBundlePath','build/OfflineDemo.xcresult','CODE_SIGNING_ALLOWED=NO','test'],cwd=root,check=True)
subprocess.run(['xcrun','xcresulttool','export','attachments','--path','build/OfflineDemo.xcresult','--output-path','build/screenshots'],cwd=root,check=False)
