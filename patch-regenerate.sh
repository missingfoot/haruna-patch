#!/bin/bash
# Regenerate the patch files from the git branches after changing the code, then reapply.
#   haruna-1.8.1-patched -> repatch/haruna-1.8.1.patch (applies to the current release)
#   zoom-pan-and-quit    -> repatch/haruna-master.patch (for when a new release catches up with master)
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
git diff v1.8.1 haruna-1.8.1-patched -- src > repatch/haruna-1.8.1.patch
git diff "$(git merge-base origin/master zoom-pan-and-quit)" zoom-pan-and-quit -- src > repatch/haruna-master.patch
echo "Patches regenerated:"
wc -l repatch/haruna-*.patch
read -rp "Reinstall the patched Haruna now? [Y/n] " answer
[[ ${answer,,} == n* ]] || ./patch-reapply.sh
