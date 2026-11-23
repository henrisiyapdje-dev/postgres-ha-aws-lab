

\# PostgreSQL Backup Automation with Cron



\## 1. Overview



This project demonstrates automated PostgreSQL database backups using `pg\_dump`, Bash scripts, and Linux cron.



The automation supports three backup schedules:



\- Daily backups

\- Weekly backups

\- Monthly backups



The scripts run under the Linux `postgres` account.



\## 2. Lab Environment



| Component | Configuration |

|---|---|

| Operating System | CentOS Stream 9 |

| PostgreSQL Version | 17.11 |

| Database | perf\_lab |

| PostgreSQL Port | 5434 |

| Backup User | postgres |

| Backup Location | /pgBACKUP |

| Backup Format | Custom (`pg\_dump -Fc`) |



\## 3. Directory Structure



```text

/pgBACKUP/

├── daily/

├── weekly/

└── monthly/

```



The backup scripts and log files are stored under:



```text

/var/lib/pgsql/

├── backup\_perf\_lab.sh

├── backup\_perf\_lab\_weekly.sh

├── backup\_perf\_lab\_monthly.sh

├── backup\_perf\_lab.log

├── backup\_perf\_lab\_weekly.log

└── backup\_perf\_lab\_monthly.log

```



\## 4. Backup Schedule



The PostgreSQL backup jobs are configured using the postgres user's crontab.



| Backup Type | Schedule | Retention |

|---|---|---|

| Daily | Every day at 2:00 AM | 7 days |

| Weekly | Every Sunday at 3:00 AM | 28 days |

| Monthly | First day of each month at 4:00 AM | 365 days |



Cron configuration:



```cron

\# Daily backup at 2:00 AM

0 2 \* \* \* /var/lib/pgsql/backup\_perf\_lab.sh



\# Weekly backup every Sunday at 3:00 AM

0 3 \* \* 0 /var/lib/pgsql/backup\_perf\_lab\_weekly.sh



\# Monthly backup on the first day at 4:00 AM

0 4 1 \* \* /var/lib/pgsql/backup\_perf\_lab\_monthly.sh

```



\## 5. Backup Implementation



All three scripts use `pg\_dump` with the custom archive format (`-Fc`).



Example:



```bash

pg\_dump -p 5434 -U postgres \\

&#x20;   -d perf\_lab \\

&#x20;   -Fc \\

&#x20;   -f "$BACKUP\_FILE"

```



The scripts:



1\. Generate timestamped backup filenames.

2\. Execute the PostgreSQL backup.

3\. Record success or failure in log files.

4\. Remove incomplete backup files after a failure.

5\. Apply retention policies to older backup files.



See the scripts in `scripts/backup/`.



\## 6. Retention Policies



Each backup script automatically removes older backup files.



Daily:



```bash

find "$BACKUP\_DIR" -type f \\

&#x20;   -name "${DB\_NAME}\_\*.dump" -mtime +7 -delete

```



Weekly:



```bash

find "$BACKUP\_DIR" -type f \\

&#x20;   -name "${DB\_NAME}\_weekly\_\*.dump" -mtime +28 -delete

```



Monthly:



```bash

find "$BACKUP\_DIR" -type f \\

&#x20;   -name "${DB\_NAME}\_monthly\_\*.dump" -mtime +365 -delete

```



\## 7. Backup Monitoring and Validation



Backup logs are maintained separately for each schedule.



Example:



```bash

tail -n 30 /var/lib/pgsql/backup\_perf\_lab.log

```



Validate a backup archive:



```bash

pg\_restore --list /pgBACKUP/daily/perf\_lab\_YYYYMMDD\_HHMMSS.dump

```



A successful archive listing confirms that PostgreSQL can read the archive's table of contents. It does not replace a restore test.



\## 8. Restore Testing



A clean test database was created:



```bash

createdb -p 5434 -U postgres perf\_lab\_full\_restore\_test

```



The backup was restored using:



```bash

pg\_restore -v -p 5434 -U postgres \\

&#x20;   -d perf\_lab\_full\_restore\_test \\

&#x20;   --no-owner \\

&#x20;   --no-privileges \\

&#x20;   --no-subscriptions \\

&#x20;   /pgBACKUP/daily/perf\_lab\_YYYYMMDD\_HHMMSS.dump

```



The restore completed successfully.



The restored database was checked for schemas, tables, data, indexes, sequences, and constraints.



The subscription was intentionally excluded from this test restore.



\## 9. Important Operational Considerations



\- The Linux VM must be running when cron jobs are scheduled.

\- PostgreSQL must be available for `pg\_dump` to connect.

\- The cron daemon must be running.

\- The backup filesystem must have sufficient free space.

\- Backup files should be protected with appropriate Linux permissions.

\- A successful backup job should be followed by periodic restore testing.

\- Production backups should also be copied to separate or off-site storage.



\## 10. DBA Takeaways



This project demonstrates practical experience with:



\- PostgreSQL logical backups using `pg\_dump`.

\- Custom-format backup archives.

\- Linux Bash scripting.

\- Cron-based job scheduling.

\- Backup retention management.

\- Backup logging and error handling.

\- Archive validation using `pg\_restore`.

\- Full database restore testing.



\## 11. Project Repository



Backup scripts and cron configuration:



```text

scripts/backup/

├── backup\_perf\_lab.sh

├── backup\_perf\_lab\_weekly.sh

├── backup\_perf\_lab\_monthly.sh

└── postgres-backup.cron

```
