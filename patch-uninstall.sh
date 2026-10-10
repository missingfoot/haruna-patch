#!/bin/bash
# Go back to stock Haruna for good: remove the update hook, script and patches, then reinstall
# the repo package. Your code and patches in this folder are kept; ./patch-reapply.sh undoes this.
set -euo pipefail
read -rp "Remove the repatch hook and reinstall stock Haruna? [y/N] " answer
[[ ${answer,,} == y* ]] || exit 0
sudo rm -f /etc/pacman.d/hooks/haruna-repatch.hook /usr/local/bin/haruna-repatch.sh
sudo rm -rf /usr/local/share/haruna-repatch
sudo pacman -S haruna
