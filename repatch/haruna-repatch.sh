#!/bin/bash
# Rebuilds Haruna with the haruna-patch mod after a repo update replaces it:
#   - click and drag to pan zoomed video, left click acts on release
#   - Quit in the video context menu
#   - = and - zoom shortcuts
#   - 1/2/3 view modes (No UI, Seek Bar Only, Full UI)
# Haruna compiles its QML into the binary, so unlike latte-ng-repatch.sh this
# has to rebuild the package from source rather than sed the installed files.
#
# Run from the pacman hook (as root) it only starts a background systemd unit,
# because pacman holds its lock while hooks run. The unit (--build) waits for
# the lock, builds a package with the same version as the installed one using
# makepkg as $BUILD_USER, installs it with pacman -U and sends a notification.
# Packages built here are stamped with $PACKAGER so the hook firing again for
# our own install is a no-op.
#
# Usage:
#   haruna-repatch.sh           rebuild only if the installed haruna isn't already patched
#   haruna-repatch.sh --force   rebuild even if it is, e.g. after changing the patches
#
# Logs: journalctl -u haruna-repatch

set -euo pipefail

BUILD_USER=__BUILD_USER__  # filled in by install.sh
SHARE=/usr/local/share/haruna-repatch
PACKAGER="haruna-repatch <haruna-repatch@localhost>"
LOCK=/var/lib/pacman/db.lck

is_patched() {
    pacman -Qi haruna 2>/dev/null | grep -q '^Packager *: haruna-repatch '
}

notify() {
    local uid
    uid=$(id -u "$BUILD_USER")
    runuser -u "$BUILD_USER" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        notify-send --app-name=Haruna --icon=haruna "$@" || true
}

force=""
for arg in "$@"; do
    [[ $arg == --force ]] && force=--force
done

if [[ ${1:-} != --build ]]; then
    if [[ -z $force ]] && is_patched; then
        exit 0
    fi
    systemd-run --no-block --collect --unit=haruna-repatch "$0" --build $force >/dev/null
    echo "haruna-repatch: rebuilding patched Haruna in the background (journalctl -u haruna-repatch)"
    exit 0
fi

workdir=""
trap 'notify -u critical "Haruna repatch failed" "The unpatched update is still installed. See: journalctl -u haruna-repatch"; [[ -n $workdir ]] && rm -rf "$workdir"' ERR

# wait up to 30 minutes for the pacman transaction that triggered us to finish
for _ in $(seq 1800); do
    [[ -e $LOCK ]] || break
    sleep 1
done
if [[ -e $LOCK ]]; then
    echo "haruna-repatch: pacman is still locked, giving up" >&2
    false
fi

if [[ -z $force ]] && is_patched; then
    exit 0
fi

full=$(pacman -Q haruna | cut -d' ' -f2)   # [epoch:]pkgver-pkgrel
epoch=""
if [[ $full == *:* ]]; then
    epoch=${full%%:*}
    full=${full#*:}
fi
pkgver=${full%-*}
pkgrel=${full##*-}
depends=$(pacman -Qi haruna | sed -n 's/^Depends On *: //p')

tarball_url="https://download.kde.org/stable/haruna/$pkgver/haruna-$pkgver.tar.xz"
tarball_sha=$(curl -fsSL "$tarball_url.sha256" | cut -d' ' -f1)

workdir=$(runuser -u "$BUILD_USER" -- mktemp -d /tmp/haruna-repatch.XXXXXX)
cd "$workdir"

# use the first patch that applies: the one made against the last release,
# then the one made against master for when a new release catches up with it
patch=""
runuser -u "$BUILD_USER" -- curl -fsSL -o "haruna-$pkgver.tar.xz" "$tarball_url"
echo "$tarball_sha  haruna-$pkgver.tar.xz" | sha256sum -c -
runuser -u "$BUILD_USER" -- tar -xf "haruna-$pkgver.tar.xz"
for p in "$SHARE"/haruna-*.patch; do
    if patch --dry-run -s -p1 -d "haruna-$pkgver" < "$p" >/dev/null; then
        patch=$p
        break
    fi
done
rm -rf "haruna-$pkgver"
if [[ -z $patch ]]; then
    echo "haruna-repatch: no patch applies to haruna $pkgver" >&2
    notify -u critical "Haruna repatch: patch no longer applies" \
        "Haruna $pkgver changed too much. The unpatched update is still installed."
    rm -rf "$workdir"
    exit 1
fi
echo "haruna-repatch: using $patch"
install -o "$BUILD_USER" -m 644 "$patch" haruna.patch

cat > PKGBUILD <<EOF
pkgname=haruna
pkgver=$pkgver
pkgrel=$pkgrel
${epoch:+epoch=$epoch}
pkgdesc='Open source video player built with Qt/QML and libmpv (with local patches)'
arch=(x86_64)
url='https://apps.kde.org/haruna/'
license=(GPL-3.0-or-later)
depends=($depends)
makedepends=(extra-cmake-modules)
options=(!debug)
source=("$tarball_url" haruna.patch)
sha256sums=('$tarball_sha' 'SKIP')

prepare() {
  patch -d haruna-\$pkgver -p1 < haruna.patch
}

build() {
  cmake -B build -S haruna-\$pkgver -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_TESTING=OFF
  cmake --build build
}

package() {
  DESTDIR="\$pkgdir" cmake --install build
}
EOF
chown "$BUILD_USER" PKGBUILD

runuser -u "$BUILD_USER" -- env PACKAGER="$PACKAGER" PKGDEST="$workdir" makepkg -f --noconfirm --noprogressbar

pkgfile=$(ls "$workdir"/haruna-*.pkg.tar.* | head -1)
pacman -U --noconfirm "$pkgfile"

rm -rf "$workdir"
notify "Haruna repatched" "Patched Haruna $full installed."
echo "haruna-repatch: installed patched haruna $full"
