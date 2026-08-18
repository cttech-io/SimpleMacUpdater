#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"

# ── Options ──────────────────────────────────────────────────────────────────
ASSUME_YES=0
REPORT_ONLY=0

usage() {
    cat <<EOF
Usage: ${0##*/} [options]

  -y, --yes       Answer yes to prompts (installs macOS updates unattended)
  -n, --report    Report what's available; change nothing
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)    ASSUME_YES=1 ;;
        -n|--report) REPORT_ONLY=1 ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
    fail "This is the macOS updater — on Linux run linux-updater.sh instead."
    exit 1
fi

banner "macOS Updater" "$(sw_vers -productName) $(sw_vers -productVersion) · $(uname -m)"
(( REPORT_ONLY )) && note "  Report-only mode — nothing will be changed."

# ── Homebrew ─────────────────────────────────────────────────────────────────
if command -v brew &>/dev/null; then
    T=$SECONDS

    header "Updating Homebrew package list"
    brew update

    BREW_OUTDATED=$(brew outdated --quiet 2>/dev/null || true)
    BREW_COUNT=$(count_lines "$BREW_OUTDATED")

    if (( REPORT_ONLY )); then
        if (( BREW_COUNT > 0 )); then
            echo "$BREW_OUTDATED" | sed 's/^/    /'
            sum_warn "Homebrew: ${BOLD}${BREW_COUNT}${RESET} package(s) outdated  ${DIM}($(section_time $T))${RESET}"
        else
            sum_ok "Homebrew: already up to date  ${DIM}($(section_time $T))${RESET}"
        fi
    else
        header "Upgrading Homebrew packages"
        brew upgrade
        success "Homebrew packages upgraded"

        header "Cleaning up Homebrew cache"
        brew cleanup
        success "Homebrew cache cleaned"

        BREW_TIME=$(section_time $T)
        if (( BREW_COUNT > 0 )); then
            sum_ok "Homebrew: ${BOLD}${BREW_COUNT}${RESET} package(s) upgraded  ${DIM}(${BREW_TIME})${RESET}"
        else
            sum_ok "Homebrew: already up to date  ${DIM}(${BREW_TIME})${RESET}"
        fi
        sum_ok "Homebrew cache cleaned"
    fi
else
    skip "Homebrew not found — skipping"
    sum_skip "Homebrew not installed"
fi

# ── tldr ─────────────────────────────────────────────────────────────────────
if command -v tldr &>/dev/null && (( ! REPORT_ONLY )); then
    T=$SECONDS
    header "Updating tldr cache"
    tldr -u
    success "tldr cache updated"
    sum_ok "tldr cache updated  ${DIM}($(section_time $T))${RESET}"
elif ! command -v tldr &>/dev/null; then
    skip "tldr not found — skipping"
fi

# ── Mac App Store (mas) ──────────────────────────────────────────────────────
if command -v mas &>/dev/null; then
    T=$SECONDS
    header "Checking Mac App Store apps"

    MAS_OUTDATED=$(mas outdated 2>/dev/null || true)
    MAS_COUNT=$(count_lines "$MAS_OUTDATED")
    [[ -n "$MAS_OUTDATED" ]] && echo "$MAS_OUTDATED" | sed 's/^/    /'

    if (( REPORT_ONLY )); then
        if (( MAS_COUNT > 0 )); then
            sum_warn "Mac App Store: ${BOLD}${MAS_COUNT}${RESET} app(s) outdated  ${DIM}($(section_time $T))${RESET}"
        else
            sum_ok "Mac App Store: already up to date  ${DIM}($(section_time $T))${RESET}"
        fi
    elif mas upgrade; then
        success "Mac App Store apps updated"
        MAS_TIME=$(section_time $T)
        if (( MAS_COUNT > 0 )); then
            sum_ok "Mac App Store: ${BOLD}${MAS_COUNT}${RESET} app(s) updated  ${DIM}(${MAS_TIME})${RESET}"
        else
            sum_ok "Mac App Store: already up to date  ${DIM}(${MAS_TIME})${RESET}"
        fi
    else
        fail "mas upgrade reported an error"
        sum_fail "Mac App Store update failed  ${DIM}($(section_time $T))${RESET}"
    fi
else
    skip "mas not found — skipping App Store updates (install with: brew install mas)"
fi

# ── macOS software updates ───────────────────────────────────────────────────
T=$SECONDS
header "Checking for macOS updates"
MACOS_LIST=$(softwareupdate --list 2>&1)
echo "$MACOS_LIST"
MACOS_COUNT=$(echo "$MACOS_LIST" | grep -cE '^\* ' || true)

if (( MACOS_COUNT == 0 )); then
    skip "No macOS updates available"
    sum_skip "macOS: no updates available  ${DIM}($(section_time $T))${RESET}"
elif (( REPORT_ONLY )); then
    sum_warn "macOS: ${BOLD}${MACOS_COUNT}${RESET} update(s) available  ${DIM}($(section_time $T))${RESET}"
else
    echo
    if confirm "Install available macOS updates?"; then
        echo
        header "Installing macOS updates"
        sudo softwareupdate --install --all
        success "macOS updates installed"
        sum_ok "macOS: ${BOLD}${MACOS_COUNT}${RESET} update(s) installed  ${DIM}($(section_time $T))${RESET}"
    else
        skip "macOS updates skipped"
        sum_skip "macOS: ${BOLD}${MACOS_COUNT}${RESET} update(s) available (skipped)  ${DIM}($(section_time $T))${RESET}"
    fi
fi

# ── Done ─────────────────────────────────────────────────────────────────────
print_summary
