#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
cd /mnt/c/Users/Valeriy/Downloads/ruby-play
bin/rails db:prepare
bash bin/build-frontend run build
bin/rails test
bin/rails zeitwerk:check
bin/rubocop
