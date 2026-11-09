#!/usr/bin/env python3
"""Package a personal native macOS application, its signed runner, and renewal sources."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--udid', required=True)
parser.add_argument('--destination', default='/Applications/iPhone Remote.app')
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
products=root/'build/wda/Build/Products'
manifest=next(products.glob('*.xctestrun'),None)
runner=products/'Debug-iphoneos/WebDriverAgentRunner-Runner.app'
if not manifest or not runner.exists():
    raise SystemExit('Prima compila WDA con build-for-testing e firma valida.')
profile=plistlib.loads(subprocess.check_output(['/usr/bin/security','cms','-D','-i',str(runner/'embedded.mobileprovision')]))
if args.udid not in profile.get('ProvisionedDevices',[]):
    raise SystemExit('Il profilo firmato non include questo iPhone.')
certificate=hashlib.sha1(profile['DeveloperCertificates'][0]).hexdigest().upper()
team=profile['TeamIdentifier'][0]
source=root/'build/mac/Build/Products/Release/iPhone Remote.app'
stage=root/'build/personal/iPhone Remote.app'
if stage.exists(): shutil.rmtree(stage)
shutil.copytree(source,stage,symlinks=True)
automation=stage/'Contents/Resources/DeviceAutomation'
automation.mkdir(parents=True)
packaged_products=automation/'Products'
packaged_products.mkdir()
shutil.copy2(manifest,packaged_products/manifest.name)
for name in ['WebDriverAgentRunner-Runner.app','WebDriverAgentLib.framework']:
    target=packaged_products/'Debug-iphoneos'/name
    target.parent.mkdir(exist_ok=True)
    shutil.copytree(products/'Debug-iphoneos'/name,target,symlinks=True)
shutil.copytree(root/'build/wda-source',automation/'Source',symlinks=True,
    ignore=shutil.ignore_patterns('.git','node_modules','build','xcuserdata','.DS_Store'))
setup={'udid':args.udid,'teamID':team,'developerDirectory':os.environ.get('DEVELOPER_DIR','/Applications/Xcode.app/Contents/Developer')}
(automation/'Setup.plist').write_bytes(plistlib.dumps(setup))
licenses=stage/'Contents/Resources/Licenses';licenses.mkdir()
shutil.copy2(root/'Research/WebDriverAgent/LICENSE',licenses/'WebDriverAgent-LICENSE.txt')
shutil.copy2(root/'LICENSE',licenses/'iPhoneRemote-MIT.txt')
shutil.copy2(root/'THIRD_PARTY_NOTICES.md',licenses/'THIRD_PARTY_NOTICES.md')
for license_file in (root/'ThirdPartyLicenses').iterdir():
    if license_file.is_file(): shutil.copy2(license_file,licenses/license_file.name)
subprocess.run(['/usr/bin/codesign','--verify','--strict',str(packaged_products/'Debug-iphoneos/WebDriverAgentRunner-Runner.app')],check=True)
# Sign the Mac container only; retain the independent iOS runner signatures.
subprocess.run(['/usr/bin/codesign','--force','--sign',certificate,'--timestamp=none',str(stage)],check=True)
subprocess.run(['/usr/bin/codesign','--verify','--strict',str(stage)],check=True)
destination=Path(args.destination).expanduser().resolve()
destination.parent.mkdir(parents=True,exist_ok=True)
backup=None
if destination.exists():
    info=plistlib.loads((destination/'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier')!='it.local.iphoneremote':
        raise SystemExit('La destinazione contiene un’altra applicazione; nessuna sostituzione eseguita.')
    backups=Path.home()/'Library/Application Support/iPhone Remote/Backups'
    backups.mkdir(parents=True,exist_ok=True)
    backup=backups/(datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'-iPhone Remote.app')
    destination.rename(backup)
try:
    shutil.copytree(stage,destination,symlinks=True)
    subprocess.run(['/usr/bin/codesign','--verify','--strict',str(destination)],check=True)
except Exception:
    if destination.exists(): shutil.rmtree(destination)
    if backup: backup.rename(destination)
    raise
report={'installed':str(destination),'runnerProfileExpires':profile['ExpirationDate'].isoformat()+'Z','containsSignedRunner':True,'containsRenewalSources':True,'macSigning':'Apple Development'}
(root/'build/logs/personal-install.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
