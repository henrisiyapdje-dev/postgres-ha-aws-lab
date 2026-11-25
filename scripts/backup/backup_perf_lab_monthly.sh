#!/bin/bash

# PostgreSQL configuration
DB_NAME="perf_lab"
DB_PORT="5434"
DB_USER="postgres"

# Monthly backup configuration
BACKUP_DIR="/pgBACKUP/monthly"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_monthly_${DATE}.dump"
LOG_FILE="/var/lib/pgsql/backup_perf_lab_monthly.log"

echo "====================================" >> "$LOG_FILE"
echo "Monthly backup started: $(date)" >> "$LOG_FILE"

# Execute PostgreSQL backup
if pg_dump -p "$DB_PORT" -U "$DB_USER" \
   -d "$DB_NAME" -Fc -f "$BACKUP_FILE" >> "$LOG_FILE" 2>&1
then
    echo "SUCCESS: $BACKUP_FILE" >> "$LOG_FILE"
else
    echo "ERROR: Monthly backup failed for $DB_NAME" >> "$LOG_FILE"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Remove monthly backups older than 365 days
find "$BACKUP_DIR" -type f \
    -name "${DB_NAME}_monthly_*.dump" -mtime +365 -delete

echo "Monthly backup finished: $(date)" >> "$LOG_FILE"
