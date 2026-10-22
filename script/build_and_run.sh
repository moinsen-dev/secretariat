#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
python3 - "$ROOT/dist/Secretariat.app/Contents/MacOS/Secretariat" <<'PY'
import os,signal,subprocess,sys
expected=sys.argv[1]
for line in subprocess.run(['ps','-axo','pid=,comm='],capture_output=True,text=True,check=True).stdout.splitlines():
    parts=line.strip().split(None,1)
    if len(parts)==2 and parts[1]==expected:
        try:os.kill(int(parts[0]),signal.SIGTERM)
        except ProcessLookupError:pass
PY
./script/build.sh
case "${1:-run}" in
  run) open -n "$ROOT/dist/Secretariat.app" ;;
  --verify) open -n "$ROOT/dist/Secretariat.app"; sleep 1; pgrep -x Secretariat >/dev/null ;;
  --debug) lldb -- "$ROOT/dist/Secretariat.app/Contents/MacOS/Secretariat" ;;
  --logs|--telemetry) open -n "$ROOT/dist/Secretariat.app"; /usr/bin/log stream --info --predicate 'process == "Secretariat"' ;;
  *) echo "Aufruf: $0 [--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
