#!/usr/bin/env bash
set -euo pipefail

# Puts simple-updater.sh on your PATH by symlinking it into a bin directory.
# Only the entry point is linked — it finds lib/ and the platform scripts by
# resolving its own symlink, so the repo can live anywhere.

SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
    LINK_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$LINK_DIR/$SOURCE"
done
REPO_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

# shellcheck source=lib/ui.sh
source "$REPO_DIR/lib/ui.sh"

# ── Options ──────────────────────────────────────────────────────────────────
LINK_NAME="simple-updater"
TARGET_DIR=""
ASSUME_YES=0
UNINSTALL=0

usage() {
    cat <<EOF
Usage: ${0##*/} [options]

  --name NAME     Command name to install as (default: simple-updater)
  --dir DIR       Bin directory to link into (default: ~/.local/bin)
  --uninstall     Remove a previously installed link
  -y, --yes       Don't prompt; update the shell rc file if needed
  -h, --help      Show this help

Installs to ~/.local/bin, so no sudo is required. Pass --dir /usr/local/bin
for a system-wide install (that directory usually needs sudo).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)      LINK_NAME="${2:?--name needs a value}"; shift ;;
        --dir)       TARGET_DIR="${2:?--dir needs a value}"; shift ;;
        --uninstall) UNINSTALL=1 ;;
        -y|--yes)    ASSUME_YES=1 ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

ENTRY="$REPO_DIR/simple-updater.sh"
[[ -n "$TARGET_DIR" ]] || TARGET_DIR="$HOME/.local/bin"
# Expand a leading ~ so --dir '~/bin' behaves as expected.
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
# A relative --dir would produce a symlink that only resolves from the
# directory you happened to run this from.
[[ "$TARGET_DIR" == /* ]] || TARGET_DIR="$PWD/$TARGET_DIR"
LINK_PATH="$TARGET_DIR/$LINK_NAME"

banner "SimpleUpdater Installer" "$REPO_DIR"

# ── Uninstall ────────────────────────────────────────────────────────────────
if (( UNINSTALL )); then
    if [[ -L "$LINK_PATH" ]]; then
        # Only remove links that point back at this repo — never someone
        # else's binary that happens to share the name.
        if [[ "$(readlink "$LINK_PATH")" == "$ENTRY" ]]; then
            rm "$LINK_PATH"
            success "Removed $LINK_PATH"
        else
            fail "$LINK_PATH doesn't point at this repo — leaving it alone"
            note "It links to: $(readlink "$LINK_PATH")"
            exit 1
        fi
    elif [[ -e "$LINK_PATH" ]]; then
        fail "$LINK_PATH exists but isn't a symlink — leaving it alone"
        exit 1
    else
        skip "Nothing installed at $LINK_PATH"
    fi
    note "Any PATH line added to your shell rc was left in place."
    echo
    exit 0
fi

# ── Sanity checks ────────────────────────────────────────────────────────────
if [[ ! -f "$ENTRY" ]]; then
    fail "simple-updater.sh not found in $REPO_DIR"
    exit 1
fi
[[ -x "$ENTRY" ]] || chmod +x "$ENTRY"

# ── Create the bin directory ─────────────────────────────────────────────────
if [[ ! -d "$TARGET_DIR" ]]; then
    header "Creating $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
    success "Created"
fi

if [[ ! -w "$TARGET_DIR" ]]; then
    fail "$TARGET_DIR isn't writable by $(whoami)"
    note "Re-run with sudo, or choose a different --dir."
    exit 1
fi

# ── Link ─────────────────────────────────────────────────────────────────────
header "Linking $LINK_NAME → simple-updater.sh"

if [[ -L "$LINK_PATH" && "$(readlink "$LINK_PATH")" == "$ENTRY" ]]; then
    success "Already linked (nothing to do)"
elif [[ -e "$LINK_PATH" || -L "$LINK_PATH" ]]; then
    # Something else owns this name. Say what it is and stop rather than
    # clobbering it.
    fail "$LINK_PATH already exists and isn't ours"
    if [[ -L "$LINK_PATH" ]]; then
        note "It links to: $(readlink "$LINK_PATH")"
    fi
    note "Pick another name with --name, or remove it yourself first."
    exit 1
else
    ln -s "$ENTRY" "$LINK_PATH"
    success "Linked $LINK_PATH"
fi

# ── Make sure the directory is actually on PATH ──────────────────────────────
on_path() {
    case ":${PATH}:" in
        *":$1:"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Which rc file does this user's shell read for interactive sessions?
rc_file_for_shell() {
    local sh
    sh="$(basename "${SHELL:-}")"
    case "$sh" in
        zsh)  echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
        bash) # macOS Terminal starts login shells, which read .bash_profile;
              # most Linux terminals start non-login shells, which read .bashrc.
              if [[ "$(uname -s)" == "Darwin" ]]; then echo "$HOME/.bash_profile"
              else echo "$HOME/.bashrc"; fi ;;
        fish) echo "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish" ;;
        *)    echo "" ;;
    esac
}

MARKER="# added by SimpleUpdater"

if on_path "$TARGET_DIR"; then
    success "$TARGET_DIR is already on your PATH"
else
    header "$TARGET_DIR is not on your PATH"
    RC="$(rc_file_for_shell)"
    SHELL_NAME="$(basename "${SHELL:-unknown}")"

    if [[ "$SHELL_NAME" == "fish" ]]; then
        # fish doesn't use POSIX export syntax; give the native command
        # instead of writing something that would break the config.
        warn "fish detected — add it with:"
        note "  fish_add_path $TARGET_DIR"
    elif [[ -z "$RC" ]]; then
        warn "Unrecognised shell '$SHELL_NAME' — add this line yourself:"
        note "  export PATH=\"$TARGET_DIR:\$PATH\""
    elif grep -qF "$MARKER" "$RC" 2>/dev/null; then
        success "$RC already has a SimpleUpdater PATH entry"
        note "Open a new shell (or: source $RC) to pick it up."
    else
        note "This would append to $RC:"
        note "  export PATH=\"$TARGET_DIR:\$PATH\"  $MARKER"
        if confirm "Add it?"; then
            printf '\n%s\nexport PATH="%s:$PATH"\n' "$MARKER" "$TARGET_DIR" >> "$RC"
            success "Updated $RC"
            note "Open a new shell (or: source $RC) to pick it up."
        else
            skip "Left $RC alone — add the line above yourself when ready"
        fi
    fi
fi

# ── Shadow check ─────────────────────────────────────────────────────────────
# Being on PATH isn't enough — an earlier PATH entry with the same name wins,
# and you'd run that instead without any indication why.
if on_path "$TARGET_DIR"; then
    RESOLVED="$(command -v "$LINK_NAME" 2>/dev/null || true)"
    if [[ -n "$RESOLVED" && "$RESOLVED" != "$LINK_PATH" ]]; then
        header "Name clash"
        warn "'$LINK_NAME' on your PATH resolves to $RESOLVED"
        note "  That comes earlier in PATH than $TARGET_DIR, so it wins."
        note "  Reinstall under a different name: --name <something-else>"
    fi
fi

# ── Report ───────────────────────────────────────────────────────────────────
header "Done"
if on_path "$TARGET_DIR"; then
    success "Run it from anywhere:  ${BOLD}${LINK_NAME} --report${RESET}"
else
    success "Once your PATH is updated:  ${BOLD}${LINK_NAME} --report${RESET}"
    note "Until then, the full path works: $LINK_PATH --report"
fi
echo
