#!/bin/bash
set -euo pipefail

# ── Timing ───────────────────────────────────────────────────────────────────
START_TIME=$SECONDS

# ── Colours ──────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

header()  { echo -e "\n${BOLD}${CYAN}==> $*${RESET}"; }
success() { echo -e "${GREEN}✔  $*${RESET}"; }
skip()    { echo -e "${YELLOW}–  $*${RESET}"; }
fail()    { echo -e "${RED}✘  $*${RESET}"; }

# ── Summary tracking ─────────────────────────────────────────────────────────
SUMMARY=()
add_summary() { SUMMARY+=("$1"); }

count_lines() { echo "$1" | grep -c . || true; }

format_duration() {
    local secs=$1
    if (( secs < 60 )); then
        echo "${secs}s"
    else
        printf "%dm %ds" "$(( secs / 60 ))" "$(( secs % 60 ))"
    fi
}

print_summary() {
    local elapsed duration
    elapsed=$(( SECONDS - START_TIME ))
    duration=$(format_duration "$elapsed")

    echo -e "\n${BOLD}────────────────────────────────────────${RESET}"
    echo -e "${BOLD}  Update Summary${RESET}"
    echo -e "${BOLD}────────────────────────────────────────${RESET}"
    for line in "${SUMMARY[@]}"; do
        echo -e "  $line"
    done
    echo -e "${BOLD}────────────────────────────────────────${RESET}"
    echo -e "  ${BOLD}Time elapsed:${RESET} ${duration}"
    echo -e "${BOLD}────────────────────────────────────────${RESET}\n"
}

# ── Homebrew ─────────────────────────────────────────────────────────────────
if command -v brew &>/dev/null; then
    header "Updating Homebrew package list"
    brew update

    BREW_OUTDATED=$(brew outdated --quiet 2>/dev/null || true)
    BREW_COUNT=$(count_lines "$BREW_OUTDATED")

    header "Upgrading Homebrew packages"
    brew upgrade
    success "Homebrew packages upgraded"

    if (( BREW_COUNT > 0 )); then
        add_summary "${GREEN}✔${RESET}  Homebrew: ${BOLD}${BREW_COUNT}${RESET} package(s) upgraded"
    else
        add_summary "${GREEN}✔${RESET}  Homebrew: already up to date"
    fi

    header "Cleaning up Homebrew cache"
    brew cleanup
    success "Homebrew cache cleaned"
    add_summary "${GREEN}✔${RESET}  Homebrew cache cleaned"
else
    skip "Homebrew not found — skipping"
    add_summary "${YELLOW}–${RESET}  Homebrew not installed"
fi

# ── tldr ─────────────────────────────────────────────────────────────────────
if command -v tldr &>/dev/null; then
    header "Updating tldr cache"
    tldr -u
    success "tldr cache updated"
    add_summary "${GREEN}✔${RESET}  tldr cache updated"
else
    skip "tldr not found — skipping"
fi

# ── Mac App Store (mas) ───────────────────────────────────────────────────────
if command -v mas &>/dev/null; then
    header "Updating Mac App Store apps"

    MAS_OUTDATED=$(mas outdated 2>/dev/null || true)
    MAS_COUNT=$(count_lines "$MAS_OUTDATED")

    if mas upgrade; then
        success "Mac App Store apps updated"
        if (( MAS_COUNT > 0 )); then
            add_summary "${GREEN}✔${RESET}  Mac App Store: ${BOLD}${MAS_COUNT}${RESET} app(s) updated"
        else
            add_summary "${GREEN}✔${RESET}  Mac App Store: already up to date"
        fi
    else
        fail "mas upgrade reported an error"
        add_summary "${RED}✘${RESET}  Mac App Store update failed"
    fi
else
    skip "mas not found — skipping App Store updates (install with: brew install mas)"
fi

# ── macOS software updates ────────────────────────────────────────────────────
header "Checking for macOS updates"
MACOS_LIST=$(softwareupdate --list 2>&1)
echo "$MACOS_LIST"
MACOS_COUNT=$(echo "$MACOS_LIST" | grep -cE '^\* ' || true)

if (( MACOS_COUNT == 0 )); then
    skip "No macOS updates available"
    add_summary "${YELLOW}–${RESET}  macOS: no updates available"
else
    echo
    read -rp "$(echo -e "${BOLD}Install available macOS updates? [y/N]: ${RESET}")" OS_UPDATE
    if [[ "$OS_UPDATE" =~ ^[Yy]$ ]]; then
        echo
        header "Installing macOS updates"
        sudo softwareupdate --install --all
        success "macOS updates installed"
        add_summary "${GREEN}✔${RESET}  macOS: ${BOLD}${MACOS_COUNT}${RESET} update(s) installed"
    else
        skip "macOS updates skipped"
        add_summary "${YELLOW}–${RESET}  macOS: ${BOLD}${MACOS_COUNT}${RESET} update(s) available (skipped)"
    fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
print_summary
