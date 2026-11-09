#!/usr/bin/env python3
"""Export the reviewed Git index as a source-only ZIP; never publish or sign it."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
from publication_audit import audit, index_files

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
result = audit(root)
if not result['passed']:
    print(json.dumps(result, indent=2))
    raise SystemExit('Source audit failed; nothing exported.')
files = index_files(root)
# Read version from the staged snapshot, not a possibly edited working-tree file.
version = plistlib.loads(next(data for path, data, _ in files if path == 'Config/Info.plist'))['CFBundleShortVersionString']
if not all(c.isdigit() or c == '.' for c in version): raise SystemExit('Unsupported version string')
output = (args.output or root/'build/releases'/f'iPhoneRemote-{version}-source.zip').resolve()
try: output.relative_to(root/'build')
except ValueError: raise SystemExit('Output must stay under build/ to avoid publishing generated archives accidentally.')
output.parent.mkdir(parents=True, exist_ok=True)
tree = subprocess.check_output(['git', '-C', str(root), 'write-tree'], text=True).strip()
subprocess.run(['git', '-C', str(root), 'archive', '--format=zip', f'--prefix=iPhoneRemote-{version}/',
                f'--output={output}', tree], check=True)
manifest = {'version': version, 'sourceTree': tree,
            'archive': output.name, 'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
            'files': [{'path': path, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)} for path, data, _ in files]}
output.with_suffix('.manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
print(json.dumps({'archive': str(output), 'files': len(files), 'sha256': manifest['sha256']}, indent=2))
