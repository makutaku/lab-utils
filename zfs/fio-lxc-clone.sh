#!/usr/bin/env bash
# ------------------------------------------
# fio-lxc-clone.sh  —  micro-benchmark that
# approximates pct clone --full on ZFS
#
# • Requires:  apt install fio
# • Run as root (needs zfs create/destroy)
#
# Tunables (env vars or edit below):
#   DATASET   – temporary ZFS dataset to create
#   SIZE      – total data written (e.g. 4G)
#   RUNTIME   – seconds to run if you prefer time-bound
#   BS        – block size per write (4k mimics rsync)
# ------------------------------------------

set -euo pipefail

DATASET="${DATASET:-rpool/bench_clone}"
SIZE="${SIZE:-4G}"
RUNTIME="${RUNTIME:-60}"
BS="${BS:-4k}"

echo "== fio clone-style benchmark =="
echo "  dataset : $DATASET"
echo "  size    : $SIZE"
echo "  runtime : $RUNTIME s"
echo "  block   : $BS"

# create a unique mountpoint under /mnt
MOUNTPOINT=$(mktemp -d /mnt/bench-XXXX)

cleanup() {
  echo "Cleaning up..."
  zfs destroy -r "$DATASET" 2>/dev/null || true
  rmdir "$MOUNTPOINT" 2>/dev/null || true
}
trap cleanup EXIT

# create throw-away dataset
if zfs list -H "$DATASET" >/dev/null 2>&1; then
  echo "Dataset $DATASET already exists. Delete it first." >&2
  exit 1
fi
zfs create -o mountpoint="$MOUNTPOINT" "$DATASET"

# run fio (sync, direct I/O, 4 KiB writes, single thread)
fio --name=lxc_clone_sim \
    --directory="$MOUNTPOINT" \
    --size="$SIZE" \
    --rw=write \
    --bs="$BS" \
    --ioengine=sync \
    --direct=1 \
    --numjobs=1 \
    --runtime="$RUNTIME" \
    --time_based \
    --group_reporting

# cleanup handled by trap

