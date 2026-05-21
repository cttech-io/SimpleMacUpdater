#!/bin/bash
set -euo pipefail

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

print_summary() {
    echo -e "\n${BOLD}────────────────────────────────────────${RESET}"
    echo -e "${BOLD}  Update Summary${RESET}"
    echo -e "${BOLD}────────────────────────────────────────${RESET}"
    for line in "${SUMMARY[@]}"; do
        echo -e "  $line"
    done
    echo -e "${BOLD}────────────────────────────────────────${RESET}\n"
}

# ── Homebrew ─────────────────────────────────────────────────────────────────
if command -v brew &>/dev/null; then
    header "Updating Homebrew packages"
    brew update && brew upgrade
    success "Homebrew packages updated"
    add_summary "${GREEN}✔${RESET}  Homebrew packages updated"

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
    if mas upgrade; then
        success "Mac App Store apps updated"
        add_summary "${GREEN}✔${RESET}  Mac App Store apps updated"
    else
        fail "mas upgrade reported an error"
        add_summary "${RED}✘${RESET}  Mac App Store update failed"
    fi
else
    skip "mas not found — skipping App Store updates (install with: brew install mas)"
fi

# ── macOS software updates ────────────────────────────────────────────────────
header "Checking for macOS updates"
softwareupdate --list 2>&1

echo
read -rp "$(echo -e "${BOLD}Install available macOS updates? [y/N]: ${RESET}")" OS_UPDATE
if [[ "$OS_UPDATE" =~ ^[Yy]$ ]]; then
    echo
    header "Installing macOS updates"
    sudo softwareupdate --install --all
    success "macOS updates installed"
    add_summary "${GREEN}✔${RESET}  macOS updates installed"
else
    skip "macOS updates skipped"
    add_summary "${YELLOW}–${RESET}  macOS updates skipped"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
print_summary
