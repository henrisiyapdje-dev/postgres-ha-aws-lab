# PostgreSQL Point-in-Time Recovery (PITR) and Database Restoration

## 1. Overview

This lab demonstrates how to recover a PostgreSQL database to a specific point in time after accidental data deletion.

The exercise covers:

- Enabling continuous WAL archiving.
- Creating and validating a physical base backup.
- Preparing an isolated recovery instance.
- Simulating accidental data deletion.
- Performing Point-in-Time Recovery (PITR).
- Validating recovered data.
- Restoring the recovered database to the original PostgreSQL instance.

The recovery was performed on a separate PostgreSQL instance to avoid modifying the original instance during PITR.

## 2. Lab Environment

| Component | Configuration |
|---|---|
| Operating system | CentOS Stream 9 |
| PostgreSQL version | 17.11 |
| Original instance | Port 5434 |
| Recovery instance | Port 5435 |
| Original data directory | `/opt/pgsql/data` |
| Recovery data directory | `/pgDATA/pitr_recovery` |
| Base backup directory | `/pgBACKUP/pitr_lab/base_20261124` |
| WAL archive directory | `/pgARCHIVE/pitr_lab` |
| Test database | `pitr_demo` |

PostgreSQL binaries:

```bash
/usr/pgsql-17/bin/

## 3. Configure WAL Archiving

PITR requires a physical base backup and the WAL files generated after that backup.

The original PostgreSQL instance was configured with:

```ini
wal_level = logical
archive_mode = on
archive_command = 'test ! -f /pgARCHIVE/pitr_lab/%f && cp %p /pgARCHIVE/pitr_lab/%f'
archive_timeout = 300

# The WAL archive directory was created and assigned to the PostgreSQL operating-system user.

mkdir -p /pgARCHIVE/pitr_lab

# After applying the configuration, the original PostgreSQL instance was restarted using pg_ctl

/usr/pgsql-17/bin/pg_ctl -D /opt/pgsql/data restart -m fast

# Verify the archiving configuration:

SHOW archive_mode;
SHOW archive_command;
SHOW archive_timeout;

# Check the archiver statistics:

SELECT
    archived_count,
    failed_count,
    last_archived_wal,
    last_archived_time
FROM pg_stat_archiver;


## 4. Create a Physical Base Backup

A physical base backup was created from the original PostgreSQL instance.

```bash
/usr/pgsql-17/bin/pg_basebackup \
    -h 127.0.0.1 \
    -p 5434 \
    -U postgres \
    -D /pgBACKUP/pitr_lab/base_20261124 \
    -F plain \
    -X stream \
    -P

The backup completed successfully.

Because the original configuration files were symbolic links, the actual configuration files were saved separately from:

/opt/pgsql/config_repo/

They were copied into:

/pgBACKUP/pitr_lab/config_20261124/


Validate the base backup

```bash
/usr/pgsql-17/bin/pg_verifybackup \
    /pgBACKUP/pitr_lab/base_20261124

Expected result:
backup successfully verified

## 5. Prepare the Recovery Instance

A separate recovery directory was created:

```bash
mkdir -p /pgDATA/pitr_recovery

The physical backup and saved configuration files were copied into this directory.

The recovery instance was configured to use port 5435, keeping it separate from the original instance on port 5434.

Important recovery settings:
port = 5435
archive_mode = off
archive_command = ''
restore_command = 'cp /pgARCHIVE/pitr_lab/%f %p'


The recovery target was configured as:
recovery_target_time = '2026-11-24 23:25:04.405145-05'
recovery_target_action = 'pause'


The recovery instance used its own pg_hba.conf, with peer authentication for local connections and SCRAM authentication configured for localhost TCP connections.

A recovery.signal file was created in the recovery data directory to instruct PostgreSQL to enter recovery mode.

## 6. Create the Test Database and Data

On the original instance, the test database was created:

```sql
CREATE DATABASE pitr_demo;


Connect to the database:
psql -p 5434 -U postgres -d pitr_demo


Create the test table:
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(150),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


Insert five customer records:
INSERT INTO customers (customer_name, email)
VALUES
    ('John Smith', 'john@example.com'),
    ('Mary Johnson', 'mary@example.com'),
    ('David Brown', 'david@example.com'),
    ('Sarah Wilson', 'sarah@example.com'),
    ('Michael Davis', 'michael@example.com');


Verify the records:
SELECT * FROM customers ORDER BY customer_id;


Five records were present before the simulated incident.

## 7. Capture the Recovery Target Time

The recovery target timestamp was captured before deleting the records:

```sql
SELECT clock_timestamp() AS recovery_target_time;


Captured timestamp:
2026-11-24 23:25:04.405145-05


A WAL switch was requested to help ensure the relevant WAL was archived:
SELECT pg_switch_wal();

## 8. Simulate Accidental Data Deletion

The incident was simulated by deleting all customer records:

```sql
DELETE FROM customers;


Verify that the records were deleted:
SELECT COUNT(*) FROM customers;


Result:
0


The deletion occurred at approximately:
2026-11-24 23:30:37.017222-05


A subsequent WAL switch was requested:
SELECT pg_switch_wal();


The archiver statistics confirmed that WAL files were successfully archived.

## 9. Perform Point-in-Time Recovery

The recovery instance was started with:

```bash
/usr/pgsql-17/bin/pg_ctl \
    -D /pgDATA/pitr_recovery \
    -l /pgDATA/pitr_recovery/recovery.log \
    start


PostgreSQL replayed the archived WAL files and stopped at the configured recovery target.

The recovery logs confirmed:
- A consistent recovery state was reached.
- PostgreSQL became ready for read-only connections.
- Recovery stopped before a transaction committed after the configured target.
- Recovery paused at the end of recovery.
A message indicating that the next WAL segment was unavailable appeared after the target had been reached. In this lab, that message was not a recovery failure.

## 10. Validate the Recovered Database

Connect to the recovery instance:

```bash
psql -p 5435 -U postgres -d pitr_demo


Check the recovery state:
SELECT
    pg_is_in_recovery(),
    pg_is_wal_replay_paused(),
    pg_last_wal_replay_lsn(),
    pg_last_xact_replay_timestamp();


The recovery instance returned:
- pg_is_in_recovery() = true
- pg_is_wal_replay_paused() = true
Verify the recovered customer count:
SELECT COUNT(*) FROM customers;


Result:
5


Verify the customer records:
SELECT
    customer_id,
    customer_name,
    email
FROM customers
ORDER BY customer_id;


All five customer records were recovered successfully.

## 11. Confirm the Original Instance Was Unchanged

Before restoring the recovered database, the original instance was checked separately on port `5434`.

The customer count was still zero.

This confirmed that PITR had been performed on the separate recovery instance without changing the original database.


## 12. Restore the Recovered Database to the Original Instance

The recovered database was exported using `pg_dump` from the recovery instance:

```bash
pg_dump \
    -p 5435 \
    -U postgres \
    -d pitr_demo \
    -F c \
    -f /pgBACKUP/pitr_lab/pitr_demo_recovered.dump

    The dump archive was inspected:
pg_restore -l \
    /pgBACKUP/pitr_lab/pitr_demo_recovered.dump


Before restoring, a backup of the original database was created:
pg_dump \
    -p 5434 \
    -U postgres \
    -d pitr_demo \
    -F c \
    -f /pgBACKUP/pitr_lab/pitr_demo_before_restore.dump


The recovered database was then restored into the original instance:
pg_restore \
    --clean \
    --if-exists \
    --single-transaction \
    --no-owner \
    -p 5434 \
    -U postgres \
    -d pitr_demo \
    /pgBACKUP/pitr_lab/pitr_demo_recovered.dump


The restore completed without errors.
Validate the restored database
Connect to the original instance:
psql -p 5434 -U postgres -d pitr_demo


Verify the records:
SELECT
    customer_id,
    customer_name,
    email
FROM customers
ORDER BY customer_id;


All five customer records were present again on the original instance.
Verify the sequence
SELECT last_value, is_called
FROM customers_customer_id_seq;


The sequence showed:
last_value = 33
is_called = true


The next generated value was 34. Sequence gaps are normal in PostgreSQL and do not indicate a failed restore.
## 13. Final Results

| Validation | Result |
|---|---|
| WAL archiving | Successful |
| Physical base backup | Successful |
| Backup verification | Successful |
| Accidental deletion simulation | Successful |
| PITR on separate instance | Successful |
| Five customer records recovered | Successful |
| Original instance unchanged during PITR | Confirmed |
| Logical dump created | Successful |
| Original database backed up before restore | Successful |
| Recovered database restored to original | Successful |
| Final customer count | 5 |

## 14. Important Production Considerations

This was a controlled lab exercise. Before applying the same approach in production:

- Store base backups and WAL archives on reliable, protected storage.
- Monitor WAL archiving failures and archive storage capacity.
- Regularly validate backups with `pg_verifybackup`.
- Test recovery procedures and measure actual RTO and RPO.
- Protect backup files and restrict access to recovery directories.
- Use appropriate authentication and network restrictions.
- Preserve a backup of the original database before logical restoration.
- Confirm database ownership, privileges, extensions, and dependencies during restoration.
- Document recovery target selection and obtain the required approval before production recovery.

The recovery instance in this lab remained paused in recovery mode and was not promoted. The original instance remained writable.

## 15. Interview Explanation

I configured PostgreSQL WAL archiving and created a physical base backup. I then created a test database, inserted five customer records, and captured a recovery target timestamp.

To simulate an incident, I deleted all five records.

Instead of modifying the original PostgreSQL instance, I restored the base backup into a separate recovery instance and configured Point-in-Time Recovery using the archived WAL files.

PostgreSQL replayed the WAL records and paused at the configured recovery target. I verified that all five customer records were recovered.

Finally, I created a logical dump from the recovered database, backed up the original database, and restored the recovered data into the original instance.

This exercise demonstrated my ability to perform PostgreSQL backup validation, WAL archiving, PITR, recovery verification, and logical database restoration.