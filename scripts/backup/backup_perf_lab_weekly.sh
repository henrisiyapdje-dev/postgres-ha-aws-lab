#!/bin/bash

# PostgreSQL configuration
DB_NAME="perf_lab"
DB_PORT="5434"
DB_USER="postgres"

# Weekly backup configuration
BACKUP_DIR="/pgBACKUP/weekly"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_weekly_${DATE}.dump"
LOG_FILE="/var/lib/pgsql/backup_perf_lab_weekly.log"

echo "====================================" >> "$LOG_FILE"
echo "Weekly backup started: $(date)" >> "$LOG_FILE"

# Execute PostgreSQL backup
if pg_dump -p "$DB_PORT" -U "$DB_USER" \
   -d "$DB_NAME" -Fc -f "$BACKUP_FILE" >> "$LOG_FILE" 2>&1
then
    echo "SUCCESS: $BACKUP_FILE" >> "$LOG_FILE"
else
    echo "ERROR: Weekly backup failed for $DB_NAME" >> "$LOG_FILE"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Remove weekly backups older than 28 days
find "$BACKUP_DIR" -type f \
    -name "${DB_NAME}_weekly_*.dump" -mtime +28 -delete

echo "Weekly backup finished: $(date)" >> "$LOG_FILE"