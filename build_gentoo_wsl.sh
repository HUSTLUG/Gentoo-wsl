#!/usr/bin/env bash
# -----------------------------------------------------------
# build_gentoo_wsl.sh
# Automatically download the latest stage3-amd64-openrc and
# produce a Gentoo .wsl package.
# -----------------------------------------------------------
set -euo pipefail

ROOT=gentoo-rootfs
TODAY=$(date +%Y-%m-%d)

# -------- 1. Fetch stage3 URL --------
if [[ $# -ge 1 ]]; then
    STAGE_URL="$1"
else
    BASE="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-openrc"
    LATEST_TXT="${BASE}/latest-stage3-amd64-openrc.txt"
    echo "[*] 读取 ${LATEST_TXT}"
    TAR_NAME=$(curl -s "$LATEST_TXT" | grep stage3 | awk '{print $1}')
    STAGE_URL="${BASE}/${TAR_NAME}"
fi
STAGE_TAR=${STAGE_URL##*/}

echo "[*] Downloading ${STAGE_TAR}"
curl -# -O "${STAGE_URL}"

# -------- 2. Extract stage3 --------
rm -rf "$ROOT" && mkdir -p "$ROOT"
echo "[*] Extracting..."
tar -xpf "$STAGE_TAR" -C "$ROOT"

# -------- 3. Write WSL configuration --------
echo "[*] Writing /etc/wsl.conf"
/usr/bin/env bash -c "cat > $ROOT/etc/wsl.conf <<'EOF'
# WSL runtime settings
# [automount] enabled=true is implicit, so we leave the block out
EOF"

echo "[*] Writing /etc/wsl-distribution.conf"
/usr/bin/env bash -c "cat > $ROOT/etc/wsl-distribution.conf <<'EOF'
[oobe]
command     = /usr/lib/wsl/oobe.sh
# defaultUid  = 0
defaultName = Gentoo

[shortcut]
enabled = true
icon = /usr/lib/wsl/gentoo.ico
EOF"

# Ensure the wheel group exists (needed for sudo)
grep -q '^wheel:' "$ROOT/etc/group" || echo 'wheel:x:10:' >> "$ROOT/etc/group"

# -------- 4. Install OOBE script --------
echo "[*] Installing oobe.sh"
/usr/bin/env bash -c "install -Dm755 oobe.sh $ROOT/usr/lib/wsl/oobe.sh"
echo "[*] gentoo.ico"
install -Dm644 "gentoo-signet-128x128.ico" "$ROOT/usr/lib/wsl/gentoo.ico"

# -------- 5. Install basic packages in chroot environment --------
echo "[*] Entering chroot to install basic software …"

# 5.1. Copy host DNS to ensure chroot can resolve
cp -L /etc/resolv.conf "$ROOT/etc/"

# 5.2. Bind /dev /proc /sys and record for cleanup
for mp in dev proc sys; do
    mount --bind "/$mp" "$ROOT/$mp"
done
mkdir -p "$ROOT/dev/pts"
mount -t devpts devpts "$ROOT/dev/pts"

# 5.3. Ensure cleanup on script exit
cleanup() {
    echo "[*] Cleaning up mounts …"
    umount -l "$ROOT/dev/pts" 2>/dev/null || true
    for mp in dev proc sys; do
        umount -l "$ROOT/$mp" 2>/dev/null || true
    done
}
trap cleanup EXIT

# 5.4. Enter chroot to install sudo
chroot "$ROOT" /bin/bash -e <<'CHROOT'
source /etc/profile
emerge --sync #--quiet --quiet
emerge --quiet app-admin/sudo         
mkdir -p /etc/sudoers.d
echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
CHROOT

# 5.5. Manually call cleanup once (trap will run again, but harmless)
cleanup
trap - EXIT


# -------- 5. Optional Cleanup --------
#echo "[*] Cleaning up man/doc/zoneinfo..."
#rm -rf "$ROOT"/usr/share/{man,doc,zoneinfo}

# -------- 6. Package as .wsl --------
WSL_NAME="gentoo_${TODAY}.wsl"
echo "[*] Packaging ${WSL_NAME}..."
tar --numeric-owner --xattrs --acls -c -C "$ROOT" . | gzip -9 > "${WSL_NAME}"

echo "=== Done! Generated file: $(pwd)/${WSL_NAME} ==="
echo "Installation example: wsl --install --from-file $(pwd)/${WSL_NAME}"
