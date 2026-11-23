

# PostgreSQL Backup Scheduling with Linux Cron



## 1. Overview



Linux cron is a time-based job scheduler used to execute commands and scripts automatically at scheduled intervals.



In this lab, cron automates PostgreSQL daily, weekly, and monthly backups.



All backup jobs run under the Linux `postgres` account.



## 2. Environment



| Component | Configuration |
|---|---|
| Operating System | CentOS Stream 9 |
| PostgreSQL Version | 17.11 |
| Database | perf_lab |
| PostgreSQL Port | 5434 |
| Linux Account | postgres |
| Scheduler | Linux cron |



## 3. Configure the PostgreSQL Crontab



Edit the crontab for the PostgreSQL operating system account:



```bash

sudo crontab -u postgres -e

```



List the configured jobs:



```bash

sudo crontab -u postgres -l

```



## 4. Cron Syntax



A cron entry contains five time fields followed by the command to execute.



```text

Minute Hour Day Month Weekday Command

```



| Field | Allowed values | Description |
|---|---|---|
| Minute | 0–59 | Minute of the hour |
| Hour | 0–23 | Hour of the day |
| Day | 1–31 | Day of the month |
| Month | 1–12 | Month of the year |
| Weekday | 0–7 | Day of the week (Sunday is 0 or 7) |



The asterisk (`*`) means every valid value for that field.



## 5. PostgreSQL Backup Schedule



The following jobs are configured in the PostgreSQL user's crontab.



### Daily backup



Runs every day at 2:00 AM.



```cron

0 2 * * * /var/lib/pgsql/backup_perf_lab.sh

```



### Weekly backup



Runs every Sunday at 3:00 AM.



```cron

0 3 * * 0 /var/lib/pgsql/backup_perf_lab_weekly.sh

```



### Monthly backup



Runs on the first day of every month at 4:00 AM.



```cron

0 4 1 * * /var/lib/pgsql/backup_perf_lab_monthly.sh

```



## 6. Complete Crontab Configuration



```cron

# Daily backup at 2:00 AM

0 2 * * * /var/lib/pgsql/backup_perf_lab.sh



# Weekly backup every Sunday at 3:00 AM

0 3 * * 0 /var/lib/pgsql/backup_perf_lab_weekly.sh



# Monthly backup on the first day at 4:00 AM

0 4 1 * * /var/lib/pgsql/backup_perf_lab_monthly.sh

```



## 7. Verify Cron Configuration



List the PostgreSQL user's scheduled jobs:



```bash

sudo crontab -u postgres -l

```



Check whether the cron daemon is running:



```bash

ps -ef | grep '[c]rond'

```



Check cron-related messages:



```bash

sudo grep CRON /var/log/cron | tail -n 30

```



## 8. Verify Backup Execution



Inspect the daily backup log:



```bash

tail -n 30 /var/lib/pgsql/backup_perf_lab.log

```



Inspect the weekly backup log:



```bash

tail -n 30 /var/lib/pgsql/backup_perf_lab_weekly.log

```



Inspect the monthly backup log:



```bash

tail -n 30 /var/lib/pgsql/backup_perf_lab_monthly.log

```



List generated backup files:



```bash

ls -lh /pgBACKUP/daily/

ls -lh /pgBACKUP/weekly/

ls -lh /pgBACKUP/monthly/

```



## 9. Troubleshooting Considerations



If a scheduled backup does not execute, check:



1. Is the Linux VM running?

2. Is the cron daemon running?

3. Is the PostgreSQL database available?

4. Do the scripts have executable permissions?

5. Does the `postgres` account have access to the backup directories?

6. Is there enough free disk space?

7. Do the backup logs contain errors?



Important: Cron does not automatically catch up on jobs missed while the VM is powered off or suspended.



## 10. Important DBA Considerations



- Use the dedicated PostgreSQL operating system account to execute backup jobs.

- Keep backup scripts executable and protected with appropriate permissions.

- Monitor backup logs regularly.

- Validate backup archives with `pg_restore --list`.

- Perform periodic restore tests.

- Keep backup copies on separate or off-site storage for production environments.

- Consider time zone and daylight-saving changes when scheduling jobs.



## 11. Repository Structure



```text

docs/

└── maintenance/

    ├── postgresql-backup-automation.md

    ├── postgresql-cron-scheduling.md

    └── postgresql-table-index-bloat.md



scripts/

└── backup/

    ├── backup_perf_lab.sh

    ├── backup_perf_lab_weekly.sh

    ├── backup_perf_lab_monthly.sh

    └── postgres-backup.cron

```



## 12. DBA Takeaways



This exercise demonstrates practical experience with:



- Linux cron scheduling.

- PostgreSQL backup automation.

- Managing scheduled jobs under a dedicated Linux account.

- Monitoring cron execution and backup logs.

- Troubleshooting missed scheduled jobs.

- Maintaining reliable database backup operations.
