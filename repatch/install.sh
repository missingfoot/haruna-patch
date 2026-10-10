#!/bin/bash
# Installs (or updates) the Haruna repatch hook, script and patches,
# then rebuilds and installs the patched Haruna in the background.
# Run with: ./patch-reapply.sh (or sudo ./repatch/install.sh)

set -euo pipefail

src=$(dirname "$(readlink -f "$0")")

if [[ -z ${SUDO_USER:-} || $SUDO_USER == root ]]; then
    echo "Run this with sudo from your normal user account, it builds Haruna as that user." >&2
    exit 1
fi

sed "s/^BUILD_USER=.*/BUILD_USER=$SUDO_USER/" "$src/haruna-repatch.sh" > /tmp/haruna-repatch.sh.new
install -Dm755 /tmp/haruna-repatch.sh.new /usr/local/bin/haruna-repatch.sh
rm /tmp/haruna-repatch.sh.new
install -Dm644 -t /usr/local/share/haruna-repatch "$src"/haruna-*.patch
install -Dm644 "$src/haruna-repatch.hook" /etc/pacman.d/hooks/haruna-repatch.hook

/usr/local/bin/haruna-repatch.sh --force
