#!/usr/bin/env python3
"""Real local coding-client checks against the installed Secretariat (1.0) in an isolated test home.

The test home gets its own keychain namespace (dev.moinsen.secretariat.items.test.*), so real items are
never touched. An artificial value goes in via `secretariat import` and out again via `item delete`.
Uses each client's stored sign-in; logs stay in ignored .artifacts with the value masked.
  --self-wire   no profile is prepared: the client lists items, creates the profile, binds, checks, runs
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

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--binary', type=Path, default=Path.home() / 'Applications/Secretariat.app/Contents/MacOS/Secretariat')
parser.add_argument('--clients', nargs='*', choices=['codex', 'claude', 'opencode'], default=['claude'])
parser.add_argument('--timeout', type=int, default=180)
parser.add_argument('--self-wire', action='store_true')
args = parser.parse_args()
binary = args.binary.resolve()
artifacts = ROOT / '.artifacts'
artifacts.mkdir(exist_ok=True)
# Provider sign-in stays in each client's own store; drop inherited API-key overrides.
environment = {k: v for k, v in os.environ.items() if not re.search(r'(API_KEY|SECRET|TOKEN|PASSWORD|CREDENTIAL)', k, re.I)}
results = {'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(), 'clients': {}}
ITEM = 'pruefung/agenten/acceptance'

def command(argv, cwd=None, timeout=60):
    return subprocess.run(list(map(str, argv)), cwd=cwd, env=environment, capture_output=True, text=True, timeout=timeout)

def require(result):
    if result.returncode:
        raise RuntimeError(f'exit {result.returncode}: {result.stderr[:300]} {result.stdout[:600]}')
    return result

with tempfile.TemporaryDirectory(prefix='secretariat-agent-acceptance-') as temporary:
    root = Path(temporary).resolve()
    home = root / 'vault'; home.mkdir(mode=0o700)
    project = root / 'project'; project.mkdir()
    fake_value = 'artificial-agent-value-' + uuid.uuid4().hex
    environment['SECRETARIAT_HOME'] = str(home)
    environment['PWD'] = str(project)
    try:
        seed = root / 'seed.env'
        seed.write_text(f'SECRETARIAT_ACCEPTANCE={fake_value}\n'); seed.chmod(0o600)
        require(command([binary, 'import', seed, f'SECRETARIAT_ACCEPTANCE={ITEM}/value', '--json']))
        seed.unlink()
        (project / 'verify.py').write_text('import os,sys,json\nfrom pathlib import Path\n'
            f'assert os.environ.get("SECRETARIAT_ACCEPTANCE")=={fake_value!r}\n'
            'Path("receipt-"+sys.argv[1]+".json").write_text(json.dumps({"credential_verified":True}))\n'
            'print("SECRETARIAT_TEST_OK")\n')
        (project / 'AGENTS.md').write_text('# Acceptance project\nExecute only the requested verification; preserve project files.\n')
        (project / 'CLAUDE.md').write_text('# Acceptance project\nUse the project instructions below.\n')
        if not args.self_wire:
            require(command([binary, 'profile', 'create', 'agent-pruefung', '--dir', project, '--command', 'python3 verify.py', '--json']))
            require(command([binary, 'profile', 'bind', 'agent-pruefung', 'SECRETARIAT_ACCEPTANCE', f'{ITEM}/value', '--json']))
            require(command([binary, 'setup', 'agent-pruefung', '--json']))
            assert json.loads(require(command([binary, 'check', 'agent-pruefung', '--json'])).stdout)['ok']
        for client in args.clients:
            executable = shutil.which(client)
            if not executable:
                results['clients'][client] = {'status': 'not_installed'}; continue
            receipt = project / f'receipt-{client}.json'
            python = shutil.which('python3')
            prompt = (f'This project needs the environment variable SECRETARIAT_ACCEPTANCE for its test verify.py. Wire it yourself '
                      f'with the Secretariat CLI {binary} (see `{binary} --help`): list the items with `items --json`, create a profile '
                      f'named agent-pruefung for the folder {project}, bind SECRETARIAT_ACCEPTANCE to the secret field of the item whose '
                      f'path starts with "pruefung/", check the profile with --json, then run verify.py with argument {client} through '
                      f'Secretariat using {python}. Never print environment or credential values, do not create .env files, do not '
                      'modify project files. Report only whether the test passed.') if args.self_wire else (
                      f'Read {project / "AGENTS.md"} in this acceptance project and follow its Secretariat instructions: check the '
                      f'profile with --json; if ready, run the project test verify.py with argument {client} through Secretariat using '
                      f'{python}. Do not print environment or credential values. Report only whether the test passed.')
            if client == 'codex':
                argv = [executable, '--no-daemon', 'exec', '--ephemeral', '--ignore-user-config', '--skip-git-repo-check',
                        '-s', 'workspace-write', '-c', 'shell_environment_policy.inherit="core"',
                        '-c', 'shell_environment_policy.set=' + json.dumps({'SECRETARIAT_HOME': str(home)}).replace(': ', ' = '), '--json', prompt]
            elif client == 'claude':
                argv = [executable, '-p', prompt, '--no-session-persistence', '--setting-sources', 'project,local',
                        '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}', '--tools', 'Read,Bash',
                        '--allowedTools', f'Read,Bash({binary} *)', '--output-format', 'json']
            else:
                argv = [executable, 'run', '--standalone', '--format', 'json', prompt]
            started = time.monotonic()
            process = subprocess.Popen(argv, cwd=project, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
            timed_out = False
            try:
                output, errors = process.communicate(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                timed_out = True; os.killpg(process.pid, signal.SIGTERM); output, errors = process.communicate()
            (artifacts / f'agent-{client}.log').write_text((output + '\nSTDERR:\n' + errors).replace(fake_value, '[ARTIFICIAL_VALUE]'))
            r = {'status': 'passed' if receipt.exists() else ('timeout' if timed_out else 'not_verified'),
                 'exit_code': process.returncode, 'elapsed_seconds': round(time.monotonic() - started, 1),
                 'artificial_value_in_output': fake_value in output + errors,
                 'env_files_created': sorted(p.name for p in project.glob('.env*'))}
            if args.self_wire:
                described = json.loads(command([binary, 'describe', 'agent-pruefung', '--json']).stdout)
                r['self_wired_profile'] = described.get('ok', False) and described['profile']['bindings'].get('SECRETARIAT_ACCEPTANCE') == f'{ITEM}/value'
            if r['artificial_value_in_output'] or r['env_files_created'] or (args.self_wire and not r.get('self_wired_profile')):
                r['status'] = 'not_verified'
            results['clients'][client] = r
            print(json.dumps({client: r}), flush=True)
            if args.self_wire:
                command([binary, 'profile', 'delete', 'agent-pruefung', '--json'])
    except Exception as error:
        results['fixture_error'] = str(error).replace(fake_value, '[ARTIFICIAL_VALUE]')
    finally:
        command([binary, 'profile', 'delete', 'agent-pruefung', '--json'])
        removed = command([binary, 'item', 'delete', ITEM, '--json'])
        results['fixture_item_removed'] = removed.returncode == 0
(artifacts / ('agent-acceptance-' + ('self-wire-' if args.self_wire else '') + '-'.join(args.clients) + '.json')).write_text(json.dumps(results, indent=2))
print(json.dumps(results, indent=2))
if results.get('fixture_error') or not results.get('fixture_item_removed') or any(r['status'] != 'passed' for r in results['clients'].values()):
    raise SystemExit(1)
