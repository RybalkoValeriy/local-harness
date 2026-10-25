#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tmp/opencode-probe
tar -xzf tmp/opencode-linux-x64-1.19.4.tgz -C tmp/opencode-probe
tmp/opencode-probe/package/bin/opencode --version
tmp/opencode-probe/package/bin/opencode run --help
