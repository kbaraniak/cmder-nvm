#!/usr/bin/env sh
# ============================================================================
#  cmder-nvm - Linux OOBE flow
#
#  Mirrors what install.cmd does on Windows, using nvm-sh instead of
#  nvm-windows. The flow is:
#
#    1. detect the distro and architecture
#    2. verify every required tool / file, auto-downloading what is missing
#    3. install nvm-sh into a per-user directory
#    4. install the requested Node.js version and make it the default
#    5. print the exact shell snippet the user needs to source
# ============================================================================

if [ -n "${CMDER_NVM_LINUX_SOURCED:-}" ]; then
    return 0 2>/dev/null || true
fi
CMDER_NVM_LINUX_SOURCED=1

# Pinned nvm-sh release. Pinning keeps installs reproducible and lets the
# script work on hosts with no git, since we fetch a plain tarball.
OOBE_NVM_VERSION="${OOBE_NVM_VERSION:-v0.40.1}"
OOBE_NVM_URL="https://github.com/nvm-sh/nvm/archive/refs/tags/${OOBE_NVM_VERSION}.tar.gz"

# nvm-sh is a bash-only tool, so the whole flow targets bash even though the
# surrounding scripts stay POSIX compatible.
OOBE_NVM_BASH_MIN_MAJOR=3

# ---------------------------------------------------------------------------
# oobe_linux_check_prereqs
#
# Verifies the base toolchain. Returns non-zero on the first hard failure so
# the caller can abort with a usable message instead of a broken shell.
# ---------------------------------------------------------------------------
oobe_linux_check_prereqs() {
    oobe_step "Checking required tools"
    oobe_info "distribution: $(oobe_distro)"
    oobe_info "architecture: $(oobe_arch)"

    # bash: nvm-sh is written for bash and will not source under dash.
    oobe_ensure_command bash bash || return 1

    _bash_major=$(bash -c 'printf "%s" "${BASH_VERSINFO:-0}"' 2>/dev/null)
    if [ "${_bash_major:-0}" -lt "$OOBE_NVM_BASH_MIN_MAJOR" ] 2>/dev/null; then
        oobe_error "bash ${OOBE_NVM_BASH_MIN_MAJOR}+ is required to run nvm-sh (found: ${_bash_major:-unknown})."
        return 1
    fi

    # tar: required to unpack the nvm-sh tarball and the Node.js archives.
    oobe_ensure_command tar tar || return 1

    # xz: Node.js linux archives are .tar.xz on every current release.
    if oobe_have xz; then
        oobe_ok "xz is available"
    else
        oobe_warn "xz is missing; needed to unpack Node.js archives"
        case "$(oobe_distro)" in
            debian|ubuntu) _pkg=xz-utils ;;
            *)             _pkg=xz ;;
        esac
        oobe_pkg_install "$_pkg" >/dev/null 2>&1 || true
        if oobe_have xz; then
            oobe_ok "installed $_pkg"
        else
            oobe_error "xz is required to install Node.js and could not be installed."
            oobe_error "Install it manually, e.g.: sudo apt-get install -y xz-utils"
            return 1
        fi
    fi

    oobe_ensure_downloader || return 1
    return 0
}

# ---------------------------------------------------------------------------
# oobe_linux_nvm_dir
#
# Prints the directory nvm-sh is installed into. Kept inside the distribution
# so the setup stays self-contained and needs no root access.
# ---------------------------------------------------------------------------
oobe_lvm_nvm_dir() {
    printf '%s\n' "${OOBE_NVM_DIR:-$CMDER_NVM_ROOT/.nvm}"
}

# ---------------------------------------------------------------------------
# oobe_linux_install_nvm
#
# Installs nvm-sh into the local nvm directory if it is not already present.
# Idempotent: re-running the OOBE keeps an existing installation.
# ---------------------------------------------------------------------------
oobe_linux_install_nvm() {
    _nvm_dir=$(oobe_lvm_nvm_dir)

    oobe_step "Installing nvm-sh $OOBE_NVM_VERSION"

    if [ -s "$_nvm_dir/nvm.sh" ]; then
        oobe_ok "nvm-sh already present in $_nvm_dir"
        return 0
    fi

    _archive="$OOBE_CACHE_DIR/nvm-${OOBE_NVM_VERSION}.tar.gz"
    if [ -s "$_archive" ]; then
        oobe_ok "using cached archive $_archive"
    else
        oobe_info "fetching $OOBE_NVM_URL"
        if ! oobe_fetch "$OOBE_NVM_URL" "$_archive"; then
            oobe_error "failed to download nvm-sh from $OOBE_NVM_URL"
            oobe_error "Check your network connection, or download the archive manually to:"
            oobe_error "  $_archive"
            return 1
        fi
        oobe_ok "downloaded nvm-sh"
    fi

    rm -rf "$_nvm_dir"
    mkdir -p "$_nvm_dir" || return 1
    if ! oobe_extract "$_archive" "$_nvm_dir" 1; then
        oobe_error "failed to unpack $_archive"
        return 1
    fi

    if [ ! -s "$_nvm_dir/nvm.sh" ]; then
        oobe_error "nvm.sh is missing after unpacking; archive may be corrupt."
        return 1
    fi

    oobe_ok "nvm-sh installed in $_nvm_dir"
    return 0
}

# ---------------------------------------------------------------------------
# oobe_linux_load_nvm
#
# Sources nvm.sh into the current shell and exports NVM_DIR. Must be run from
# a bash process; the caller is responsible for that.
# ---------------------------------------------------------------------------
oobe_linux_load_nvm() {
    NVM_DIR=$(oobe_lvm_nvm_dir)
    export NVM_DIR
    # nvm.sh wants a sane umask; it warns and can misbehave without it.
    [ -n "${NVM_DIR:-}" ] || return 1
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh" || return 1
    return 0
}

# ---------------------------------------------------------------------------
# oobe_linux_install_node <version>
#
# Installs a Node.js version and pins it as the default alias. Accepts full
# versions (18.20.4), major lines (18) and the nvm keywords latest / lts.
# ---------------------------------------------------------------------------
oobe_linux_install_node() {
    _ver=$1
    if [ -z "$_ver" ]; then
        oobe_error "a Node.js version is required"
        return 1
    fi

    oobe_step "Installing Node.js $_ver"

    # nvm must run in bash, not the POSIX shell running this script.
    #
    # NVM_DIR is passed explicitly and any inherited value is cleared first:
    # if the user already has a system-wide nvm, nvm.sh would otherwise
    # install the version there and leave this distribution empty.
    OOBE_NVM_DIR_LOCAL=$(oobe_lvm_nvm_dir)
    OOBE_NVM_VERSION_ARG=$_ver
    export OOBE_NVM_DIR_LOCAL OOBE_NVM_VERSION_ARG
    unset NVM_DIR NVM_BIN

    bash -c '
        set -e
        NVM_DIR="$OOBE_NVM_DIR_LOCAL"
        export NVM_DIR
        . "$NVM_DIR/nvm.sh"
        nvm install "$OOBE_NVM_VERSION_ARG"
        nvm alias default "$OOBE_NVM_VERSION_ARG"
    ' || {
        oobe_error "nvm failed to install Node.js $_ver"
        return 1
    }

    oobe_ok "Node.js $_ver installed and set as default"
    return 0
}

# ---------------------------------------------------------------------------
# oobe_linux_write_env
#
# Writes a sourceable env file so the user's shell picks up nvm on the next
# start. Idempotent: rewriting it is always safe.
# ---------------------------------------------------------------------------
oobe_linux_write_env() {
    _env_file="$CMDER_NVM_ROOT/config/user_profile.sh"
    _nvm_dir=$(oobe_lvm_nvm_dir)

    oobe_step "Writing $_env_file"

    mkdir -p "$(dirname "$_env_file")" || return 1
    cat > "$_env_file" <<EOF
# Generated by cmder-nvm. Source this from your shell profile:
#   . "$_env_file"
#
# nvm-sh (the Linux equivalent of the bundled nvm-windows).
export NVM_DIR="$_nvm_dir"
if [ -s "\$NVM_DIR/nvm.sh" ]; then
    . "\$NVM_DIR/nvm.sh"
fi
EOF

    oobe_ok "wrote $_env_file"
    return 0
}

# ---------------------------------------------------------------------------
# oobe_linux_summary
#
# Final report for the user: what changed and how to activate it.
# ---------------------------------------------------------------------------
oobe_linux_summary() {
    _env_file="$CMDER_NVM_ROOT/config/user_profile.sh"

    oobe_step "Setup complete"
    oobe_log "  Activate Node.js in your current shell with:"
    oobe_log ""
    oobe_log "      . \"$_env_file\""
    oobe_log ""
    oobe_log "  To make it permanent, add that line to ~/.bashrc (or ~/.zshrc)."
    oobe_log "  Afterwards, use nvm as usual:"
    oobe_log ""
    oobe_log "      nvm install 20        # install another version"
    oobe_log "      nvm use 20           # switch versions"
    oobe_log "      nvm ls               # list installed versions"
}
