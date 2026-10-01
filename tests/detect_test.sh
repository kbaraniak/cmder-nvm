#!/bin/sh
# ---------------------------------------------------------------------------
# Regression tests for lib/oobe/detect.sh.
#
# These run on Linux, unlike tests\run.cmd, which needs cmd.exe. detect.sh
# decides what the installer does to a machine, and a wrong answer there is
# silent: oobe_pkg_install falls through its case and returns 1 without
# installing anything, so the only symptom is a missing prerequisite that
# nothing reports.
#
# oobe_distro and oobe_have are stubbed so every branch can be exercised
# regardless of the machine this runs on. Each case asserts the *exact*
# output, because the original bug was extra output, not wrong output.
# ---------------------------------------------------------------------------
set -u

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=../lib/oobe/detect.sh
. "$ROOT/lib/oobe/detect.sh"

RUN=0
FAILED=0

# expect <description> <expected-output> <distro> <available-commands...>
expect() {
    _desc=$1
    _want=$2
    _distro=$3
    shift 3

    RUN=$((RUN + 1))

    _got=$(
        oobe_distro() { printf '%s\n' "$_distro"; }
        _avail=" $* "
        oobe_have() {
            case "$_avail" in
                *" $1 "*) return 0 ;;
                *) return 1 ;;
            esac
        }
        oobe_pkg_manager
    )

    if [ "$_got" = "$_want" ]; then
        printf 'ok   %s\n' "$_desc"
    else
        FAILED=$((FAILED + 1))
        printf 'FAIL %s\n       want: %s\n       got:  %s\n' "$_desc" "$_want" "$_got"
    fi
}

# ---------------------------------------------------------------------------
# oobe_pkg_manager
# ---------------------------------------------------------------------------

expect 'debian with apt-get'        'apt-get' debian apt-get
expect 'ubuntu without apt-get'     'none'    ubuntu curl

# RHEL 8 and 9 ship dnf and yum together. This is the case that was broken:
# chained `&&`/`||` bound left to right, so the yum test ran anyway and both
# names were printed.
expect 'rhel with dnf and yum'      'dnf'     rhel dnf yum
expect 'rhel with yum only'         'yum'     rhel yum
expect 'rhel with dnf only'         'dnf'     rhel dnf
expect 'rhel with neither'          'none'    rhel tar

expect 'fedora with dnf'            'dnf'     fedora dnf
expect 'arch with pacman'           'pacman'  arch pacman
expect 'suse with zypper'           'zypper'  suse zypper
expect 'alpine with apk'            'apk'     alpine apk
expect 'unknown distro'             'none'    plan9 anything

# ---------------------------------------------------------------------------
printf 'detect tests: %d run, %d failed\n' "$RUN" "$FAILED"
[ "$FAILED" -eq 0 ]
