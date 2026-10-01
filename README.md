# cmder-nvm 🚀
> Easy Node.js installation and version management within Cmder without Admin privileges.
> Now supports **Windows** and **Linux**.

![[GitHub Release](https://img.shields.io/github/v/release/kbaraniak/cmder-nvm)](https://github.com/kbaraniak/cmder-nvm/releases/latest)

---

## ⬇️ Downloads
Get the latest version here: [Latest release](https://github.com/kbaraniak/cmder-nvm/releases/latest)

---

## 📦 Platform Support

The out-of-box setup (OOBE) flow detects your platform automatically and picks
the right backend.

| Platform | Entry point | Version manager |
| :--- | :--- | :--- |
| Windows (Cmder) | `install.cmd` | nvm-windows (bundled in `bin/`) |
| Linux | `./oobe.sh` | nvm-sh (downloaded into `.nvm/`) |
| macOS | — | not supported; use the Windows installer or install [nvm-sh](https://github.com/nvm-sh/nvm) manually |

### Windows: Missing nvm Binary

A standard checkout ships `bin/nvm.exe`, and `install.cmd` uses it directly.
If the binary is missing — a partial checkout, or a distribution where the
~7 MB executable was excluded — `install.cmd` downloads it automatically
before continuing, using the portable `nvm-noinstall` archive. That archive is
used deliberately: the regular installer rewrites `PATH` and registers a
system-wide symlink, which needs the admin rights this project avoids.

The download is tried with, in order:

1. **`curl`** (Windows 10 1803+, and Cmder's MSYS2 tools)
2. **PowerShell** `Invoke-WebRequest` (present on every supported Windows)
3. **Clear error** naming the URL, the target path, and how to override

If all transports fail, the script tells you exactly where to place
`nvm.exe`, and supports an override for mirrors:

```bat
set NVM_WINDOWS_URL=https://example.com/nvm-noinstall.zip
install
```

A downloaded archive is cached in `.oobe-cache/`, so a retry does not
re-download, and the resulting binary is executed once to confirm it is not a
truncated file.

> ⚠️ **Note:** the pinned default URL for `nvm-noinstall.zip` currently returns
> **404**. The upstream project moved to the
> [`nvm-windows/nvm`](https://github.com/nvm-windows/nvm) organisation and
> removed the v1.x release assets. The bundled `nvm.exe` is v1.1.10, which
> predates that change; v2.x is a redesign that keeps its configuration in the
> Windows registry instead of `settings.txt` and is **not** a drop-in
> replacement for this flow. Until v1.x assets are available again, set
> `NVM_WINDOWS_URL` to a mirror or an archived copy if you need this path.

### Linux Setup

```sh
git clone https://github.com/kbaraniak/cmder-nvm.git
cd cmder-nvm
./oobe.sh              # checks dependencies, installs nvm-sh, then prompts for a version
./oobe.sh 20           # or install a specific version directly
./oobe.sh --check      # verify the system without installing Node.js
```

Then activate Node.js in your shell:

```sh
. ./config/user_profile.sh
```

To make it permanent, add that line to `~/.bashrc` (or `~/.zshrc`).

### Dependencies

The Linux flow installs everything it needs automatically. These are the
tools it looks for, and what happens when one is missing:

| Requirement | Why | If missing |
| :--- | :--- | :--- |
| `bash` 3+ | nvm-sh is a bash-only tool | Installed via package manager |
| `tar` | Unpacks the nvm-sh archive | Installed via package manager |
| `xz` | Node.js Linux archives are `.tar.xz` | Installed via package manager |
| `curl` **or** `wget` **or** `python3` | Downloads nvm-sh | Installed via package manager, or see below |

No third-party libraries are added to the project itself.

Package manager support covers **Debian/Ubuntu** (`apt-get`), **Fedora** (`dnf`),
**RHEL/CentOS** (`dnf`/`yum`), **Arch** (`pacman`) and **openSUSE** (`zypper`).
`sudo` is used automatically when the script is not already running as root.

### Download Fallback Chain

When a required file is missing, the setup downloads it by trying each
method in order and using the first one that works:

1. **`curl`** — primary method
2. **`wget`** — first fallback
3. **`python3`** (`urllib.request`) — second fallback, covers minimal
   containers and distroless images
4. **Package manager** — `apt-get` / `dnf` / `pacman` / `zypper` / `apk` to
   install `curl` or `wget` when none of the above exist
5. **Clear error** — if all of the above fail, the script stops and prints the
   exact command to run for your distribution, for example:
   ```
   Debian/Ubuntu : sudo apt-get install -y curl
   Fedora        : sudo dnf install -y curl
   Arch          : sudo pacman -S --needed curl
   ```

Downloads are written to a temporary file and only moved into place after a
complete, non-empty transfer, so an interrupted download can never leave a
corrupt file behind.

### `oobe.sh` Options

| Option | Description |
| :--- | :--- |
| `-h`, `--help` | Show usage information |
| `-c`, `--check` | Run dependency checks and the nvm-sh install, then stop |
| `-q`, `--quiet` | Suppress progress output |
| `-n`, `--no-menu` | Never prompt; requires a version argument |

A version can also be supplied via the `CMDER_NVM_VERSION` environment
variable, which is useful in scripts and CI.

### What the Linux Flow Does

1. Detects the distribution and architecture.
2. Verifies `bash`, `tar`, `xz` and a download transport, installing any that
   are missing.
3. Downloads **nvm-sh v0.40.1** (pinned for reproducibility) into `.nvm/`
   inside the distribution, so no root access is required.
4. Writes `config/user_profile.sh`, which exports `NVM_DIR` and sources nvm.
5. Installs the requested Node.js version and sets it as the default.

Re-running the script is safe: an existing nvm-sh installation is kept and
already-downloaded archives are reused from `.oobe-cache/`.

---

## 📦 One-File Distribution

The project ships as a **single zip** instead of an unpacked Cmder tree.

```
cmder-nvm/
├── SETUP.cmd          ← run this
├── cmder-nvm.zip      ← the payload
└── README.md
```

### `SETUP.cmd` — One-Click Bootstrap

Double-click it, or run it from a command prompt. It:

1. **Unpacks** `cmder-nvm.zip` into `.\cmder-nvm\`
2. **Verifies** `bin\nvm.exe` is present (warning only — `install.cmd`
   will attempt to download it if missing)
3. **Wires the first-run install** by appending a conditional hook to
   `config\user_profile.cmd`, so `install.cmd` runs automatically the first
   time Cmder opens
4. **Launches Cmder** in the unpacked folder, where the install then runs

The startup hook is guarded by the presence of `nodejs\settings.txt`, which
`install.cmd` creates on success:

```bat
@if not exist "%~dp0..\nodejs\settings.txt" call "%~dp0..\install.cmd"
```

So it fires **exactly once**. Once settings exist the line is a no-op and Cmder
starts normally from then on. Re-running `SETUP.cmd` is safe — it will not
re-unpack, will not add a second hook, and will not re-run the installer.

> 📝 In a git checkout, where `Cmder.exe` already sits at the root, `SETUP.cmd`
> uses it in place and skips extraction entirely. It does still append the hook
> to `config\user_profile.cmd`, so that tracked file will show as modified —
> the appended block is clearly marked and safe to delete.

### `pack.cmd` — Building the Zip

Run from a checkout to produce the release artifact:

```bat
pack.cmd
```

It stages `bin\`, `vendor\`, `config\`, `opt\`, `icons\`, `Cmder.exe`,
`install.cmd` and `LICENSE` into a temporary folder, then compresses it to
`cmder-nvm.zip` with the payload rooted at the top level. Development-only
files (`.git`, caches, an already-installed `nodejs\`) are excluded.

---

## 🛠️ Usage

### 1. Installation Steps
First, you must run the core initialization command. After that, you can install specific Node.js versions.

#### Windows (Cmder)

**If you downloaded the zip**, just run `SETUP.cmd` — it unpacks everything and
opens Cmder with the installer ready to go.

If you already have an unpacked checkout, use these commands:

| Command | Description |
| :--- | :--- |
| `install` | **Required for first run.** Initializes the installer. |
| `install\node_js {VER}` | Install a Node.js version |

`install\node_js` accepts a major line, a full version, or a keyword:

| Command | Description |
| :--- | :--- |
| `install\node_js 18` | Install the latest v18 release |
| `install\node_js 18.19.0` | Install that exact version |
| `install\node_js lts` | Install the latest LTS release |
| `install\node_js latest` | Install the latest release |

#### Linux

Run `./oobe.sh` once to set everything up, then use `nvm` directly:

| Command | Description |
| :--- | :--- |
| `./oobe.sh` | Full setup, then pick a version from the menu |
| `./oobe.sh {VER}` | Install a specific version (e.g., `./oobe.sh 22`) |
| `nvm install {VER}` | Install another version |
| `nvm use {VER}` | Switch versions |
| `nvm ls` | List installed versions |

### 2. Switching Versions
Once a version is installed, use these commands to enable and switch between them.

#### Windows (Cmder)

| Command | Description |
| :--- | :--- |
| `use\node 16` | Enable Node.js v16 |
| `use\node 18` | Enable Node.js v18 |
| `use\node 19` | Enable Node.js v19 |
| `use\node 20` | Enable Node.js v20 |
| `use\node 21` | Enable Node.js v21 |
| `use\node lts` | Enable the latest LTS release |
| `use\node {VER}` | Enable any installed version (e.g., `use\node 18.19.0`) |

`use\node` accepts the `lts` and `latest` keywords as well as exact versions;
it resolves the keyword to the matching folder before switching.

#### Linux

Switching is handled by nvm directly, so the same commands work everywhere:

| Command | Description |
| :--- | :--- |
| `nvm use 16` | Switch to Node.js v16 |
| `nvm use 18` | Switch to Node.js v18 |
| `nvm use lts` | Switch to the latest LTS release |
| `nvm alias default {VER}` | Make a version the default for new shells |

---

## 🗂️ Project Layout

| Path | Purpose |
| :--- | :--- |
| `SETUP.cmd` | Unpacks the distribution, wires the first-run install, launches Cmder |
| `pack.cmd` | Builds `cmder-nvm.zip` from a checkout |
| `install.cmd` | Windows OOBE bootstrap (native flow) |
| `oobe.sh` | Cross-platform entry point; dispatches to Windows or Linux |
| `lib/oobe/detect.sh` | OS, architecture, distro and package manager detection |
| `lib/oobe/download.sh` | Auto-download with the curl → wget → python → package manager fallback chain |
| `lib/oobe/linux.sh` | Linux bootstrap: nvm-sh install, Node.js install, env file |
| `bin/nvm.exe` | Bundled nvm-windows binary; re-downloaded by `install.cmd` if absent |
| `bin/install/node_js.cmd` | Install any Node.js version on Windows |
| `bin/use/node.cmd` | Switch the active Node.js version on Windows |
| `bin/elevate.cmd`, `bin/elevate.vbs` | nvm-windows helper for admin-requiring operations |
| `.nvm/`, `.oobe-cache/` | Generated at install time; not tracked |
| `config/user_profile.sh` | Generated on Linux; not tracked |

---

## 📄 License & Credits

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

### Acknowledgments
This project is built upon and inspired by these amazing tools:
* **nvm** - [nvm-sh/nvm](https://github.com/nvm-sh/nvm/) (MIT)
* **nvm-windows** - [coreybutler/nvm-windows](https://github.com/coreybutler/nvm-windows) (MIT)
* **cmder** - [cmderdev/cmder](https://github.com/cmderdev/cmder) (MIT)

> 💡 *Please note: This repository contains projects created as part of university classes and may contain errors.*

---

**Thank you for using my project!** ❤️  
Pull Requests are always welcome. Made with love for coding.
