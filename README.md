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

## 🛠️ Usage

### 1. Installation Steps
First, you must run the core initialization command. After that, you can install specific Node.js versions.

#### Windows (Cmder)

| Command | Description |
| :--- | :--- |
| `install` | **Required for first run.** Initializes the installer. |
| `install\node\16` | Install Node.js v16 |
| `install\node\18` | Install Node.js v18 |
| `install\node\19` | Install Node.js v19 |
| `install\node\20` | Install Node.js v20 |
| `install\node\21` | Install Node.js v21 |
| `install\node\latest-lts` | Install the latest LTS release |
| `install\node\latest` | Install the latest release |
| `install\node_js {VER}` | Install a custom Node.js version (e.g., `install\node_js 22`) |

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
| `install.cmd` | Windows OOBE bootstrap (native flow) |
| `oobe.sh` | Cross-platform entry point; dispatches to Windows or Linux |
| `lib/oobe/detect.sh` | OS, architecture, distro and package manager detection |
| `lib/oobe/download.sh` | Auto-download with the curl → wget → python → package manager fallback chain |
| `lib/oobe/linux.sh` | Linux bootstrap: nvm-sh install, Node.js install, env file |
| `bin/install/` | Windows install commands |
| `bin/use/` | Windows version-switching commands |
| `.nvm/`, `.oobe-cache/` | Generated on Linux; not tracked |
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
