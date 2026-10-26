#!/usr/bin/env python3
"""Local installation management. Never removes a vault, credentials or foreign apps."""
import argparse
import datetime
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import tempfile

IDENTIFIER = 'dev.moinsen.secretariat.local'
ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('action', choices=['install', 'uninstall'])
parser.add_argument('--app-dir', type=Path, default=Path.home() / 'Applications')
parser.add_argument('--bin-dir', type=Path, default=Path.home() / 'bin')
args = parser.parse_args()
bundle = args.app_dir.absolute() / 'Secretariat.app'
link = args.bin_dir.absolute() / 'secretariat'
target = bundle / 'Contents/MacOS/Secretariat'

def verify_bundle(path):
    if path.is_symlink():
        raise SystemExit(f'Fremder Verweis bleibt erhalten: {path}')
    try:
        with (path / 'Contents/Info.plist').open('rb') as f:
            identifier = plistlib.load(f).get('CFBundleIdentifier')
    except (OSError, ValueError):
        raise SystemExit(f'Unbekannte Installation bleibt erhalten: {path}')
    if identifier != IDENTIFIER:
        raise SystemExit(f'Andere App bleibt erhalten: {path}')

def verify_link():
    if os.path.lexists(link):
        if not link.is_symlink() or Path(os.path.abspath(os.path.join(link.parent, os.readlink(link)))) != target:
            raise SystemExit(f'Vorhandene Terminaldatei bleibt erhalten: {link}')

def stop_app():
    for line in subprocess.run(['ps', '-axo', 'pid=,comm='], capture_output=True, text=True, check=True).stdout.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) == 2 and parts[1] == str(target):
            try:
                os.kill(int(parts[0]), signal.SIGTERM)
            except ProcessLookupError:
                pass

if os.path.lexists(bundle):
    verify_bundle(bundle)
verify_link()

if args.action == 'install':
    source = ROOT / 'dist/Secretariat.app'
    verify_bundle(source)
    subprocess.run(['codesign', '--verify', '--strict', str(source)], check=True)
    args.app_dir.mkdir(parents=True, exist_ok=True)
    args.bin_dir.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.secretariat-install-', dir=args.app_dir))
    try:
        shutil.copytree(source, stage / 'Secretariat.app')
        subprocess.run(['codesign', '--verify', '--strict', str(stage / 'Secretariat.app')], check=True)
        stop_app()
        if bundle.exists():
            backup = stage / 'previous.app'
            bundle.rename(backup)
        try:
            (stage / 'Secretariat.app').rename(bundle)
            if not os.path.lexists(link):
                link.symlink_to(target)
        except Exception:
            if bundle.exists():
                shutil.rmtree(bundle)
            if (stage / 'previous.app').exists():
                (stage / 'previous.app').rename(bundle)
            raise
    finally:
        shutil.rmtree(stage)
    print(f'Installiert: {bundle}\nTerminal: {link}')
else:
    stop_app()
    if link.is_symlink():
        link.unlink()
    if bundle.exists():
        # Recoverable application removal, separate from all credential data.
        trash = Path.home() / '.Trash'
        trash.mkdir(exist_ok=True)
        destination = trash / ('Secretariat-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.app')
        bundle.rename(destination)
        print(f'App im Papierkorb: {destination}')
    print('Secretariat removed. Stored keys and profiles are kept.')
