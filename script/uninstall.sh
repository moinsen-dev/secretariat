#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
exec python3 "$ROOT/script/install.py" uninstall "$@"
