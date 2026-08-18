# SimpleUpdater

Single-script maintenance tools that keep a machine's packages, apps, and OS up to date in one run — one script for macOS, one for Linux, sharing a common presentation layer.

Both print a summary at the end showing what changed per category, the time each category took, and the total elapsed time.

```
  ┌─ Summary ──────────────────────────────
  │
  │  ✔  apt-get: 11 package(s) upgraded  (31s)
  │  ✔  snap: 1 refreshed  (12s)
  │  !  Docker: 2 container(s) running (upgrade manually)
  │  !  Reboot required (deferred)
  │
  ├────────────────────────────────────────
  │  Time elapsed  47s
  └────────────────────────────────────────
```

## Usage

Run the same command on every machine — it detects the platform and hands off to the right updater:

```bash
./simple-updater.sh
```

Or call a platform script directly, if you prefer:

```bash
./macos-updater.sh          # macOS
./linux-updater.sh          # Linux
```

All three accept the same flags:

| Flag | Effect |
|------|--------|
| `-n`, `--report` | Report what's available; change nothing |
| `-y`, `--yes` | Don't prompt — apply the safe subset unattended (cron-friendly) |
| `-h`, `--help` | Show help |

## Install

To run it from anywhere without typing a path:

```bash
./install.sh
simple-updater --report
```

This symlinks the entry point into `~/.local/bin` — no `sudo` needed — and, if that directory isn't already on your `PATH`, offers to add it to your shell's rc file. It asks before touching any dotfile, and re-running it changes nothing that's already correct.

| Flag | Effect |
|------|--------|
| `--name NAME` | Install under a different command name (default: `simple-updater`) |
| `--dir DIR` | Link into a different directory (e.g. `/usr/local/bin`, usually needs sudo) |
| `--uninstall` | Remove the link |
| `-y`, `--yes` | Don't prompt before editing the shell rc file |

It knows the right rc file per shell (`.zshrc`, `.bashrc` on Linux, `.bash_profile` on macOS) and prints the native `fish_add_path` command for fish rather than writing POSIX syntax into a fish config. It refuses to overwrite a file it didn't create, only ever removes links pointing back at this repo, and warns if something earlier on your `PATH` already owns the name.

Prefer to do it by hand? `simple-updater.sh` resolves symlinks, so this works too:

```bash
ln -s "$PWD/simple-updater.sh" ~/.local/bin/update
```

## macOS

| Step | Tool | Notes |
|------|------|-------|
| Update & upgrade packages | [Homebrew](https://brew.sh) | Skipped if not installed |
| Clean up package cache | Homebrew | Removes stale downloads |
| Update cheat-sheet cache | [tldr](https://tldr.sh) | Skipped if not installed |
| Update App Store apps | [mas](https://github.com/mas-cli/mas) | Skipped if not installed |
| Check & install macOS updates | `softwareupdate` | Prompts before installing |

Optional dependencies — the script detects them automatically, install only what you use:

```bash
brew install mas   # Mac App Store CLI
brew install tldr  # Community man-page summaries
```

## Linux

The package manager is **detected, not assumed**. The first of `apt-get`, `dnf`, `yum`, `pacman`, `zypper`, `apk` found on the host is used, and every other step is skipped unless the relevant tool is present.

| Step | Tool | Behaviour |
|------|------|-----------|
| Native packages | detected manager | Refresh, list pending, upgrade, clean cache |
| Orphaned packages | `apt-get autoremove` | **Prompt only** — lists candidates first, never runs under `--yes` |
| Snap packages | `snap` | Refreshed if any are pending |
| Flatpaks | `flatpak` | Updated if any are pending |
| Firmware | `fwupdmgr` | **Reported only** — applying needs an explicit yes |
| Docker containers | `docker` | **Reported only**, never pulled — see below |
| Pi-hole | `pihole` | Gravity/blocklists updated; version upgrade is prompt-only |
| Reboot required | `/var/run/reboot-required`, `needs-restarting`, kernel comparison | Reported, with the packages that caused it |

Tested against Debian 12, Ubuntu 24.04 (x86_64 and aarch64), and Fedora.

### What it deliberately won't do unattended

`--yes` applies the *safe subset* only. These stay behind a human decision even with `--yes`, because getting them wrong on a remote machine is expensive:

- **Docker images are never pulled.** A `pull` on a `:latest` tag can jump a major version with breaking schema or config changes. The script lists what's running so you can read the release notes and decide.
- **Firmware is never flashed unattended.** A bad flash isn't recoverable over SSH.
- **`autoremove` is never run unattended.** It has a habit of taking libraries that AppImages and other non-packaged software still depend on. The script prints the candidate list so you can read it first.
- **Reboots are never automatic.** Reported, with the packages that triggered them.
- **Pi-hole version upgrades are prompt-only.** Blocklist (gravity) refreshes are routine and included.

On Debian/Ubuntu, `--yes` also keeps existing config files rather than stopping on a conffile prompt, and sets `needrestart` to *list* affected services rather than silently restarting them.

### Unattended use

`--yes` needs passwordless sudo (or root) — it exits with a clear message rather than hanging on a password prompt with no terminal. Colour is disabled automatically when output isn't a terminal, so cron mail and log files stay readable.

```cron
0 4 * * 0  /path/to/linux-updater.sh --yes >> /var/log/simpleupdater.log 2>&1
```

## Layout

```
install.sh           # optional — puts the entry point on your PATH
simple-updater.sh    # entry point — detects the platform, delegates
lib/ui.sh            # colours, banner, summary, timing, prompts — shared
macos-updater.sh     # Homebrew, tldr, mas, softwareupdate
linux-updater.sh     # native packages, snap, flatpak, fwupd, reports
```

`lib/ui.sh` is sourced, not executed, and is kept compatible with bash 3.2 (the version macOS ships). The scripts locate each other relative to their own path, so keep the layout intact — copy the directory, not individual files.

## Requirements

- **macOS:** bash 3.2+ (system bash is fine). Homebrew recommended but not required.
- **Linux:** bash 4+, and one of the supported package managers. `sudo` unless running as root.

## Licence

[MIT](LICENSE)
