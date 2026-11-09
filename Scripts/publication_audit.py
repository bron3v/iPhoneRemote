#!/usr/bin/env python3
"""Check the Git index for accidental personal/build artifacts before publication.

This is a conservative local heuristic, not proof that a repository has no secrets.
It never prints matching secret values and never contacts GitHub.
"""
import argparse
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

BLOCKED_DIRS = {'.git', '.local', '.build', 'build', 'Research', 'DerivedData',
                'xcuserdata', '__pycache__', '.venv'}
BLOCKED_SUFFIXES = {'.mobileprovision', '.provisionprofile', '.p12', '.pfx', '.pem',
                    '.key', '.cer', '.ipa', '.dmg', '.pkg', '.xctestrun', '.mov', '.mp4',
                    '.pyc', '.pyo', '.log', '.zip'}
BUNDLE_SUFFIXES = {'.app', '.xcarchive', '.xcresult', '.dSYM'}
PATTERNS = {
    'private key material': re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----'),
    'GitHub credential': re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b'),
    'API credential': re.compile(r'\bsk-[A-Za-z0-9_-]{24,}\b'),
    'personal home path': re.compile(r'/Users/[A-Za-z0-9_.-]+'),
    'device identifier': re.compile(r'\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}\b'),
}
REQUIRED_FILES = {'LICENSE', 'THIRD_PARTY_NOTICES.md', 'README.md', 'SECURITY.md',
                  'CONTRIBUTING.md', '.gitignore', '.github/workflows/ci.yml',
                  'ThirdPartyLicenses/WebDriverAgent-BSD.txt', 'ThirdPartyLicenses/Apache-2.0.txt'}

def issues_for(path, data, mode='100644'):
    """Inspect one staged file. Return reasons, without echoing its content."""
    name = PurePosixPath(path)
    issues = []
    if name.is_absolute() or '..' in name.parts or any(part in BLOCKED_DIRS for part in name.parts):
        issues.append('local/generated path')
    if mode not in {'100644', '100755'}:
        issues.append('symlink, submodule or unsupported file mode')
    if name.suffix.lower() in BLOCKED_SUFFIXES or any(PurePosixPath(part).suffix in BUNDLE_SUFFIXES for part in name.parts):
        issues.append('binary, account, media or signing artifact')
    if name.name in {'Setup.plist', '.DS_Store', '.env'} or (name.name.startswith('.env.') and name.name != '.env.example'):
        issues.append('local configuration')
    if name.suffix.lower() in {'.png', '.icns'}:
        if len(name.parts) < 2 or name.parts[0] != 'Assets':
            issues.append('image outside reviewed application assets')
        return issues
    if len(data) > 2 * 1024 * 1024:
        issues.append('unexpectedly large text/binary file')
        return issues
    if b'\x00' in data:
        issues.append('unexpected binary data')
        return issues
    text = data.decode('utf-8', errors='replace')
    for reason, pattern in PATTERNS.items():
        if pattern.search(text): issues.append(reason)
    return issues

def index_files(root):
    output = subprocess.check_output(['git', '-C', str(root), 'ls-files', '--stage', '-z'])
    result = []
    for record in output.split(b'\0'):
        if not record: continue
        metadata, path = record.split(b'\t', 1)
        mode, oid, stage = metadata.decode().split()
        if stage != '0': raise RuntimeError('Resolve index conflicts before publication')
        name = path.decode('utf-8')
        data = subprocess.check_output(['git', '-C', str(root), 'cat-file', 'blob', oid])
        result.append((name, data, mode))
    return result

def audit(root):
    files = index_files(root)
    violations = []
    for path, data, mode in files:
        for reason in issues_for(path, data, mode): violations.append({'path': path, 'reason': reason})
    for required in sorted(REQUIRED_FILES - {p for p, _, _ in files}):
        violations.append({'path': required, 'reason': 'required publication file missing'})
    if not files: violations.append({'path': '.', 'reason': 'Git index is empty; review and stage source files first'})
    return {'filesChecked': len(files), 'passed': not violations, 'violations': violations}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    try: result = audit(args.root)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(2, f'Audit unavailable: {type(error).__name__}. Use an initialized Git working tree.\n')
    output = json.dumps(result, indent=2) + '\n'
    print(output, end='')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output)
    raise SystemExit(0 if result['passed'] else 1)

if __name__ == '__main__': main()
