#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -oue pipefail

KERNEL_SUFFIX=""
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(|'"$KERNEL_SUFFIX"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"$KERNEL_SUFFIX"'-)//')"
export DRACUT_NO_XATTR=1
# Use bootc dracut module on sealed images (rpm-ostree absent); ostree on standard
if command -v rpm-ostree >/dev/null 2>&1; then
    DRACUT_MODULE="ostree"
else
    DRACUT_MODULE="bootc"
fi
/usr/bin/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible -v --add "${DRACUT_MODULE}" -f "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
chmod 0600 "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"

echo "::endgroup::"
