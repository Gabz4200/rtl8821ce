#!/bin/bash
#
# Remove the rtl8821ce driver via DKMS.
#
# Usage: sudo ./dkms-remove.sh [-k <kernel-version>]
# Bare: all kernels plus stale state, then drop the source tree.
# -k: only the given kernel, source tree left alone.

set -u
shopt -s nullglob

usage() {
  cat <<EOF
Usage: sudo ./dkms-remove.sh [-k <kernel-version>]

  With no options, remove from every kernel and drop the DKMS source tree.
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
  echo "You must run this with superuser privileges.  Try \"sudo ./dkms-remove.sh\"" 2>&1
  exit 1
fi

DRV_NAME=rtl8821ce
DRV_VERSION=v5.5.2_34066.20200325
SRC_DIR=/usr/src/${DRV_NAME}-${DRV_VERSION}

echo "About to run dkms removal steps..."

# -k targets one kernel, otherwise every kernel under /lib/modules
# (headers not needed for removal) plus stale DKMS entries.
KERNELS=()
if [[ -n "$TARGET_KVER" ]]; then
  KERNELS=("$TARGET_KVER")
else
  for moddir in /lib/modules/*/; do
    kver=$(basename "$moddir")
    KERNELS+=("$kver")
  done

  # Stale entries for kernels whose /lib/modules dir is gone.
  if command -v dkms >/dev/null 2>&1; then
    while IFS= read -r kver; do
      [[ -z "$kver" ]] && continue
      skip=0
      for known in ${KERNELS[@]+"${KERNELS[@]}"}; do
        [[ "$known" == "$kver" ]] && { skip=1; break; }
      done
      [[ $skip -eq 0 ]] && KERNELS+=("$kver")
    done < <(dkms status -m ${DRV_NAME} -v ${DRV_VERSION} 2>/dev/null | awk -F', ' '{ if ($1 ~ /\//) print $2; else print $3 }' | cut -d: -f1 | sort -u)
  fi
fi

if [[ ${#KERNELS[@]} -eq 0 ]]; then
  echo "No kernels found under /lib/modules and none known to DKMS. Nothing to uninstall." 2>&1
else
  echo "Target kernels: ${KERNELS[*]}"
fi

FAILED=()
# A bare "added" status line names no kernel, so match ", <kver>," exactly.
STATUS=$(dkms status -m ${DRV_NAME} -v ${DRV_VERSION} 2>/dev/null || true)
for kver in ${KERNELS[@]+"${KERNELS[@]}"}; do
  if printf '%s\n' "$STATUS" | grep -q -F ", ${kver},"; then
    echo "=== Removing for $kver ==="
    if dkms remove -m ${DRV_NAME} -v ${DRV_VERSION} -k "$kver"; then
      echo "=== Removed for $kver ==="
    else
      echo "!!! Failed to remove for $kver" 2>&1
      FAILED+=("$kver")
    fi
  else
    echo "=== Skipping $kver: not registered with DKMS ==="
  fi
done

# All-kernels mode only: mop up leftovers and drop the source tree.
if [[ -z "$TARGET_KVER" ]]; then
  dkms remove -m ${DRV_NAME} -v ${DRV_VERSION} --all >/dev/null 2>&1 || true
  rm -rf "${SRC_DIR}"
fi

echo "Finished running dkms removal steps."
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "Failed kernels: ${FAILED[*]}" 2>&1
  exit 1
fi
exit 0
