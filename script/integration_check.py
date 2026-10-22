#!/usr/bin/env python3
"""Exercise the packaged CLI using explicitly disposable, UI-created credentials.

The selected home must contain only keys whose names start with 'Prüfung'.
The original metadata is restored; no real credential values are printed.
Close the app before running this check.
"""
import argparse
import json
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import sys
import tempfile
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--binary', type=Path, required=True)
parser.add_argument('--home', type=Path, required=True)
parser.add_argument('--expected', required=True, help='Artificial fixture value only')
args = parser.parse_args()
binary = str(args.binary.absolute())
metadata = args.home / 'profiles.json'
original = metadata.read_bytes()
config = json.loads(original)
assert config['secrets'] and all(key['name'].startswith('Prüfung') for key in config['secrets']), 'Only disposable fixture homes are allowed'
assert all(profile['name'].endswith('pruefung') for profile in config['profiles']), 'Only disposable fixture profiles are allowed'
secret_id = config['secrets'][0]['id']
environment = os.environ.copy()
environment['SECRETARIAT_HOME'] = str(args.home)
results = {}

def save(value):
    temporary = metadata.with_suffix('.integration-tmp')
    temporary.write_text(json.dumps(value))
    temporary.chmod(0o600)
    temporary.replace(metadata)

def run(profile, command, **kwargs):
    return subprocess.run([binary, 'run', profile, '--', *command], env=environment,
                          capture_output=True, text=True, timeout=15, **kwargs)

def ensure(result, *, code=0, output=None):
    assert result.returncode == code, f'Unexpected exit status {result.returncode}'
    if output is not None:
        assert result.stdout.strip() == output, 'Unexpected stdout'
    assert args.expected not in result.stdout + result.stderr, 'Fixture value leaked by launcher'

try:
    with tempfile.TemporaryDirectory(prefix='secretariat-process-') as temporary:
        root = Path(temporary).resolve()
        profiles = []
        for name in ['one-pruefung', 'two-pruefung']:
            profiles.append(dict(id=str(uuid.uuid4()), name=name, directory=str(root), command='true',
                                 bindings=[dict(id=str(uuid.uuid4()), variable='SECRETARIAT_ACCEPTANCE', secretID=secret_id)]))
        config['profiles'] = profiles
        save(config)
        code = "import os,sys; assert os.environ['SECRETARIAT_ACCEPTANCE']==sys.argv[1]; assert os.getcwd()==sys.argv[2]; assert sys.stdin.read()=='input-check'; print('IO-OK'); sys.exit(7)"
        ensure(run('one-pruefung', [sys.executable, '-c', code, args.expected, str(root)], input='input-check'), code=7, output='IO-OK')
        results['working_directory_environment_stdin_stdout_exitcode'] = True
        check = "import os,sys; assert os.environ['SECRETARIAT_ACCEPTANCE']==sys.argv[1]; print('SHARED-OK')"
        ensure(run('two-pruefung', [sys.executable, '-c', check, args.expected]), output='SHARED-OK')
        results['same_key_available_to_two_profiles'] = True
        arguments = ['space here', "single'quote", '$(touch SHOULD_NOT_EXIST)']
        quoted = "import sys; assert sys.argv[1:]==['space here', \"single'quote\", '$(touch SHOULD_NOT_EXIST)']; print('ARGV-OK')"
        ensure(run('one-pruefung', [sys.executable, '-c', quoted, *arguments]), output='ARGV-OK')
        assert not (root / 'SHOULD_NOT_EXIST').exists()
        results['literal_arguments_without_implicit_shell'] = True
        marker = root / 'must-not-start'
        ensure(run('unknown-profile', ['/usr/bin/touch', str(marker)]), code=1)
        assert not marker.exists()
        ensure(run('one-pruefung', ['missing-secretariat-program-12345']), code=1)
        results['unknown_profile_and_program_fail'] = True
        missing_id = str(uuid.uuid4())
        config['secrets'].append(dict(id=missing_id, name='Prüfung missing'))
        config['profiles'][0]['bindings'][0]['secretID'] = missing_id
        save(config)
        ensure(run('one-pruefung', ['/usr/bin/touch', str(marker)]), code=1)
        assert not marker.exists()
        results['missing_keychain_value_stops_before_child_launch'] = True
        config['profiles'][0]['bindings'][0]['secretID'] = secret_id
        save(config)
        pid, terminal = pty.fork()
        if pid == 0:
            script = "import signal,sys,time; signal.signal(signal.SIGINT,lambda *_:sys.exit(42)); print('READY',flush=True); time.sleep(20)"
            os.execve(binary, [binary, 'run', 'one-pruefung', '--', sys.executable, '-c', script], environment)
        try:
            observed = b''
            deadline = time.monotonic() + 10
            while b'READY' not in observed and time.monotonic() < deadline:
                if select.select([terminal], [], [], .2)[0]:
                    observed += os.read(terminal, 4096)
            assert b'READY' in observed, 'Child did not reach interactive state'
            os.write(terminal, b'\x03')
            status = None
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                done, candidate = os.waitpid(pid, os.WNOHANG)
                if done:
                    status = candidate
                    break
                time.sleep(.05)
            assert status is not None and os.waitstatus_to_exitcode(status) == 42, 'Ctrl-C did not reach target'
            results['real_terminal_ctrl_c_reaches_target'] = True
        finally:
            os.close(terminal)
            try:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
            except ProcessLookupError:
                pass
        broken = b'{invalid configuration'
        metadata.write_bytes(broken)
        failure = subprocess.run([binary, 'profiles'], env=environment, capture_output=True, text=True, timeout=10)
        ensure(failure, code=1)
        assert metadata.read_bytes() == broken
        results['corrupt_configuration_preserved'] = True
        assert args.expected not in original.decode()
        results['metadata_contains_no_fixture_values'] = True
finally:
    metadata.write_bytes(original)
    metadata.chmod(0o600)

print(json.dumps(results, indent=2))
