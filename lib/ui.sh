# shellcheck shell=bash
# Shared presentation layer for the SimpleUpdater scripts.
# Source this, don't execute it:  source "$(dirname "$0")/lib/ui.sh"
#
# Kept compatible with bash 3.2 (macOS ships it) — no associative arrays,
# no ${var,,}, no mapfile.

# ── Colours ──────────────────────────────────────────────────────────────────
# Disabled when stdout isn't a terminal, so piped/cron output stays readable.
if [[ -t 1 && "${TERM:-dumb}" != "dumb" && -z "${NO_COLOR:-}" ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    RED='\033[0;31m'
    RESET='\033[0m'
else
    BOLD='' DIM='' GREEN='' YELLOW='' CYAN='' RED='' RESET=''
fi

# ── Timing ───────────────────────────────────────────────────────────────────
START_TIME=$SECONDS

format_duration() {
    local secs=$1
    if (( secs < 60 )); then
        echo "${secs}s"
    else
        printf "%dm %ds" "$(( secs / 60 ))" "$(( secs % 60 ))"
    fi
}

section_time() { format_duration "$(( SECONDS - $1 ))"; }

# ── Output helpers ───────────────────────────────────────────────────────────
banner() {
    local title="$1" subtitle="${2:-}" dt
    dt=$(date '+%a %d %b %Y  ·  %H:%M')
    echo -e "\n${BOLD}${CYAN}  ${title}${RESET}"
    [[ -n "$subtitle" ]] && echo -e "  ${DIM}${subtitle}${RESET}"
    echo -e "  ${DIM}${dt}${RESET}"
    echo -e "${CYAN}  ────────────────────────────────────────${RESET}"
}

header()  { echo -e "\n${BOLD}${CYAN}  ▸ $*${RESET}"; }
success() { echo -e "  ${GREEN}✔${RESET}  $*"; }
skip()    { echo -e "  ${YELLOW}–${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  $*"; }
fail()    { echo -e "  ${RED}✘${RESET}  $*"; }
note()    { echo -e "  ${DIM}$*${RESET}"; }

# ── Summary tracking ─────────────────────────────────────────────────────────
SUMMARY=()
add_summary() { SUMMARY+=("$1"); }

sum_ok()   { add_summary "${GREEN}✔${RESET}  $1"; }
sum_skip() { add_summary "${YELLOW}–${RESET}  $1"; }
sum_warn() { add_summary "${YELLOW}!${RESET}  $1"; }
sum_fail() { add_summary "${RED}✘${RESET}  $1"; }

# Count non-blank lines; tolerant of empty input.
count_lines() {
    [[ -z "$1" ]] && { echo 0; return; }
    echo "$1" | grep -c . || true
}

# Safe to call more than once — only the first call prints. That lets scripts
# trap this on EXIT as a safety net without double-printing when they also call
# it on the normal path.
SUMMARY_PRINTED=0

print_summary() {
    local elapsed duration line
    (( SUMMARY_PRINTED )) && return 0
    SUMMARY_PRINTED=1
    elapsed=$(( SECONDS - START_TIME ))
    duration=$(format_duration "$elapsed")

    echo -e "\n${BOLD}${CYAN}  ┌─ Summary ──────────────────────────────${RESET}"
    echo -e "${CYAN}  │${RESET}"
    for line in "${SUMMARY[@]}"; do
        echo -e "${CYAN}  │${RESET}  ${line}"
    done
    echo -e "${CYAN}  │${RESET}"
    echo -e "${BOLD}${CYAN}  ├────────────────────────────────────────${RESET}"
    echo -e "${CYAN}  │${RESET}  ${DIM}Time elapsed${RESET}  ${BOLD}${duration}${RESET}"
    echo -e "${BOLD}${CYAN}  └────────────────────────────────────────${RESET}\n"
}

# ── Prompting ────────────────────────────────────────────────────────────────
# confirm "Question?" → 0 if yes.
# Honours ASSUME_YES (--yes) and refuses to hang when there's no terminal.
confirm() {
    local prompt="$1" reply
    if [[ "${ASSUME_YES:-0}" == "1" ]]; then
        echo -e "  ${DIM}${prompt} → yes (--yes)${RESET}"
        return 0
    fi
    if [[ ! -t 0 ]]; then
        echo -e "  ${DIM}${prompt} → no (not a terminal)${RESET}"
        return 1
    fi
    read -rp "$(echo -e "${BOLD}  ${prompt} [y/N]: ${RESET}")" reply
    [[ "$reply" =~ ^[Yy]$ ]]
}
