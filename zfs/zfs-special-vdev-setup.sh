#!/usr/bin/env bash
# zfs-special-vdev-setup.sh
# Adds SLOG + 3‑way special mirror + striped L2ARC to an existing pool.

set -euo pipefail

###############################################################################
# 0. CLI parsing – required POOL + optional flags
###############################################################################
DRY_RUN=false VERBOSE=false
declare -a ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=true ;;
    -v|--verbose) VERBOSE=true ;;
    -h|--help)
cat <<EOF
Usage: $0 [--dry-run|-n] [--verbose|-v] POOL
  POOL            Existing ZFS pool to extend  (required)
  -n, --dry-run   Log the actions but do not execute them
  -v, --verbose   Extra progress logging
EOF
      exit 0 ;;
    --) shift; break ;;
    -*)
      echo "Unknown option: $1" >&2; exit 1 ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
[[ ${#ARGS[@]} -eq 1 ]] || { echo "ERROR: POOL name is required."; exit 1; }
POOL="${ARGS[0]}"

###############################################################################
# 1. Logging helpers
###############################################################################
LOGFILE="zfs_setup_${POOL}_$(date +%F_%H%M%S).log"
log()  { echo "[$(date '+%F %T')] $*" | tee -a "$LOGFILE"; }
logv() { $VERBOSE && log "$*"; }
run()  { $DRY_RUN && log "[dry‑run] $*" || { log "$*"; eval "$*"; }; }

log "=== ZFS vdev setup script started (pool: $POOL) ==="

###############################################################################
# 2. Device‑detection helpers
###############################################################################
find_by_model() {
  local pattern="$1" want="${2:-1}"
  mapfile -t matches < <(ls -1 /dev/disk/by-id | grep -iE "nvme-.*(${pattern})" || true)
  local i; for ((i=0; i<want && i<${#matches[@]}; i++)); do
    printf '/dev/disk/by-id/%s\n' "${matches[$i]}"
  done
}

# Optane may be labelled “Optane” or by product code SSDPEK1A*
optane=$(find_by_model 'Optane|SSDPEK1A' 1)
# Crucial drives: match “T500” anywhere in the id
mapfile -t t500 < <(find_by_model 'T500' 2)

if [[ -z $optane || ${#t500[@]} -ne 2 ]]; then
  log "ERROR: Did not detect required drives."
  log " Optane found : ${optane:-<none>}"
  log " T500 matches : ${t500[*]:-<none>}"
  exit 1
fi

t500A=${t500[0]}
t500B=${t500[1]}

###############################################################################
# 3. Show detected devices
###############################################################################
printf '\nDetected devices for pool "%s":\n' "$POOL" | tee -a "$LOGFILE"
printf '  Optane           : %s\n' "$optane"  | tee -a "$LOGFILE"
printf '  Crucial T500 (A) : %s\n' "$t500A"   | tee -a "$LOGFILE"
printf '  Crucial T500 (B) : %s\n\n' "$t500B" | tee -a "$LOGFILE"

if $VERBOSE; then
  printf 'Planned vdev additions:\n' | tee -a "$LOGFILE"
  printf '  LOG (SLOG)        -> %s p1 (20 GB)\n' "$optane" | tee -a "$LOGFILE"
  printf '  SPECIAL 3‑mirror  -> %s p2, %s p1, %s p1 (90 GB)\n' \
         "$optane" "$t500A" "$t500B" | tee -a "$LOGFILE"
  printf '  L2ARC (striped)   -> %s p2 + %s p2\n' \
         "$t500A" "$t500B" | tee -a "$LOGFILE"
  $DRY_RUN && printf '  *** DRY‑RUN — no changes will be made ***\n' | tee -a "$LOGFILE"
  echo | tee -a "$LOGFILE"
fi

###############################################################################
# 4. Confirmation
###############################################################################
read -rp "Proceed with these changes? [y/N] " ans
[[ $ans =~ ^[Yy]$ ]] || { log "Aborted by user."; exit 0; }

###############################################################################
# 5. Partition drives – GUIDs 6a04 log | 6a05 special | 6a06 cache
###############################################################################
logv "=== Partitioning devices ==="

log "Partitioning Optane for SLOG + special slice..."
run sudo sgdisk --zap-all "$optane"
run sudo sgdisk \
  -n1:0:+20G -t1:6a04 -c1:"${POOL}_slog" \
  -n2:0:+90G -t2:6a05 -c2:"${POOL}_special0" "$optane"

for d in "$t500A" "$t500B"; do
  log "Partitioning $(basename "$d") for special slice + L2ARC..."
  run sudo sgdisk --zap-all "$d"
  run sudo sgdisk \
    -n1:0:+90G -t1:6a05 -c1:"${POOL}_special_$(basename "$d")" \
    -n2:0:0    -t2:6a06 -c2:"${POOL}_l2arc_$(basename "$d")" "$d"
done

###############################################################################
# 6. Attach vdevs
###############################################################################
logv "=== Adding vdevs to pool ==="
ASHIFT='-o ashift=12'

log "Adding SLOG vdev..."
run sudo zpool add $ASHIFT "$POOL" log   "${optane}p1"

log "Adding 3‑way SPECIAL mirror..."
run sudo zpool add          "$POOL" special mirror \
            "${optane}p2" "${t500A}p1" "${t500B}p1"

log "Adding striped L2ARC cache..."
run sudo zpool add          "$POOL" cache "${t500A}p2" "${t500B}p2"

###############################################################################
# 7. Pool properties
###############################################################################
logv "=== Setting pool properties ==="
run sudo zfs set special_small_blocks=32K "$POOL"
run sudo zfs set compression=lz4 atime=off "$POOL"

###############################################################################
# 8. Verification
###############################################################################
logv "=== Final status ==="
run sudo zpool status -v "$POOL"
run sudo zpool iostat -rw 1

log "Completed — full log saved to $LOGFILE"

