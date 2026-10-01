#!/usr/bin/env python3
"""
Static checks for the cmder-nvm Windows scripts.

These run on any platform with Python 3, including CI and Linux containers
where cmd.exe is not available. They cannot replace tests/run.cmd, which
executes the real flow, but they catch the class of mistake that is expensive
to find on Windows: a stale reference, a label that no longer exists, a
manifest that no longer matches the binaries.

    python3 tests/static_checks.py [repo-root]
"""
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

FAILURES = []
CHECKS = 0


def check(condition, message):
    global CHECKS
    CHECKS += 1
    if not condition:
        FAILURES.append(message)
    return condition


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_version(root):
    version_file = root / "VERSION"
    if not check(version_file.is_file(), "VERSION is missing"):
        return
    version = version_file.read_text().strip()
    check(
        re.fullmatch(r"\d+\.\d+\.\d+", version) is not None,
        f"VERSION is not semver: {version!r}",
    )


def check_manifest(root):
    manifest_file = root / "manifest.json"
    if not check(manifest_file.is_file(), "manifest.json is missing"):
        return

    try:
        manifest = json.loads(manifest_file.read_text())
    except json.JSONDecodeError as error:
        FAILURES.append(f"manifest.json is not valid JSON: {error}")
        return

    for key, value in manifest.items():
        if key.startswith("_"):
            continue
        # schema is a JSON number on purpose; every other value is a string.
        if key == "schema":
            check(
                isinstance(value, int) and value >= 1,
                f"manifest schema must be a positive integer, got {value!r}",
            )
            continue
        check(
            isinstance(value, str) and value != "",
            f"manifest value for {key!r} is empty or not a string",
        )
        check(
            not (isinstance(value, str) and '": "' in value),
            f'manifest value for {key!r} contains \'": "\', which breaks parsing',
        )

    # Every dotted key must be matched literally by the parser, so no key may be
    # a substring of another key.
    keys = [
        k
        for k, v in manifest.items()
        if not k.startswith("_") and k != "schema" and isinstance(v, str)
    ]
    for key in keys:
        check(
            " " not in key,
            f"manifest key contains a space, which lib/manifest.cmd cannot parse: {key!r}",
        )

    # lib/manifest.cmd matches a key with the literal pattern *"KEY": ", so two
    # keys only collide if one full pattern appears inside the other's line.
    # Simulating that is more precise than a plain substring test, which would
    # flag "cmder.archive" against "cmder.archive.sha256" even though the parser
    # never confuses the two.
    text = manifest_file.read_text()
    for key in keys:
        for other in keys:
            if key == other:
                continue
            pattern = f'"{key}": "'
            other_pattern = f'"{other}": "'
            for line in text.splitlines():
                if pattern in line and other_pattern in line:
                    FAILURES.append(
                        f"manifest keys {key!r} and {other!r} are indistinguishable to "
                        f"lib/manifest.cmd; both match {pattern!r} in: {line.strip()}"
                    )
                    break

    # The pinned digests must match the artifacts as they are on disk. Cmder is
    # not on disk any more: it ships inside lib/cmder-<version>.zip, so its
    # digest is verified by reading the member out of the archive. That check is
    # what proves SETUP.cmd's post-extraction verification will pass.
    for digest_key, file_key in (
        ("nvm-windows.sha256", "nvm-windows.file"),
    ):
        if digest_key not in manifest or file_key not in manifest:
            continue
        target = root / manifest[file_key]
        if not check(target.is_file(), f"manifest points at a missing file: {manifest[file_key]}"):
            continue
        actual = sha256(target)
        check(
            actual == manifest[digest_key],
            f"{manifest[file_key]} digest is stale: manifest says "
            f"{manifest[digest_key]}, file is {actual}",
        )

    archive_key = "cmder.archive"
    if archive_key in manifest:
        archive = root / manifest[archive_key]
        if check(archive.is_file(), f"manifest points at a missing archive: {manifest[archive_key]}"):
            if "cmder.archive.sha256" in manifest:
                actual = sha256(archive)
                check(
                    actual == manifest["cmder.archive.sha256"],
                    f"{manifest[archive_key]} digest is stale: manifest says "
                    f"{manifest['cmder.archive.sha256']}, file is {actual}",
                )

            member = manifest.get("cmder.file", "Cmder.exe")
            digest = hashlib.sha256()
            found = False
            with zipfile.ZipFile(archive) as bundle:
                for info in bundle.infolist():
                    if info.filename == member:
                        digest.update(bundle.read(info))
                        found = True
                        break
            check(found, f"{member} is not inside {manifest[archive_key]}")
            if found and "cmder.sha256" in manifest:
                actual = digest.hexdigest()
                check(
                    actual == manifest["cmder.sha256"],
                    f"{member} inside the archive has a stale digest: manifest says "
                    f"{manifest['cmder.sha256']}, archive holds {actual}",
                )


def check_cmder_is_not_vendored(root):
    """
    Cmder must arrive as a verified archive, not as a tree in the source repo.

    A vendored Cmder makes updating it a diff over hundreds of files and puts an
    unverifiable binary in version control, which is exactly what the manifest
    exists to prevent.
    """
    for name in ("Cmder.exe", "vendor", "config", "opt", "icons"):
        check(
            not (root / name).exists() or (root / name).is_file() and name == "VERSION",
            f"{name} exists in the source tree; Cmder must ship only as lib/cmder-*.zip",
        )

    archives = sorted((root / "lib").glob("cmder-*.zip"))
    check(bool(archives), "no Cmder archive in lib/")

    hook = root / "src" / "profile.d" / "cmder-nvm.cmd"
    check(
        hook.is_file(),
        "src/profile.d/cmder-nvm.cmd is missing; the hook must be tracked in src/, "
        "because config/ is generated by SETUP.cmd",
    )


def iter_batch_files(root):
    skip = {".git", ".kilo", "vendor", "config", "opt", "icons", "nodejs", "node", ".nvm", ".oobe-cache"}
    for path in root.rglob("*"):
        if path.is_dir():
            continue
        if set(path.relative_to(root).parts) & skip:
            continue
        if path.suffix.lower() in {".cmd", ".bat"}:
            yield path


def strip_comments(line):
    """Drop a trailing REM comment that is not inside a quoted string."""
    result = []
    in_string = False
    index = 0
    while index < len(line):
        char = line[index]
        if char == '"':
            in_string = not in_string
        if not in_string and line[index:].upper().lstrip().startswith("REM "):
            break
        if not in_string and line[index:].upper().lstrip() == "REM":
            break
        result.append(char)
        index += 1
    return "".join(result)


def strip_batch_idioms(line):
    """
    Remove text that looks like a bracket but is not a block.

    `echo(` is the batch idiom for echoing a string that starts with a
    delimiter, and it opens no block. Counting it as an opening bracket makes
    every later line look unbalanced.
    """
    return re.sub(r"\becho\s*\(", "echo ", line, flags=re.IGNORECASE)


def check_labels(root):
    """Every goto / call target inside a script must exist in that script."""
    pattern = re.compile(r"^\s*(?:goto|call)\s+:?([A-Za-z_][A-Za-z0-9_]*)", re.IGNORECASE)
    for path in iter_batch_files(root):
        text = path.read_text(errors="replace")
        defined = {
            match.group(1).lower()
            for match in re.finditer(r"^\s*:([A-Za-z_][A-Za-z0-9_]*)", text, re.IGNORECASE | re.MULTILINE)
        }
        for raw in text.splitlines():
            line = strip_comments(raw)
            if line.lstrip().lower().startswith("rem"):
                continue
            match = pattern.match(line)
            if not match:
                continue
            target = match.group(1).lower()
            # `call nvm install ...` and `call :lib` are not internal labels.
            if target in {"errorlevel", "exit", "nvm", "node", "npm"}:
                continue
            check(
                target in defined,
                f"{path.relative_to(root)} references :{match.group(1)} which is not defined",
            )


def check_parentheses(root):
    """Unbalanced parentheses break a batch block at runtime."""
    for path in iter_batch_files(root):
        text = path.read_text(errors="replace")
        depth = 0
        for number, raw in enumerate(text.splitlines(), start=1):
            line = strip_batch_idioms(strip_comments(raw))
            if line.lstrip().lower().startswith("rem"):
                continue
            depth += line.count("(") - line.count(")")
            check(
                depth >= 0,
                f"{path.relative_to(root)}:{number} closes a parenthesis that was never opened",
            )
        check(
            depth == 0,
            f"{path.relative_to(root)} ends with {depth} unclosed parenthesis(es)",
        )


def check_line_endings(root):
    """Batch is parsed line by line, so a stray CR inside a script breaks it."""
    for path in iter_batch_files(root):
        data = path.read_bytes()
        check(
            b"\r" not in data,
            f"{path.relative_to(root)} contains a bare CR",
        )


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()

    check_version(root)
    check_manifest(root)
    check_cmder_is_not_vendored(root)
    check_labels(root)
    check_parentheses(root)
    check_line_endings(root)

    print(f"static checks: {CHECKS} run, {len(FAILURES)} failed")
    for failure in FAILURES:
        print(f"  [FAIL] {failure}")
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
