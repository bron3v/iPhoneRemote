#!/usr/bin/env python3
"""Create a disposable WDA working copy; change only the runner bundle IDs."""
from pathlib import Path
import os
import re
import shutil
root = Path(__file__).resolve().parent.parent
bundle = os.environ.get('WDA_BUNDLE_ID', '')
if not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)+', bundle):
    raise SystemExit('WDA_BUNDLE_ID deve essere un identificativo reverse-DNS valido')
source = root/'Research/WebDriverAgent'
if not (source/'WebDriverAgent.xcodeproj/project.pbxproj').is_file():
    raise SystemExit('Esegui prima Scripts/bootstrap-wda.sh')
destination = root/'build/wda-source'
# Copy into a dedicated generated directory, preserving the upstream checkout.
shutil.copytree(source, destination, dirs_exist_ok=True, ignore=shutil.ignore_patterns('.git', 'node_modules', 'build', 'xcuserdata'))
project = destination/'WebDriverAgent.xcodeproj/project.pbxproj'
text = project.read_text()
old = 'PRODUCT_BUNDLE_IDENTIFIER = com.facebook.WebDriverAgentRunner;'
if old not in text:
    raise SystemExit('Il progetto WDA è cambiato: verifica gli identificativi del runner')
project.write_text(text.replace(old, f'PRODUCT_BUNDLE_IDENTIFIER = {bundle};'))
print(destination/'WebDriverAgent.xcodeproj')
