#!/usr/bin/env bash
# detect_empty_nvme.sh
#
# Function: find_empty_nvme
#   Emit lines in the form "<device>\t<by‑id‑link>" for every NVMe disk
#   that has **no partitions**.
#   Returns 0 if at least one such disk exists, 1 otherwise.
#
# Usage example (at bottom of file):
#   source detect_empty_nvme.sh
#   mapfile -t empty_nvmes < <(find_empty_nvme) && printf '%s\n' "${empty_nvmes[@]}"

###############################################################################
find_empty_nvme() {
    local found=0

    _print() {                 # <device> -> "<device>\t<by‑id link>"
        local dev="$1" link=""
        for l in /dev/disk/by-id/*; do
            [[ -e $l ]] || continue
            [[ $(readlink -f "$l") == "$dev" ]] && { link="$l"; break; }
        done
        printf '%s\t%s\n' "$dev" "${link:-<no-by-id-link>}"
    }

    if command -v jq >/dev/null 2>&1; then
        lsblk -J -o NAME,TYPE |
        jq -r '
            .blockdevices[]
            | select(.type=="disk" and .name|test("^nvme"))
            | select(.children==null)
            | "/dev/"+.name
        ' | while read -r dev; do
            _print "$dev"
            found=1
        done
    else
        lsblk -dn -o NAME,TYPE |
        awk '$2=="disk" && $1 ~ /^nvme/ {print "/dev/"$1}' |
        while read -r dev; do
            [[ $(lsblk -n "$dev" | wc -l) -eq 1 ]] && { _print "$dev"; found=1; }
        done
    fi

    return $((found == 0))
}
###############################################################################

# --- Example invocation (remove if sourcing in another script) --------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if mapfile -t empty_nvmes < <(find_empty_nvme); then
        echo "Empty NVMe disks:"
        printf '  %s\n' "${empty_nvmes[@]}"
    else
        echo "No empty NVMe disks."
    fi
fi

