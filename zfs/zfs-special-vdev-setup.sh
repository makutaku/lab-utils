#!/usr/bin/env bash
# zfs-special-vdev-setup.sh  —  2‑way special‑vdev version
# Adds to an existing pool:
#   • 20 GB SLOG          (Optane‑part1)
#   • 2‑way 90 GB special mirror  (Optane‑part2  +  T500‑part1)
#   • L2ARC               (T500‑part2)

###############################################################################
# CLI:  POOL  OPTANE_ID  T500_ID   [options]
# Options:
#   -n | --dry-run        Print commands but do not execute
#   -v | --verbose        Extra progress logging
#   -c | --confirm-each   Ask y/N/a before each modifying command
###############################################################################

set -euo pipefail

# ─── Parse flags ────────────────────────────────────────────────────────────
DRY_RUN=false VERBOSE=false CONFIRM=false
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)       DRY_RUN=true ;;
    -v|--verbose)       VERBOSE=true ;;
    -c|--confirm-each)  CONFIRM=true ;;
    -h|--help)
cat <<EOF
Usage: $0 [options] POOL OPTANE_ID T500_ID
Options:
  -n, --dry-run        Show commands without executing them
  -v, --verbose        Extra progress logging
  -c, --confirm-each   Ask y/N/a before each change (a = abort)
EOF
      exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *)  POSITIONAL+=("$1") ;;
  esac
  shift
done
[[ ${#POSITIONAL[@]} -eq 3 ]] || {
  echo "ERROR: need POOL  OPTANE_ID  T500_ID"; exit 1; }

POOL="${POSITIONAL[0]}"
OPTANE_ID="${POSITIONAL[1]}"
T500_ID="${POSITIONAL[2]}"

# ─── Path helpers ───────────────────────────────────────────────────────────
ensure_path() { [[ $1 == /dev/* ]] && printf '%s\n' "$1" || printf '/dev/disk/by-id/%s\n' "$1"; }
optane=$(ensure_path "$OPTANE_ID")
t500=$(ensure_path "$T500_ID")
for p in "$optane" "$t500"; do [[ -e $p ]] || { echo "ERROR: '$p' not found"; exit 1; }; done
part() { echo "$1-part$2"; }                  # part <disk> <N>

# ─── Logging helpers ────────────────────────────────────────────────────────
LOGFILE="zfs_setup_${POOL}_$(date +%F_%H%M%S).log"
log()  { echo "[$(date '+%F %T')] $*" | tee -a "$LOGFILE"; }
logv() { $VERBOSE && log "$*"; }
run() {
  local cmd="$*"
  if $DRY_RUN; then log "[dry-run] $cmd"; return; fi
  if $CONFIRM; then
    while true; do
      read -rp "Execute: $cmd ? [y/N/a] " r
      case $r in [Yy]) break ;;
        [Nn]|"" ) log "Skipped: $cmd"; return ;;
        [Aa]) log "Aborted by user."; exit 0 ;;
        *) echo "Please answer y, n, or a." ;;
      esac
    done
  fi
  log "$cmd"; eval "$cmd"
}

log "=== ZFS vdev setup (2‑way special mirror) for pool '$POOL' ==="

# ─── Plan summary ───────────────────────────────────────────────────────────
printf '\nDevices:\n  Optane : %s\n  T500   : %s\n\n' \
       "$optane" "$t500" | tee -a "$LOGFILE"
$VERBOSE && cat <<PLAN | tee -a "$LOGFILE"
Vdevs to add:
  • SLOG             : $(part $optane 1)
  • SPECIAL mirror-2 : $(part $optane 2)   +   $(part $t500 1)
  • L2ARC            : $(part $t500 2)
PLAN

read -rp "Proceed? [y/N] " ans
[[ $ans =~ ^[Yy]$ ]] || { log "Aborted by user."; exit 0; }

# ─── Partitioning (bf07 = Solaris reserved) ────────────────────────────────
logv "=== Partitioning ==="
run sudo sgdisk --zap-all "$optane"
run sudo sgdisk -n1:0:+20G -t1:bf07 -c1:"${POOL}_slog" \
                -n2:0:+90G -t2:bf07 -c2:"${POOL}_special0" "$optane"
run sudo sgdisk --zap-all "$t500"
run sudo sgdisk -n1:0:+90G -t1:bf07 -c1:"${POOL}_special_$(basename "$t500")" \
                -n2:0:0    -t2:bf07 -c2:"${POOL}_l2arc_$(basename "$t500")" "$t500"

# ─── Add vdevs ──────────────────────────────────────────────────────────────
logv "=== Adding vdevs ==="
ASHIFT='-o ashift=12'
run sudo zpool add $ASHIFT "$POOL" log   "$(part "$optane" 1)"
run sudo zpool add          "$POOL" special mirror \
          "$(part "$optane" 2)"  "$(part "$t500" 1)"
run sudo zpool add          "$POOL" cache \
          "$(part "$t500" 2)"

# ─── Pool properties ────────────────────────────────────────────────────────
logv "=== Setting pool properties ==="
run sudo zfs set special_small_blocks=32K "$POOL"

# ─── Verify ────────────────────────────────────────────────────────────────
logv "=== Final status ==="
run sudo zpool status -v "$POOL"
run sudo zpool iostat -v 1
log "Completed — log saved to $LOGFILE"

