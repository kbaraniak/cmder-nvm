#!/usr/bin/env sh
# ============================================================================
#  cmder-nvm - OOBE entry point
#
#  Single cross-platform entry point for the out-of-box setup flow.
#
#    Windows / Cmder  : delegates to install.cmd (unchanged native flow)
#    Linux            : runs the POSIX flow (installs nvm-sh, then Node.js)
#    anything else    : prints a clear, actionable error
#
#  Usage:
#    ./oobe.sh                 interactive version menu
#    ./oobe.sh 20              install a specific version non-interactively
#    ./oobe.sh --check         run the checks and the install, then stop
#    CMDER_NVM_VERSION=20 ./oobe.sh
# ============================================================================

CMDER_NVM_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export CMDER_NVM_ROOT

OOBE_LIB="$CMDER_NVM_ROOT/lib/oobe"
. "$OOBE_LIB/detect.sh"
. "$OOBE_LIB/download.sh"
. "$OOBE_LIB/linux.sh"

# Versions offered by the menu, mirroring install.cmd.
OOBE_MENU_VERSIONS="16 18 19 20 21 lts latest"

usage() {
    cat <<EOF
cmder-nvm setup

Usage:
    oobe.sh [options] [version]

Options:
    -h, --help      show this help
    -c, --check     verify dependencies and exit without installing Node.js
    -q, --quiet     suppress progress output
    -n, --no-menu   never prompt; requires a version argument

Arguments:
    version         Node.js version to install, e.g. 20, 18.20.4, lts, latest

Examples:
    ./oobe.sh              install a version chosen from the menu
    ./oobe.sh 20           install Node.js 20
    ./oobe.sh --check      only verify the system
EOF
}

# Print the same menu the Windows bootstrap shows.
menu() {
    oobe_log "NodeJS: Select the node version to install:"
    oobe_log "  1) 16   2) 18 (LTS)   3) 19"
    oobe_log "  4) 20 (LTS)   5) 21   6) latest LTS   7) latest"
    oobe_log "  0) exit"
    printf 'Option > '

    read -r _choice || _choice=""
    case "$_choice" in
        1) printf '16\n' ;;
        2) printf '18\n' ;;
        3) printf '19\n' ;;
        4) printf '20\n' ;;
        5) printf '21\n' ;;
        6) printf 'lts\n' ;;
        7) printf 'latest\n' ;;
        *) printf '\n' ;;
    esac
}

# Ask for a version: CLI argument, then environment, then the interactive menu.
resolve_version() {
    if [ -n "${1:-}" ]; then
        printf '%s\n' "$1"
        return 0
    fi
    if [ -n "${CMDER_NVM_VERSION:-}" ]; then
        printf '%s\n' "$CMDER_NVM_VERSION"
        return 0
    fi
    menu
}

# The Windows path stays byte-for-byte identical to the existing behaviour:
# install.cmd is invoked directly and owns the whole flow.
run_windows() {
    oobe_log "cmder-nvm: detected Windows, using the native installer."
    oobe_log ""

    if [ -f "$CMDER_NVM_ROOT/install.cmd" ]; then
        if oobe_have cmd.exe; then
            cmd.exe /c "cd /d \"$CMDER_NVM_ROOT\" && install.cmd"
        else
            oobe_warn "cmd.exe is not on PATH; run install.cmd from Cmder instead."
            return 1
        fi
    else
        oobe_error "install.cmd not found in $CMDER_NVM_ROOT"
        return 1
    fi
}

run_linux() {
    oobe_linux_check_prereqs      || return 1
    oobe_linux_install_nvm        || return 1
    oobe_linux_write_env          || return 1

    if [ "${1:-}" = "check-only" ]; then
        oobe_step "Checks passed, stopping before the Node.js install as requested"
        return 0
    fi

    _version=$(resolve_version "${2:-}")
    if [ -z "$_version" ]; then
        oobe_linux_summary
        return 0
    fi

    oobe_linux_install_node "$_version" || return 1
    oobe_linux_summary
    return 0
}

main() {
    _mode=""
    _version=""
    _no_menu=0

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)    usage; return 0 ;;
            -c|--check)   _mode="check-only"; shift ;;
            -q|--quiet)   CMDER_NVM_QUIET=1; export CMDER_NVM_QUIET; shift ;;
            -n|--no-menu) _no_menu=1; shift ;;
            -*)           oobe_error "unknown option: $1"; usage; return 2 ;;
            *)            _version=$1; shift ;;
        esac
    done

    if [ "$_no_menu" = "1" ] && [ -z "$_version" ] && [ -z "${CMDER_NVM_VERSION:-}" ]; then
        oobe_error "--no-menu requires a version argument"
        return 2
    fi

    oobe_log "cmder-nvm setup"
    _os=$(oobe_os)

    case "$_os" in
        windows) run_windows ;;
        linux)   run_linux "$_mode" "$_version" ;;
        macos)   oobe_error "macOS is not supported by this flow; use the Windows installer or install nvm-sh manually."; return 1 ;;
        *)       oobe_error "unsupported platform: $(uname -s 2>/dev/null || echo unknown)"; return 1 ;;
    esac
}

main "$@"
