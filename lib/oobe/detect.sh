#!/usr/bin/env sh
# ============================================================================
#  cmder-nvm - platform detection
#
#  Sourced by the OOBE scripts. Provides OS / architecture / distro detection
#  so the rest of the code never has to poke at `uname` directly.
#
#  Written for POSIX sh: no bashisms, no arrays, no `local`-free assumptions
#  beyond what dash/ash/bash all provide.
# ============================================================================

# Guard against double-sourcing (oobe.sh may be reached through several paths).
if [ -n "${CMDER_NVM_DETECT_SOURCED:-}" ]; then
    return 0 2>/dev/null || true
fi
CMDER_NVM_DETECT_SOURCED=1

# ---------------------------------------------------------------------------
# Logging helpers. Everything user facing goes through these so the output
# stays consistent and can be silenced with CMDER_NVM_QUIET=1.
# ---------------------------------------------------------------------------
oobe_log() {
    [ "${CMDER_NVM_QUIET:-0}" = "1" ] && return 0
    printf '%s\n' "$*"
}

oobe_step() {
    oobe_log ""
    oobe_log "==> $*"
}

oobe_ok() {
    oobe_log "    [ok]      $*"
}

oobe_info() {
    oobe_log "    [info]    $*"
}

oobe_warn() {
    oobe_log "    [warn]    $*" >&2
}

oobe_error() {
    printf '%s\n' "    [error]   $*" >&2
}

# ---------------------------------------------------------------------------
# oobe_have <command>
#
# True when <command> is callable. Uses `command -v` rather than a plain
# `which`, which is not POSIX and varies wildly between distros.
# ---------------------------------------------------------------------------
oobe_have() {
    command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# oobe_os
#
# Prints one of: linux, macos, windows, unsupported
#
# Windows is reported for the POSIX environments Cmder is usually launched
# from (MSYS2, Cygwin, Git Bash, WSL-less emulations) so the caller can hand
# control back to the native .cmd bootstrap.
# ---------------------------------------------------------------------------
oobe_os() {
    _os=$(uname -s 2>/dev/null || printf 'unknown')

    case "$_os" in
        Linux*)                printf 'linux\n' ;;
        Darwin*)               printf 'macos\n' ;;
        MINGW*|MSYS*|CYGWIN*|Windows_NT*) printf 'windows\n' ;;
        *)                     printf 'unsupported\n' ;;
    esac
}

# ---------------------------------------------------------------------------
# oobe_arch
#
# Prints the machine architecture as reported by `uname -m`.
# ---------------------------------------------------------------------------
oobe_arch() {
    uname -m 2>/dev/null || printf 'unknown\n'
}

# ---------------------------------------------------------------------------
# oobe_distro
#
# Prints an identifier for the Linux distribution, derived from the fields
# the various /etc/*-release files agree on: debian, ubuntu, fedora, rhel,
# centos, arch, opensuse, alpine, suse, or generic when unrecognised.
# ---------------------------------------------------------------------------
oobe_distro() {
    _id=""
    _id_like=""

    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release 2>/dev/null || true
        _id="${ID:-}"
        _id_like="${ID_LIKE:-}"
    else
        for _f in /etc/os-release /etc/lsb-release /etc/*-release; do
            [ -r "$_f" ] || continue
            _id=$(sed -n 's/^ID=//p' "$_f" | tr -d '"' | head -n 1)
            [ -n "$_id" ] && break
        done
    fi

    _haystack="$_id $_id_like"

    case "$_haystack" in
        *ubuntu*)         printf 'ubuntu\n' ;;
        *debian*)         printf 'debian\n' ;;
        *fedora*)         printf 'fedora\n' ;;
        *rhel*|*centos*)  printf 'rhel\n' ;;
        *arch*|*manjaro*) printf 'arch\n' ;;
        *opensuse*|*suse*) printf 'suse\n' ;;
        *alpine*)         printf 'alpine\n' ;;
        *)                printf 'generic\n' ;;
    esac
}

# ---------------------------------------------------------------------------
# oobe_pkg_manager
#
# Prints the package manager to use for this distro, or "none" when no
# supported manager was found. Debian/Ubuntu, Fedora, RHEL/CentOS, Arch and
# openSUSE are covered, which is the practical common denominator.
# ---------------------------------------------------------------------------
oobe_pkg_manager() {
    _pm=$(oobe_distro)

    # The rhel branch is spelled out rather than written as
    # `oobe_have dnf && printf dnf || oobe_have yum && ...`: chained
    # `&&`/`||` binds left to right, so that form falls through to the yum
    # test even when dnf already answered, printing both names. RHEL 8 and 9
    # ship dnf and yum together, so that is the common case, not the exotic
    # one. It also printed "dnf" followed by "none" on a dnf-only system,
    # because the `||` bound to the second test instead of the first.
    case "$_pm" in
        debian|ubuntu) oobe_have apt-get && printf 'apt-get\n' || printf 'none\n' ;;
        fedora)        oobe_have dnf     && printf 'dnf\n'     || printf 'none\n' ;;
        rhel)
            if oobe_have dnf; then
                printf 'dnf\n'
            elif oobe_have yum; then
                printf 'yum\n'
            else
                printf 'none\n'
            fi
            ;;
        arch)          oobe_have pacman  && printf 'pacman\n'  || printf 'none\n' ;;
        suse)          oobe_have zypper  && printf 'zypper\n'  || printf 'none\n' ;;
        alpine)        oobe_have apk     && printf 'apk\n'     || printf 'none\n' ;;
        *)             printf 'none\n' ;;
    esac
}

# ---------------------------------------------------------------------------
# oobe_is_root
# ---------------------------------------------------------------------------
oobe_is_root() {
    [ "$(id -u 2>/dev/null || printf '0')" = "0" ]
}

# ---------------------------------------------------------------------------
# oobe_sudo
#
# Echoes the privilege escalation prefix to use, if any. Installers call this
# instead of assuming root, so a normal user account still works via sudo.
# ---------------------------------------------------------------------------
oobe_sudo() {
    if oobe_is_root; then
        printf '\n'
    elif oobe_have sudo; then
        printf 'sudo '
    else
        printf ''
    fi
}
