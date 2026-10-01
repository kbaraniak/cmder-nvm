#!/usr/bin/env sh
# ============================================================================
#  cmder-nvm - download and dependency provisioning
#
#  Implements the auto-download behaviour of the OOBE flow on Linux.
#
#  Download strategy, in order:
#    1. curl            (primary)
#    2. wget            (first fallback)
#    3. python3 urllib  (second fallback; covers minimal containers)
#    4. package manager (apt-get / dnf / pacman / ...) as a last resort
#    5. a clear, actionable error message
#
#  Every download is written to a temporary file first and only moved into
#  place after a successful, non-empty transfer, so an interrupted download
#  can never leave a truncated file that looks valid.
# ============================================================================

if [ -n "${CMDER_NVM_DOWNLOAD_SOURCED:-}" ]; then
    return 0 2>/dev/null || true
fi
CMDER_NVM_DOWNLOAD_SOURCED=1

# Where fetched payloads are cached within the distribution.
OOBE_CACHE_DIR="${OOBE_CACHE_DIR:-$CMDER_NVM_ROOT/.oobe-cache}"

# ---------------------------------------------------------------------------
# oobe_pkg_install <package>...
#
# Installs packages with the distro package manager. Returns non-zero when no
# supported manager is available or the install failed, so callers can fall
# back to another strategy.
# ---------------------------------------------------------------------------
oobe_pkg_install() {
    _pm=$(oobe_pkg_manager)
    if [ "$_pm" = "none" ]; then
        oobe_warn "no supported package manager found; cannot install: $*"
        return 1
    fi

    _sudo=$(oobe_sudo)
    oobe_info "installing $* via $_pm"

    case "$_pm" in
        apt-get) DEBIAN_FRONTEND=noninteractive ${_sudo}apt-get install -y --no-install-recommends "$@" ;;
        dnf)     ${_sudo}dnf install -y "$@" ;;
        yum)     ${_sudo}yum install -y "$@" ;;
        pacman)  ${_sudo}pacman -S --needed --noconfirm "$@" ;;
        zypper)  ${_sudo}zypper install -y "$@" ;;
        apk)     ${_sudo}apk add --no-cache "$@" ;;
        *)       return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# oobe_fetch <url> <destination>
#
# Downloads <url> to <destination>, trying each available transport in turn.
# Returns 0 only when the destination holds a non-empty file.
# ---------------------------------------------------------------------------
oobe_fetch() {
    _url=$1
    _dest=$2

    mkdir -p "$(dirname "$_dest")" 2>/dev/null || true
    _tmp="$_dest.part.$$"
    trap 'rm -f "$_tmp"' EXIT INT TERM

    _attempt_curl "$_url" "$_tmp" && _commit "$_tmp" "$_dest" && return 0
    _attempt_wget "$_url" "$_tmp" && _commit "$_tmp" "$_dest" && return 0
    _attempt_python "$_url" "$_tmp" && _commit "$_tmp" "$_dest" && return 0

    oobe_warn "no download transport available for $_url"
    rm -f "$_tmp"
    trap - EXIT INT TERM
    return 1
}

# Move a completed download into place, rejecting empty payloads.
_commit() {
    _src=$1
    _dest=$2
    if [ ! -s "$_src" ]; then
        rm -f "$_src"
        return 1
    fi
    mv -f "$_src" "$_dest"
}

# --- Transport 1: curl (primary) -------------------------------------------
_attempt_curl() {
    oobe_have curl || return 1
    oobe_info "downloading with curl: $1"
    # -f fail on HTTP errors, -L follow redirects, -sS quiet but show errors,
    # --retry survives transient network failures.
    curl -fSL --retry 2 --connect-timeout 15 -o "$2" "$1" 2>/dev/null
}

# --- Transport 2: wget ----------------------------------------------------
_attempt_wget() {
    oobe_have wget || return 1
    oobe_info "downloading with wget: $1"
    wget -q -T 15 -O "$2" "$1" 2>/dev/null
}

# --- Transport 3: python3 urllib ------------------------------------------
# Deliberately invoked as a heredoc-free one-liner so it works with any
# python3 on PATH, including the minimal builds shipped in distroless images.
_attempt_python() {
    oobe_have python3 || return 1
    oobe_info "downloading with python3 urllib: $1"
    python3 - "$1" "$2" <<'PY' 2>/dev/null
import shutil
import sys
import urllib.request

url, dest = sys.argv[1], sys.argv[2]
with urllib.request.urlopen(url, timeout=30) as response:
    with open(dest, "wb") as handle:
        shutil.copyfileobj(response, handle)
PY
}

# ---------------------------------------------------------------------------
# oobe_ensure_downloader
#
# Guarantees that at least one transport exists, installing one through the
# package manager when the system has none. Called before the first download
# so the fast paths are not wasted on a system that will fail anyway.
# ---------------------------------------------------------------------------
oobe_ensure_downloader() {
    if oobe_have curl || oobe_have wget || oobe_have python3; then
        oobe_ok "download transport available"
        return 0
    fi

    oobe_warn "neither curl, wget nor python3 was found"
    if oobe_pkg_install curl && oobe_have curl; then
        oobe_ok "installed curl via package manager"
        return 0
    fi
    if oobe_pkg_install wget && oobe_have wget; then
        oobe_ok "installed wget via package manager"
        return 0
    fi

    oobe_error "unable to install curl or wget automatically."
    oobe_error "Install one of them and re-run, for example:"
    oobe_error "  Debian/Ubuntu : sudo apt-get install -y curl"
    oobe_error "  Fedora        : sudo dnf install -y curl"
    oobe_error "  Arch          : sudo pacman -S --needed curl"
    return 1
}

# ---------------------------------------------------------------------------
# oobe_ensure_command <command> <package-name>
#
# Ensures a single external tool is available, installing it via the package
# manager when missing. Used for the small set of tools the Linux flow needs.
# ---------------------------------------------------------------------------
oobe_ensure_command() {
    _cmd=$1
    _pkg=${2:-$1}

    if oobe_have "$_cmd"; then
        oobe_ok "$_cmd is available"
        return 0
    fi

    oobe_warn "$_cmd is missing"
    if oobe_pkg_install "$_pkg" && oobe_have "$_cmd"; then
        oobe_ok "installed $_pkg"
        return 0
    fi

    oobe_error "required tool '$_cmd' is not available and could not be installed."
    oobe_error "Install it manually and re-run this script."
    return 1
}

# ---------------------------------------------------------------------------
# oobe_extract <archive> <target-dir> [strip-components]
#
# Unpacks a .tar.gz/.tar.xz archive. tar is the only tool used so no extra
# runtime dependency is introduced; xz support is part of tar on all modern
# distributions.
# ---------------------------------------------------------------------------
oobe_extract() {
    _archive=$1
    _target=$2
    _strip=${3:-1}

    oobe_ensure_command tar tar || return 1
    mkdir -p "$_target" || return 1
    tar -xf "$_archive" -C "$_target" --strip-components="$_strip" 2>/dev/null
}
