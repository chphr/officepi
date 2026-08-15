#!/usr/bin/env bash
#
# Backs up Docker named volumes (actual data) to a local timestamped
# tarball. This is deliberately separate from git — service data
# changes constantly and can be large/sensitive, so it doesn't belong
# in version control. Point BACKUP_DIR at an external drive or add an
# rclone/rsync/restic push at the bottom for offsite copies.

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/pi-homelab-backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$BACKUP_DIR/$STAMP"

mkdir -p "$DEST"

VOLUMES=(adguard_work adguard_conf gophish_data foundry_data)

for VOL in "${VOLUMES[@]}"; do
  echo "Backing up volume: $VOL"
  docker run --rm \
    -v "${VOL}:/data:ro" \
    -v "${DEST}:/backup" \
    alpine \
    tar czf "/backup/${VOL}.tar.gz" -C /data .
done

echo "Backup complete: $DEST"

# --- Optional offsite copy, uncomment and configure as needed ---
# rclone copy "$DEST" remote:pi-homelab-backups/"$STAMP"
