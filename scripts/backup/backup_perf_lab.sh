#!/bin/bash

# PostgreSQL configuration
DB_NAME="perf_lab"
DB_PORT="5434"
DB_USER="postgres"

# Backup configuration
BACKUP_DIR="/pgBACKUP/daily"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${DATE}.dump"
LOG_FILE="/var/lib/pgsql/backup_perf_lab.log"

echo "====================================" >> "$LOG_FILE"
echo "Backup started: $(date)" >> "$LOG_FILE"

# Execute PostgreSQL backup
if pg_dump -p "$DB_PORT" -U "$DB_USER" \
   -d "$DB_NAME" -Fc -f "$BACKUP_FILE" >> "$LOG_FILE" 2>&1
then
    echo "SUCCESS: $BACKUP_FILE" >> "$LOG_FILE"
else
    echo "ERROR: Backup failed for $DB_NAME" >> "$LOG_FILE"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Remove backups older than 7 days
find "$BACKUP_DIR" -type f \
    -name "${DB_NAME}_*.dump" -mtime +7 -delete

echo "Backup finished: $(date)" >> "$LOG_FILE"
