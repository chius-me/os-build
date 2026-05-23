#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
JOBS=${JOBS:-$(nproc)}
LINUX_REPO=${LINUX_REPO:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}
LINUX_TAG=${LINUX_TAG:-chiux-syscall}
BUSYBOX_REPO=${BUSYBOX_REPO:-https://git.busybox.net/busybox}
BUSYBOX_COMMIT=${BUSYBOX_COMMIT:-fb10ad3}
LINUX_DIR="$ROOT_DIR/linux"
BUSYBOX_DIR="$ROOT_DIR/busybox"
ROOTFS_DIR="$ROOT_DIR/rootfs"
OUT_DIR="$ROOT_DIR/out"
KERNEL_OUT="$OUT_DIR/Chiux-bzImage"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

for cmd in git make gcc rsync qemu-system-x86_64; do
  need_cmd "$cmd"
done

mkdir -p "$OUT_DIR"

if [[ ! -d "$LINUX_DIR/.git" ]]; then
  git clone "$LINUX_REPO" "$LINUX_DIR"
fi

# If LINUX_TAG is 'chiux-syscall', trust the local branch (avoids overwriting our changes)
if [[ "$LINUX_TAG" != "chiux-syscall" ]]; then
  git -C "$LINUX_DIR" fetch --tags --force origin
  if ! git -C "$LINUX_DIR" rev-parse -q --verify "refs/tags/$LINUX_TAG" >/dev/null; then
    echo "Missing Linux tag $LINUX_TAG" >&2
    exit 1
  fi
  git -C "$LINUX_DIR" checkout -f "$LINUX_TAG"
fi

if [[ ! -d "$BUSYBOX_DIR/.git" ]]; then
  git clone "$BUSYBOX_REPO" "$BUSYBOX_DIR"
fi

git -C "$BUSYBOX_DIR" fetch --force origin
git -C "$BUSYBOX_DIR" checkout -f "$BUSYBOX_COMMIT"

make -C "$BUSYBOX_DIR" distclean >/dev/null
make -C "$BUSYBOX_DIR" defconfig >/dev/null
python3 - <<'PY' "$BUSYBOX_DIR/.config"
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
replacements = {
    '# CONFIG_STATIC is not set': 'CONFIG_STATIC=y',
    'CONFIG_TC=y': '# CONFIG_TC is not set',
    'CONFIG_FEATURE_TC_INGRESS=y': '# CONFIG_FEATURE_TC_INGRESS is not set',
}
for old, new in replacements.items():
    s = s.replace(old, new)
p.write_text(s)
PY
make -C "$BUSYBOX_DIR" oldconfig >/dev/null < /dev/null
make -C "$BUSYBOX_DIR" -j"$JOBS"

rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"
make -C "$BUSYBOX_DIR" CONFIG_PREFIX="$ROOTFS_DIR" install >/dev/null
mkdir -p "$ROOTFS_DIR"/{dev,dev/pts,proc,sys,tmp,run,root,mnt,etc}
mknod -m 600 "$ROOTFS_DIR/dev/console" c 5 1 2>/dev/null || true
cat > "$ROOTFS_DIR/init" <<'EOF'
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
mount -t devtmpfs devtmpfs /dev 2>/dev/null || mkdir -p /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mkdir -p /dev/pts /run /tmp /root /mnt
mount -t devpts devpts /dev/pts 2>/dev/null || true
# Redirect to the actual console (devtmpfs now provides /dev/console)
exec >/dev/console 2>&1 </dev/console
hostname Chiux
cat <<'MSG'

Chiux booted
MSG
uname -a
printf '\nWelcome to Chiux.\n\n'
if grep -qw 'chiux.autotest=1' /proc/cmdline; then
  echo '[chiux] autotest mode'
  echo '[chiux] / contents:'
  ls /
  echo '[chiux] busybox:'
  /bin/busybox | sed -n '1,2p'
  echo '[chiux] testing sys_print_info:'
  /root/test_print_info
  echo '[chiux] powering off'
  poweroff -f
fi
exec setsid cttyhack /bin/sh
EOF
chmod +x "$ROOTFS_DIR/init"
cat > "$ROOTFS_DIR/etc/motd" <<'EOF'
Chiux
Linux 7.0 + BusyBox rootfs
EOF
cat > "$ROOTFS_DIR/etc/profile" <<'EOF'
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PS1='Chiux# '
echo 'Type uname -a or ls / to explore Chiux.'
EOF

# Build the syscall test program
mkdir -p "$ROOTFS_DIR/root"
gcc -static -o "$ROOTFS_DIR/root/test_print_info" -x c - 2>/dev/null <<'CEOF' || true
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#define __NR_print_info 548
int main() {
    long ret = syscall(__NR_print_info, 42);
    write(2, ret == 0 ? "Chiux: SUCCESS - sys_print_info returned 0\n"
                      : "Chiux: FAILED\n", ret == 0 ? 47 : 15);
    return 0;
}
CEOF

make -C "$LINUX_DIR" mrproper >/dev/null
make -C "$LINUX_DIR" x86_64_defconfig >/dev/null
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --set-str LOCALVERSION -chiux
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --disable DEBUG_INFO
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable MODULES
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable MODULE_UNLOAD
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable BLK_DEV_INITRD
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --set-str INITRAMFS_SOURCE "$ROOTFS_DIR"
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable RD_GZIP
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable BINFMT_ELF
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable BINFMT_SCRIPT
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable PROC_FS
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable SYSFS
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable DEVTMPFS
"$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable DEVTMPFS_MOUNT
make -C "$LINUX_DIR" oldconfig >/dev/null < /dev/null
make -C "$LINUX_DIR" -j"$JOBS" bzImage
cp "$LINUX_DIR/arch/x86/boot/bzImage" "$KERNEL_OUT"

echo "Built $KERNEL_OUT"
file "$KERNEL_OUT"
