#!/bin/bash
# Show whether the installed Haruna is your patched build and whether the update hook is set up.
cd "$(dirname "$(readlink -f "$0")")"
info=$(pacman -Qi haruna)
version=$(sed -n 's/^Version *: //p' <<< "$info")
packager=$(sed -n 's/^Packager *: //p' <<< "$info")
if [[ $packager == haruna-repatch* ]]; then
    echo "Haruna $version: PATCHED"
else
    echo "Haruna $version: STOCK (packager: $packager)"
fi
[[ -f /etc/pacman.d/hooks/haruna-repatch.hook ]] && echo "Update hook: installed" || echo "Update hook: NOT installed"
for p in repatch/haruna-*.patch; do
    if cmp -s "$p" "/usr/local/share/haruna-repatch/$(basename "$p")"; then
        echo "$(basename "$p"): installed copy matches"
    else
        echo "$(basename "$p"): installed copy differs or missing, run ./patch-reapply.sh"
    fi
done
state=$(systemctl is-active haruna-repatch 2>/dev/null)
[[ $state == active ]] && echo "Rebuild: running now (./patch-logs.sh)"
echo
echo "Last rebuild log:"
journalctl -u haruna-repatch --no-pager -o short 2>/dev/null | grep "haruna-repatch:" | tail -3
