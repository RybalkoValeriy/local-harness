#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
cd /mnt/c/Users/Valeriy/Downloads/ruby-play
export LM_STUDIO_URL="http://$(ip route show default | awk '{print $3; exit}'):1234/v1"
bin/rails runner "${1:-script/smoke.rb}"
