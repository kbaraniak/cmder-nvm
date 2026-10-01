# cmder-nvm 🚀
> Easy Node.js installation and version management within Cmder without Admin privileges.

![[GitHub Release](https://img.shields.io/github/v/release/kbaraniak/cmder-nvm)](https://github.com/kbaraniak/cmder-nvm/releases/latest)

---

## ⬇️ Downloads
Get the latest version here: [Latest release](https://github.com/kbaraniak/cmder-nvm/releases/latest)

---

## 🛠️ Usage

### 1. Installation Steps
First, you must run the core initialization command. After that, you can install specific Node.js versions.

| Command | Description |
| :--- | :--- |
| `install` | **Required for first run.** Initializes the installer. |
| `install\node\16` | Install Node.js v16 |
| `install\node\18` | Install Node.js v18 |
| `install\node\19` | Install Node.js v19 |
| `install\node\20` | Install Node.js v20 |
| `install\node\21` | Install Node.js v21 |
| `install\node_js {VER}` | Install a custom Node.js version (e.g., `install\node_js 22`) |

### 2. Switching Versions
Once a version is installed, use these commands to enable and switch between them.

| Command | Description |
| :--- | :--- |
| `use\node_16` | Enable Node.js v16 |
| `use\node_18` | Enable Node.js v18 |
| `use\node_19` | Enable Node.js v19 |
| `use\node_20` | Enable Node.js v20 |
| `use\node_21` | Enable Node.js v21 |
| `use\node_js {VER}` | Enable a custom Node.js version (e.g., `use\node_js 22`) |

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
