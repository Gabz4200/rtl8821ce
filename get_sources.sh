#!/bin/bash
#
# Fetch the Endless OS rtl8821ce snapshot as a read-only reference.
# The fork never copies vendor files over its own tree.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null) || {
  echo "Error: not inside a git repository." >&2
  exit 1
}

dest="$repo_root/vendor/endless"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git clone --depth=1 https://github.com/endlessm/linux.git "$tmp/linux"
rm -rf "$dest"
mkdir -p "$dest"
cp -a "$tmp/linux/drivers/net/wireless/rtl8821ce/." "$dest/"

echo "Vendor reference updated in $dest"
