#!/bin/bash
#
# Install the rtl8821ce driver via DKMS for every kernel on this
# machine that has headers installed (/lib/modules/<ver>/build).
#
# Usage: sudo ./dkms-install.sh

set -u
shopt -s nullglob

if [[ $EUID -ne 0 ]]; then
  echo "You must run this with superuser privileges.  Try \"sudo ./dkms-install.sh\"" 2>&1
  exit 1
fi

DRV_NAME=rtl8821ce
DRV_VERSION=v5.5.2_34066.20200325
SRC_DIR=/usr/src/${DRV_NAME}-${DRV_VERSION}

echo "About to run dkms install steps..."

# Discover installed kernels that have build headers.
KERNELS=()
for builddir in /lib/modules/*/build; do
  kver=$(basename "$(dirname "$builddir")")
  if [[ -d "$builddir" ]]; then
    KERNELS+=("$kver")
  else
    echo "Skipping $kver: headers missing ($builddir is a broken link)"
  fi
done

if [[ ${#KERNELS[@]} -eq 0 ]]; then
  echo "No kernels with headers found under /lib/modules. Nothing to do." 2>&1
  exit 1
fi

echo "Target kernels: ${KERNELS[*]}"

# Refresh the DKMS source tree so it matches this checkout.
dkms remove -m ${DRV_NAME} -v ${DRV_VERSION} --all >/dev/null 2>&1 || true
rm -rf "${SRC_DIR}"
cp -r . "${SRC_DIR}"

dkms add -m ${DRV_NAME} -v ${DRV_VERSION} || exit $?

FAILED=()
for kver in "${KERNELS[@]}"; do
  echo "=== Building for $kver ==="
  if dkms build -m ${DRV_NAME} -v ${DRV_VERSION} -k "$kver" \
    && dkms install -m ${DRV_NAME} -v ${DRV_VERSION} -k "$kver"; then
    echo "=== Installed for $kver ==="
  else
    echo "!!! Failed for $kver (see /var/lib/dkms/${DRV_NAME}/${DRV_VERSION}/build/make.log)" 2>&1
    FAILED+=("$kver")
  fi
done

echo "Finished running dkms install steps."
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "Failed kernels: ${FAILED[*]}" 2>&1
  exit 1
fi
exit 0
