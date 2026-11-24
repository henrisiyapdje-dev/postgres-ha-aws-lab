#!/bin/bash

# PostgreSQL Backup Monitoring Script

DB_NAME="perf_lab"
BACKUP_DIR="/pgBACKUP/daily"
LOG_FILE="/var/lib/pgsql/backup_perf_lab.log"
DISK_THRESHOLD=80
STATUS=0
TODAY=$(date +"%Y%m%d")

echo "===================================="
echo "PostgreSQL Backup Monitoring"
echo "Date: $(date)"
echo "===================================="

# Check today's backup
TODAY_BACKUP=$(find "$BACKUP_DIR" -maxdepth 1 -type f \
    -name "${DB_NAME}_${TODAY}_*.dump" -print -quit)

if [ -n "$TODAY_BACKUP" ]; then
    echo "SUCCESS: Today's backup exists: $TODAY_BACKUP"
else
    echo "WARNING: Today's backup is missing!"
    STATUS=1
fi

echo
echo "Checking backup archive integrity..."

# Verify backup archive readability
if [ -n "$TODAY_BACKUP" ]; then
    if pg_restore -l "$TODAY_BACKUP" >/dev/null 2>&1; then
        echo "SUCCESS: Backup archive is readable."
    else
        echo "ERROR: Backup archive cannot be read!"
        STATUS=1
    fi
else
    echo "SKIPPED: No backup available to verify."
fi

echo
echo "Checking backup disk usage..."

# Check filesystem usage
DISK_USAGE=$(df -P "$BACKUP_DIR" | awk 'NR==2 {gsub(/%/, "", $5); print $5}')

echo "Current disk usage: ${DISK_USAGE}%"

if [ "$DISK_USAGE" -ge "$DISK_THRESHOLD" ]; then
    echo "WARNING: Disk usage has reached the ${DISK_THRESHOLD}% threshold!"
    STATUS=1
else
    echo "SUCCESS: Disk usage is below the threshold."
fi

echo
echo "Checking backup directory size..."

# Report total backup storage
BACKUP_SIZE=$(du -sh /pgBACKUP | awk '{print $1}')

echo "Total backup storage: $BACKUP_SIZE"

echo
echo "Checking today's backup job status..."

# Verify today's backup success entry in the backup log
if [ -n "$TODAY_BACKUP" ]; then
    TODAY_BACKUP_NAME=$(basename "$TODAY_BACKUP")

    if [ -r "$LOG_FILE" ] && awk -v backup="$TODAY_BACKUP_NAME" '
        $1 == "SUCCESS:" && index($0, backup) > 0 { found=1 }
        END { exit !found }
    ' "$LOG_FILE"; then
        echo "SUCCESS: Today's backup job is recorded as successful."
    else
        echo "ERROR: Today's backup job success was not found in the log!"
        STATUS=1
    fi
else
    echo "SKIPPED: No today's backup to match against the log."
fi

echo
echo "Backup monitoring completed: $(date)"

exit "$STATUS"
