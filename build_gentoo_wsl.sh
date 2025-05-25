#!/usr/bin/env bash
# -----------------------------------------------------------
# build_gentoo_wsl.sh
# 自动下载最新 stage3-amd64-openrc，生成 Gentoo .wsl 分发包
# 可传入自定义 stage3 URL 作第 1 参数
# -----------------------------------------------------------
set -euo pipefail

ROOT=gentoo-rootfs
TODAY=$(date +%Y-%m-%d)

# -------- 1. 获取 stage3 URL --------
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

echo "[*] 下载 ${STAGE_TAR}"
curl -# -O "${STAGE_URL}"

# -------- 2. 解压 --------
rm -rf "$ROOT" && mkdir -p "$ROOT"
echo "[*] 解压..."
tar -xpf "$STAGE_TAR" -C "$ROOT"

# -------- 3. 写入 WSL 配置 --------
echo "[*] 写入 /etc/wsl.conf"
/usr/bin/env bash -c "cat > $ROOT/etc/wsl.conf <<'EOF'
[automount]
root = /mnt
options = \"metadata\"
EOF"

echo "[*] 写入 /etc/wsl-distribution.conf"
/usr/bin/env bash -c "cat > $ROOT/etc/wsl-distribution.conf <<'EOF'
[oobe]
command     = /usr/lib/wsl/oobe.sh
defaultUid  = 0
defaultName = Gentoo

[shortcut]
enabled = true
icon = /usr/lib/wsl/gentoo.ico
EOF"

# 确保 wheel 组存在（sudo 需要）
grep -q '^wheel:' "$ROOT/etc/group" || echo 'wheel:x:10:' >> "$ROOT/etc/group"

# -------- 4. 安装 OOBE 脚本与占位图标 --------
echo "[*] 安装 oobe.sh"
/usr/bin/env bash -c "install -Dm755 oobe.sh $ROOT/usr/lib/wsl/oobe.sh"
echo "[*] gentoo.ico"
install -Dm644 "gentoo-signet-128x128.ico" "$ROOT/usr/lib/wsl/gentoo.ico"

# -------- 5. 在 chroot 环境安装 sudo 等基础包 --------
echo "[*] 进入 chroot 安装基础软件 …"

# 5.1. 复制宿主 DNS，保证 chroot 内能解析
cp -L /etc/resolv.conf "$ROOT/etc/"

# 5.2. 绑定 /dev /proc /sys，并记录以便清理
for mp in dev proc sys; do
    mount --bind "/$mp" "$ROOT/$mp"
done

# 5.3. 保证脚本异常时也能卸载
cleanup() {
    echo "[*] 清理挂载 …"
    for mp in dev proc sys; do
        umount -l "$ROOT/$mp" 2>/dev/null || true
    done
}
trap cleanup EXIT

# 5.4. 进入 chroot 安装 sudo
chroot "$ROOT" /bin/bash -e <<'CHROOT'
source /etc/profile
emerge --sync #--quiet --quiet
emerge --quiet app-admin/sudo          # ← 正确分类
mkdir -p /etc/sudoers.d
echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
CHROOT

# 5.5. 手动调用一次 cleanup（trap 也会再跑一遍，但无害）
cleanup
trap - EXIT


# -------- 5. 可选精简 --------
#echo "[*] 精简 man/doc/zoneinfo..."
#rm -rf "$ROOT"/usr/share/{man,doc,zoneinfo}

# -------- 6. 打包为 .wsl --------
WSL_NAME="gentoo_${TODAY}.wsl"
echo "[*] 打包 ${WSL_NAME}..."
tar --numeric-owner --xattrs --acls -c -C "$ROOT" . | gzip -9 > "${WSL_NAME}"

echo "=== 完成！生成文件: $(pwd)/${WSL_NAME} ==="
echo "安装示例： wsl --install --from-file $(pwd)/${WSL_NAME}"
