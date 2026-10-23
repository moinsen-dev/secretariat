#!/usr/bin/env python3
"""Real local coding-client checks with a disposable credential and generated instructions.

Uses stored client sign-ins; no credential values are returned to models. Logs stay
in ignored .artifacts. No keychain is created, locked or unlocked. Cleanup removes
only this run's unique test entry, never an existing profile/credential.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import time
import uuid
import tomllib

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--binary', type=Path, default=Path.home() / 'Applications/Secretariat.app/Contents/MacOS/Secretariat')
parser.add_argument('--clients', nargs='*', choices=['codex', 'claude', 'opencode'], default=['codex', 'claude', 'opencode'])
parser.add_argument('--timeout', type=int, default=150)
parser.add_argument('--denied-fixture', action='store_true', help='Verify fail-closed CLI against a deliberately untrusted artificial item')
parser.add_argument('--opencode-model', help='Optional explicit model; otherwise keep the user default')
parser.add_argument('--codex-policy', choices=['workspace-write', 'user'], default='workspace-write')
args = parser.parse_args()
binary = args.binary.resolve()
artifacts = ROOT / '.artifacts'
artifacts.mkdir(exist_ok=True)
# Provider sign-in stays in each client's existing secret store. Exclude API-key
# overrides inherited from the caller so this check doesn't change billing mode.
environment = {k: v for k, v in os.environ.items() if not re.search(r'(API_KEY|SECRET|TOKEN|PASSWORD|CREDENTIAL)', k, re.I)}
results = {'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(), 'clients': {}}

def command(argv, cwd=None, env=None, timeout=20):
    return subprocess.run(list(map(str, argv)), cwd=cwd, env=env or environment, capture_output=True, text=True, timeout=timeout)

def require(result):
    if result.returncode:
        raise RuntimeError(f'Prerequisite exited {result.returncode}: {result.stderr[:300]} {result.stdout[:600]}')
    return result

with tempfile.TemporaryDirectory(prefix='secretariat-agent-acceptance-') as temporary:
    root = Path(temporary).resolve()
    home = root / 'vault'
    home.mkdir(mode=0o700)
    project = root / 'project'
    project.mkdir()
    service = 'dev.moinsen.secretariat.local.v1.' + hashlib.sha256(str(home).encode()).hexdigest()[:24]
    account = str(uuid.uuid4()).upper()
    fake_value = 'artificial-agent-value-' + uuid.uuid4().hex
    helper = root / 'fixture-helper'
    require(command(['swiftc', '-parse-as-library', ROOT / 'script/seed_agent_fixture.swift', '-o', helper], timeout=60))
    signing = command(['codesign', '-dv', '--verbose=4', binary]).stderr
    identity = re.search(r'^Authority=(Developer ID Application:.*)$', signing, re.M)
    if not identity:
        raise RuntimeError('Fixture requires the same Developer ID team as the installed app')
    require(command(['codesign', '--force', '--sign', identity.group(1), '--identifier',
                     'dev.moinsen.secretariat.local.fixture', '--options', 'runtime', '--timestamp=none', helper]))
    service = require(command([helper, 'service', home])).stdout.strip()
    require(command([helper, 'seed-denied' if args.denied_fixture else 'seed', service, account, binary, fake_value]))
    try:
        config = {'version': 1, 'revision': 0, 'secrets': [{'id': account, 'name': 'Prüfung Agenten'}], 'profiles': [
            {'id': str(uuid.uuid4()), 'name': 'agent-pruefung', 'directory': str(project), 'command': 'python3 verify.py', 'bindings': [
                {'id': str(uuid.uuid4()), 'variable': 'SECRETARIAT_ACCEPTANCE', 'secretID': account}]}]}
        metadata = home / 'profiles.json'
        metadata.write_text(json.dumps(config)); metadata.chmod(0o600)
        environment['SECRETARIAT_HOME'] = str(home)
        environment['PWD'] = str(project)
        # The marker is written by the launched test, not by the model's summary.
        (project / 'verify.py').write_text('import os,sys,json\nfrom pathlib import Path\n'
            f'assert os.environ.get("SECRETARIAT_ACCEPTANCE")=={fake_value!r}\n'
            'assert os.getcwd()==str(Path(__file__).resolve().parent)\n'
            'Path("receipt-"+sys.argv[1]+".json").write_text(json.dumps({"credential_verified":True,"cwd_verified":True}))\n'
            'print("SECRETARIAT_TEST_OK")\n')
        (project / 'AGENTS.md').write_text('# Acceptance project\nExecute only the requested verification; preserve project files.\n')
        (project / 'CLAUDE.md').write_text('# Acceptance project\nUse the project instructions below.\n')
        require(command([binary, 'setup', 'agent-pruefung', '--json'], env=environment))
        check = command([binary, 'check', 'agent-pruefung', '--json'], env=environment, timeout=60)
        if args.denied_fixture:
            assert check.returncode == 2 and not json.loads(check.stdout)['ok']
            elapsed = []
            for _ in range(3):
                started = time.monotonic()
                denied = command([binary, 'check', 'agent-pruefung', '--json'], env=environment)
                assert denied.returncode == 2 and not json.loads(denied.stdout)['ok']
                elapsed.append(round(time.monotonic()-started, 3))
            marker = project/'must-not-start'
            denied = command([binary, 'run', 'agent-pruefung', '--', '/usr/bin/touch', marker], env=environment)
            assert denied.returncode == 1 and not marker.exists()
            results['denied_credential_checks'] = {'check_exit_codes':[2,2,2], 'seconds':elapsed, 'run_exit_code':1, 'target_not_started':True}
        else:
            check = require(check)
            assert json.loads(check.stdout)['ok'], 'Noninteractive fixture check unavailable'
        # Run the prior packaged process regression against this isolated fixture.
        if not args.clients and not args.denied_fixture:
            check = require(command(['python3', ROOT/'script/integration_check.py', '--binary', binary, '--home', home, '--expected', fake_value], env=environment, timeout=40))
            results['packaged_process_checks'] = json.loads(check.stdout)
        for client in ([] if args.denied_fixture else args.clients):
            executable = shutil.which(client)
            if not executable:
                results['clients'][client] = {'status': 'not_installed'}
                continue
            receipt = project / f'receipt-{client}.json'
            prompt = (f'Read {project / "AGENTS.md"} (and {project / "CLAUDE.md"} if applicable) in this acceptance project. '
                      f'Follow its Secretariat instructions: first check the profile with --json; '
                      f'if ready, run the project test verify.py with argument {client} through Secretariat using '
                      f'{shutil.which("python3")}. Do not print environment or credential values. '
                      'Do not modify any files, use other integrations, or delegate. Report only whether the test passed.')
            if client == 'codex':
                argv = [executable, '--no-daemon', 'exec', '--ephemeral', '--ignore-user-config', '--skip-git-repo-check',
                        '-s', 'workspace-write', '-c', 'shell_environment_policy.inherit="core"',
                        '-c', 'shell_environment_policy.set=' + json.dumps({'SECRETARIAT_HOME': str(home)}).replace(': ', ' = '),
                        '--json', prompt]
                if args.codex_policy == 'user':
                    # Copy only non-secret policy/model fields into this isolated
                    # invocation. An unrelated broken MCP transport in user config
                    # must not prevent the acceptance fixture from starting.
                    config_path = Path(os.environ.get('CODEX_HOME', str(Path.home()/'.codex'))) / 'config.toml'
                    config = tomllib.loads(config_path.read_text()) if config_path.exists() else {}
                    position = argv.index('-s')
                    argv[position + 1] = config.get('sandbox_mode', 'workspace-write')
                    if config.get('model'):
                        argv[-1:-1] = ['-m', config['model']]
                    if config.get('approval_policy'):
                        argv[1:1] = ['--ask-for-approval', config['approval_policy']]
            elif client == 'claude':
                argv = [executable, '-p', prompt, '--no-session-persistence', '--setting-sources', 'project,local',
                        '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}', '--tools', 'Read,Bash',
                        '--allowedTools', f'Read,Bash({binary} *)', '--output-format', 'json']
            else:
                argv = [executable, 'run', '--standalone', '--format', 'json', prompt]
                if args.opencode_model:
                    argv[-1:-1] = ['--model', args.opencode_model]
            started = time.monotonic()
            process = subprocess.Popen(argv, cwd=project, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
            timed_out = False
            try:
                output, errors = process.communicate(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGTERM)
                try: output, errors = process.communicate(timeout=8)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL); output, errors = process.communicate()
            # Store output after replacing the synthetic value; never echo full client logs.
            (artifacts / f'agent-{client}.log').write_text((output + '\nSTDERR:\n' + errors).replace(fake_value, '[ARTIFICIAL_VALUE]'))
            results['clients'][client] = {'status': 'passed' if receipt.exists() else ('timeout' if timed_out else 'not_verified'),
                'exit_code': process.returncode, 'elapsed_seconds': round(time.monotonic() - started, 1),
                'receipt': json.loads(receipt.read_text()) if receipt.exists() else None,
                'artificial_value_in_output': fake_value in output + errors}
            print(json.dumps({client: results['clients'][client]}), flush=True)
    except Exception as error:
        results['fixture_error'] = str(error).replace(fake_value, '[ARTIFICIAL_VALUE]')
    finally:
        removed = command([helper, 'remove', service, account, binary, fake_value])
        results['fixture_credential_removed'] = removed.returncode == 0
        if removed.returncode: print('Cleanup status:', removed.stderr, flush=True)
(artifacts / ('agent-acceptance-' + ('denied' if args.denied_fixture else ('-'.join(args.clients) if args.clients else 'process')) + '.json')).write_text(json.dumps(results, indent=2))
print(json.dumps(results, indent=2))

if results.get("fixture_error") or not results.get("fixture_credential_removed") or any(item["status"] != "passed" for item in results["clients"].values()):
    raise SystemExit(1)
