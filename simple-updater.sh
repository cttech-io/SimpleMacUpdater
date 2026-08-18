#!/usr/bin/env bash
set -euo pipefail

# Entry point: works out which platform this is and hands off to the matching
# updater, passing every argument straight through. Run this one everywhere and
# you never have to remember which script a given machine needs.

# Resolve symlinks so this stays correct when linked onto PATH — the platform
# scripts live next to the *real* file, not next to the link. `readlink -f`
# isn't portable to macOS, so walk the chain by hand.
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
    LINK_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$LINK_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

OS="$(uname -s)"
case "$OS" in
    Darwin) TARGET="macos-updater.sh" ;;
    Linux)  TARGET="linux-updater.sh" ;;
    *)
        echo "simple-updater: unsupported platform '$OS'" >&2
        echo "Supported: Darwin (macOS), Linux." >&2
        exit 1
        ;;
esac

TARGET_PATH="$SCRIPT_DIR/$TARGET"

if [[ ! -f "$TARGET_PATH" ]]; then
    echo "simple-updater: $TARGET not found in $SCRIPT_DIR" >&2
    echo "Copy the whole repo, not just this script — it needs its siblings" >&2
    echo "and lib/ui.sh." >&2
    exit 1
fi

# Mention the hand-off on --help, otherwise the delegated usage text naming a
# different script is just confusing.
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        echo "simple-updater.sh — runs the right updater for this machine."
        echo "Detected ${OS}, delegating to ${TARGET}:"
        echo
        break
    fi
done

# exec so signals and the exit status belong to the real updater.
if [[ -x "$TARGET_PATH" ]]; then
    exec "$TARGET_PATH" "$@"
else
    exec bash "$TARGET_PATH" "$@"
fi
