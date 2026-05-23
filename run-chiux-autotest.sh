#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KERNEL_IMAGE="$ROOT_DIR/out/Chiux-bzImage"
if [[ ! -f "$KERNEL_IMAGE" ]]; then
  echo "Missing $KERNEL_IMAGE, run ./os-build/build-chiux.sh first" >&2
  exit 1
fi
exec qemu-system-x86_64 \
  -machine accel=kvm:tcg \
  -m 1024 \
  -smp 2 \
  -kernel "$KERNEL_IMAGE" \
  -append 'console=ttyS0 rdinit=/init chiux.autotest=1' \
  -nographic \
  -no-reboot
