#!/bin/bash
#
# Install the rtl8821ce driver via DKMS.
#
# Usage: sudo ./dkms-install.sh [-k <kernel-version>]
# Bare: all kernels with headers. -k: only the given kernel.

set -u
shopt -s nullglob

usage() {
  cat <<EOF
Usage: sudo ./dkms-install.sh [-k <kernel-version>]

  With no options, install for every kernel with headers installed.
  -k <kernel-version>  operate only on the given kernel
  -h                   show this help and exit
EOF
}

TARGET_KVER=""
while getopts ":k:h" opt; do
  case "$opt" in
    k) TARGET_KVER="$OPTARG" ;;
    h) usage; exit 0 ;;
    :) echo "Option -$OPTARG requires an argument." 2>&1; usage >&2; exit 1 ;;
    \?) echo "Unknown option: -$OPTARG" 2>&1; usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
if [[ $# -gt 0 ]]; then
  echo "Unexpected argument: $1" 2>&1; usage >&2; exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "You must run this with superuser privileges.  Try \"sudo ./dkms-install.sh\"" 2>&1
  exit 1
fi

DRV_NAME=rtl8821ce
DRV_VERSION=v5.5.2_34066.20200325
SRC_DIR=/usr/src/${DRV_NAME}-${DRV_VERSION}

echo "About to run dkms install steps..."

# -k targets one kernel, otherwise every kernel with build headers.
KERNELS=()
if [[ -n "$TARGET_KVER" ]]; then
  if [[ ! -d "/lib/modules/${TARGET_KVER}/build" ]]; then
    echo "Error: kernel '${TARGET_KVER}' not found or headers missing (/lib/modules/${TARGET_KVER}/build)." 2>&1
    exit 1
  fi
  KERNELS=("$TARGET_KVER")
else
  for builddir in /lib/modules/*/build; do
    kver=$(basename "$(dirname "$builddir")")
    if [[ -d "$builddir" ]]; then
      KERNELS+=("$kver")
    else
      echo "Skipping $kver: headers missing ($builddir is a broken link)"
    fi
  done
fi

if [[ ${#KERNELS[@]} -eq 0 ]]; then
  echo "No kernels with headers found under /lib/modules. Nothing to do." 2>&1
  exit 1
fi

echo "Target kernels: ${KERNELS[*]}"

# Refresh the DKMS source tree. -k clears only that kernel's build.
if [[ -n "$TARGET_KVER" ]]; then
  dkms remove -m ${DRV_NAME} -v ${DRV_VERSION} -k "$TARGET_KVER" >/dev/null 2>&1 || true
else
  dkms remove -m ${DRV_NAME} -v ${DRV_VERSION} --all >/dev/null 2>&1 || true
fi
rm -rf "${SRC_DIR}"
cp -r . "${SRC_DIR}"

# Re-add only if unregistered (per-kernel remove keeps registration).
if ! dkms status -m ${DRV_NAME} -v ${DRV_VERSION} 2>/dev/null | grep -q .; then
  dkms add -m ${DRV_NAME} -v ${DRV_VERSION} || exit $?
fi

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
