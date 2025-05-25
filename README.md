# Gentoo WSL

> **Gentoo Linux rolling-release image for Windows Subsystem for Linux (WSL)**  
> Maintained by the **Huazhong University of Science and Technology Linux USER Group – HLUG**  
> <https://hlug.cn>

---

## Overview

This repository provides an unofficial, continuously updated **`.wsl` package** that lets you install Gentoo on Windows with a single command:

```powershell
wsl --install gentoo          # once our PR is merged into microsoft/WSL
````

For manual installation or testing:

```powershell
wsl --install --from-file gentoo_YYYY-MM-DD.wsl
```

The root-filesystem is built from the latest **stage3-amd64-openrc** snapshot, pre-configured with:

* Interactive **OOBE** that creates your first user (UID 1000, in `wheel` group)
* `sudo` pre-installed and `%wheel` enabled
* `wsl.conf` tuned for `/mnt` automount with `metadata`
---

## Usage

1. Download the latest release from [https://github.com/hlug-hust/gentoo-wsl/releases](https://github.com/hlug-hust/gentoo-wsl/releases).
2. Run

   ```powershell
   wsl --install --from-file gentoo_YYYY-MM-DD.wsl
   ```
3. Follow the OOBE prompt to create your user and set a password.
4. On subsequent launches you will drop directly into that user account.

---

## Build it yourself

```bash
git clone https://github.com/hlug-hust/gentoo-wsl.git
cd gentoo-wsl
./build_gentoo_wsl.sh                 # fetches stage3, installs sudo, packs .wsl
# result: gentoo_YYYY-MM-DD.wsl
```

*Requires `bash`, `curl`, `tar` and root privileges for the chroot step.*

---

## Maintainers

| Name                             | Role                | Contact                           |
| -------------------------------- | ------------------- | --------------------------------- |
| HLUG | Primary maintainers | [wsl@hlug.cn](mailto:wsl@hlug.cn) |

We welcome issues & PRs from the community!

---

## License

The build scripts are released under the **GPL V2.0 License**.
Gentoo packages inside the image retain their original licenses as provided by Gentoo.
