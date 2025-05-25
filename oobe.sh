#!/usr/bin/env bash
set -e

DEFAULT_USER="gentoo"

# 如果 UID 1000 已存在，直接把它写进 wsl.conf 然后结束
if id -u 1000 &>/dev/null; then
    EXISTING=$(getent passwd 1000 | cut -d: -f1)
    printf '\n[user]\ndefault = %s\n' "$EXISTING" >> /etc/wsl.conf
    echo "[OOBE] Default user set to \"$EXISTING\" via /etc/wsl.conf"
    exit 0
fi

# 交互获取用户名（无 TTY 时回退到 gentoo）
if [[ -t 0 && -t 1 ]]; then
    echo "=== Gentoo WSL – First-run setup ==="
    while true; do
        read -rp "Enter new UNIX username [${DEFAULT_USER}]: " USERNAME
        USERNAME=${USERNAME:-$DEFAULT_USER}
        [[ $USERNAME =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { echo "Invalid name"; continue; }
        id "$USERNAME" &>/dev/null && { echo "Name exists"; continue; }
        break
    done
else
    USERNAME=$DEFAULT_USER
    echo "[OOBE] Non-interactive – using \"$USERNAME\" (empty password)."
fi

echo "[OOBE] Creating user \"$USERNAME\" (UID 1000)…"
useradd -m -u 1000 -G wheel -s /bin/bash "$USERNAME"

if [[ -t 0 && -t 1 ]]; then
    echo "Set password for $USERNAME:"
    passwd "$USERNAME"
else
    passwd -d "$USERNAME"
fi

# 把新用户写进 /etc/wsl.conf
printf '\n[user]\ndefault = %s\n' "$USERNAME" >> /etc/wsl.conf
echo "[OOBE] Default user set to \"$USERNAME\" via /etc/wsl.conf"
