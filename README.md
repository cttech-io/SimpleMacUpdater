# SimpleMacUpdater

A single-script macOS maintenance tool that keeps your packages, apps, and OS up to date in one run.

## What it does

| Step | Tool | Notes |
|------|------|-------|
| Update & upgrade packages | [Homebrew](https://brew.sh) | Skipped if not installed |
| Clean up package cache | Homebrew | Removes stale downloads |
| Update cheat-sheet cache | [tldr](https://tldr.sh) | Skipped if not installed |
| Update App Store apps | [mas](https://github.com/mas-cli/mas) | Skipped if not installed |
| Check & install macOS updates | `softwareupdate` | Prompts before installing — only if updates are found |

The summary printed at the end of each run shows the number of packages/apps updated per category, the time taken per category, and the total elapsed time.

## Usage

```bash
chmod +x macOS-Updater.sh
./macOS-Updater.sh
```

## Optional dependencies

The script detects these tools automatically — install only what you use:

```bash
brew install mas   # Mac App Store CLI
brew install tldr  # Community man-page summaries
```

## Requirements

- macOS
- [Homebrew](https://brew.sh) (recommended, but the script will run without it)
