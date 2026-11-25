# PostgreSQL Backup Monitoring and Validation

## 1. Overview

This guide documents a PostgreSQL backup monitoring solution for the `perf_lab` database running on PostgreSQL 17.11.

The monitoring script checks whether the daily backup exists, verifies that the backup archive is readable, monitors backup disk usage, reports total backup storage, and confirms that the backup job was recorded as successful.

## 2. Environment

| Component | Configuration |
|---|---|
| PostgreSQL version | 17.11 |
| Database | `perf_lab` |
| PostgreSQL port | 5434 |
| Linux user | `postgres` |
| Backup mount | `/pgBACKUP` |
| Daily backup directory | `/pgBACKUP/daily` |
| Monitoring script | `/var/lib/pgsql/monitor_backup.sh` |
| Monitoring log | `/var/lib/pgsql/monitor_backup.log` |

## 3. Monitoring Checks

The script performs the following checks:

1. **Backup existence:** Checks whether a daily backup file exists for the current date.
2. **Archive integrity:** Uses `pg_restore -l` to verify that PostgreSQL can read the backup archive's table of contents.
3. **Disk usage:** Checks filesystem usage and warns when it reaches the configured 80% threshold.
4. **Backup storage:** Reports the total size of the `/pgBACKUP` directory.
5. **Backup job status:** Confirms that the daily backup filename appears in the backup log with a successful status.

The script returns exit code `0` when all checks pass and exit code `1` when a monitored condition fails.

**Note:** Archive readability is not a substitute for a complete restore test.

## 4. Monitoring Script

Location:

`/var/lib/pgsql/monitor_backup.sh`

The script is maintained separately from the backup scripts to avoid changing the existing backup process.

## 5. Cron Scheduling

The monitoring job runs daily at 2:15 AM, fifteen minutes after the daily backup starts.
**Scheduling consideration:** Ensure the daily backup completes before the monitoring job starts. If backup duration increases, adjust the monitoring schedule to allow sufficient time.

```cron
# Daily backup
0 2 * * * /var/lib/pgsql/backup_perf_lab.sh

# Daily backup monitoring
15 2 * * * /var/lib/pgsql/monitor_backup.sh >> /var/lib/pgsql/monitor_backup.log 2>&1

# Weekly backup
0 3 * * 0 /var/lib/pgsql/backup_perf_lab_weekly.sh

# Monthly backup
0 4 1 * * /var/lib/pgsql/backup_perf_lab_monthly.sh
```

The monitoring output is appended to:

`/var/lib/pgsql/monitor_backup.log`

## 6. Validation and Test Scenarios

The monitoring script was tested using an isolated test directory before being deployed to its production path.

| Test scenario | Expected result | Actual result |
|---|---|---|
| Daily backup missing | Warning and exit code 1 | Passed |
| Valid backup exists | Success | Passed |
| Backup archive readable | Success | Passed |
| Backup success entry missing from log | Error and exit code 1 | Passed |
| Production monitoring run | All checks successful | Passed |
| Monitoring log creation | Log file created | Passed |

## 7. Production Validation Results

Observed on November 24, 2026:

| Check | Result |
|---|---|
| Daily backup | Found |
| Backup archive | Readable |
| Filesystem usage | 6% |
| Total backup storage | 444 MB |
| Backup job log entry | Successful |
| Monitoring exit code | 0 |

Backup file verified:

`/pgBACKUP/daily/perf_lab_20261124_020001.dump`

## 8. Operational Considerations

- Monitor backup disk usage regularly.
- Review monitoring logs for warnings and errors.
- Keep backup retention policies aligned with recovery requirements.
- Perform periodic restore tests to confirm recoverability.
- Consider off-site backup copies and encryption for production environments.
- Configure alerting so backup failures are not discovered only through manual log reviews.

## 9. Conclusion

This project adds a separate monitoring layer to PostgreSQL backup automation.

It demonstrates backup existence checks, archive readability checks, disk capacity monitoring, backup log validation, cron scheduling, and failure detection using shell scripting.
