#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
cd "$(dirname "$0")/.."
# Zed starts remote tools through a login shell. Ubuntu's noninteractive bashrc
# returns before its rbenv setup, so expose the shims from the login profile too.
if ! grep -q 'Zed WSL Ruby toolchain' "$HOME/.profile"; then
  cp "$HOME/.profile" "$HOME/.profile.backup-zed-$(date +%Y%m%d-%H%M%S)"
  cat >> "$HOME/.profile" <<'PROFILE'

# Zed WSL Ruby toolchain (also available to noninteractive login shells).
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
PROFILE
fi
bundle install
rbenv rehash
bundle exec ruby-lsp --version
bundle exec ruby -e 'puts "Ruby LSP Rails #{Gem.loaded_specs.fetch("ruby-lsp-rails").version}"'
