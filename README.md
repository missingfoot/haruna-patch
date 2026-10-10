# haruna-patch

A mod for [Haruna](https://apps.kde.org/haruna/), KDE's video player, that gives it the mouse and keyboard feel of **mpc-qt / MPC-HC** while keeping everything else Haruna does.

It isn't a fork. Your normal Haruna package is rebuilt with a small patch applied, and a pacman hook rebuilds it again after each official Haruna update, so you keep getting upstream releases with the mod on top.

## What it changes

**Mouse**

| Action | Result |
|---|---|
| Left click | Play / pause, triggered on **release** (like mpc-qt) |
| Left double-click | Toggle fullscreen (unchanged) |
| Left drag | Move the window (when not fullscreen or maximized). Never triggers play / pause |
| Press within 10px of a window edge or corner | Resize the window, with resize cursors on hover |
| Middle click | Mute, triggered on release |
| Middle drag | Pan the video while zoomed in. Never triggers mute |
| Right click | Context menu, which now ends with **Quit** |

**Keyboard**

| Key | Result |
|---|---|
| `1` | **No UI**: hides the menu bar, header, footer and the window's title bar. Video only |
| `2` | **Seek Bar Only**: only the footer (seek bar and controls) |
| `3` | **Full UI**: menu bar, header and footer |
| `=` / `-` | Zoom in / out (stock Haruna uses Ctrl+Plus / Ctrl+Minus) |
| `Ctrl+0` | Reset zoom, which now also re-centres any panning |

More details:

- In fullscreen, moving the mouse to the bottom edge still shows the seek bar in every view mode.
- The view mode is saved and restored next time.
- All of these are normal Haruna actions, so you can rebind them in *Settings → Shortcuts / Mouse*. Contrast up/down and brightness up lost their default `1`/`2`/`3` keys to make room.

## Requirements

- Arch Linux or an Arch-based distro (CachyOS, EndeavourOS, …), since it uses pacman and makepkg
- Haruna installed from the repos, plus the build tools:

  ```sh
  sudo pacman -S --needed haruna base-devel extra-cmake-modules
  ```

Tested with Haruna 1.8.1 on KDE Plasma (Wayland).

## Install

```sh
git clone https://github.com/missingfoot/haruna-patch.git
cd haruna-patch
./patch-reapply.sh
```

It asks for your sudo password, installs the hook, then builds and installs the modded Haruna in the background, which takes a few minutes. You'll get a desktop notification when it's done.

## Scripts

Run these from the repo folder. They call `sudo` themselves when needed.

| Script | What it does |
|---|---|
| `./patch-status.sh` | Shows whether you're running the modded or stock Haruna, whether the update hook is installed, whether the installed patches match this folder, and the last rebuild result |
| `./patch-reapply.sh` | Installs the hook and patches, then rebuilds and installs the modded Haruna. Use it after pulling changes, or whenever stock Haruna is back |
| `./patch-logs.sh` | Follows a rebuild live (Ctrl+C to stop) |
| `./patch-uninstall.sh` | Goes back to stock Haruna for good. It removes the hook and reinstalls the repo package; `./patch-reapply.sh` undoes it |
| `./patch-regenerate.sh` | For development: regenerates the patch files from your local Haruna source branches (see below) |

To check which Haruna you're running: `pacman -Qi haruna | grep Packager` shows `haruna-repatch` for the modded build.

## How it works

Haruna compiles its QML interface into the binary, so the mod can't edit installed files in place. It has to rebuild the package:

1. `/etc/pacman.d/hooks/haruna-repatch.hook` fires whenever pacman installs or upgrades `haruna`.
2. The hook runs `/usr/local/bin/haruna-repatch.sh`. Pacman holds its lock while hooks run, so the script only starts a background systemd unit (`haruna-repatch`) and returns.
3. The unit waits for pacman to finish, then downloads the matching Haruna source release from download.kde.org and checks its sha256.
4. It applies the first patch in `/usr/local/share/haruna-repatch/` that fits that release.
5. It builds a `haruna` package with `makepkg` as your user. The package has the same version and dependencies as the repo one.
6. It installs the package with `pacman -U` and sends a notification.

The modded package is stamped with the packager name `haruna-repatch`, so when the hook fires for that install it sees the package is already modded and does nothing.

Two patches ship in `repatch/`:

- `haruna-1.8.1.patch` is made against the current release.
- `haruna-master.patch` is made against Haruna's development branch, for when the next release catches up with it.

**If an update breaks the patch** (neither one applies), you get a notification and the stock update stays installed and working until the patches are updated. Logs: `journalctl -u haruna-repatch`.

## Development

The patch files are generated from two branches of a [Haruna](https://invent.kde.org/multimedia/haruna) clone that only exist locally. In the maintainer's checkout, this repo is the `main` branch of that clone, and the branches are checked out as git worktrees. Both folders are ignored by this repo:

- `source/`: branch `zoom-pan-and-quit`, based on Haruna master
- `source-1.8.1/`: branch `haruna-1.8.1-patched`, based on the `v1.8.1` tag

To change the mod:

1. Edit and commit in both worktrees.
2. Build to test, e.g. `cmake -B build -G Ninja && cmake --build build && build/bin/haruna`.
3. Run `./patch-regenerate.sh`, which rewrites both patch files and offers to reinstall.

## License

GPL-3.0-or-later, the same as Haruna (see `LICENSE`). Not affiliated with KDE or the Haruna developers.
