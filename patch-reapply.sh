#!/bin/bash
# Install the repatch hook, script and patches, then rebuild and install the patched Haruna.
# Use after changing the patches, or whenever you want your patched build back.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
sudo ./repatch/install.sh
echo "Building in the background. Follow it with ./patch-logs.sh"
