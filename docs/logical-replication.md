# PostgreSQL Logical Replication Lab — 12 Hands-on Challenges

**Status:** 12 of 12 challenges completed  
**Date completed:** November 17, 2026  
**PostgreSQL version:** 17.11

> This document records a hands-on logical replication lab. It is a learning and portfolio artifact, not a production deployment guide. Replace `<PUBLISHER_HOST>`, `<SUBSCRIBER_HOST>`, and `<SUBSCRIBER_IP>` with values from your own environment. Actual IP addresses, passwords, and other secrets are intentionally excluded.

## 1. Lab architecture

| Component | Publisher | Subscriber |
|---|---|---|
| Database | `suta_shop` | `perf_lab` |
| PostgreSQL port | `5432` | `5434` |
| Host/IP | `<PUBLISHER_HOST>` | `<SUBSCRIBER_HOST>` |
| Publication | `employee_pub` | — |
| Subscription | — | `employee_sub` |
| Replication role | `replicator` | Uses publisher login |
| Schema | `logi_repli` | `logi_repli` |

**Replication flow:**

```text
Publisher: suta_shop (`<PUBLISHER_HOST>:5432`)
  └── Publication: employee_pub
        ├── logi_repli.employees
        ├── logi_repli.departments
        └── logi_repli.projects
                  |
                  | Logical replication connection
                  | role: replicator
                  v
Subscriber: perf_lab (`<SUBSCRIBER_HOST>:5434`)
  └── Subscription: employee_sub
        ├── logi_repli.employees
        ├── logi_repli.departments
        └── logi_repli.projects
```

The subscriber tables were created separately with matching definitions. PostgreSQL logical replication copies table data and applies supported row changes; it does **not** automatically replicate table DDL, indexes, constraints, or schema changes.

## 2. Connection and security setup

### Publisher prerequisites

The publisher was configured to listen on the required network interface and port. The subscriber's address was allowed through the host firewall, and the publisher's `pg_hba.conf` included a SCRAM-authenticated rule for the replication login from `<SUBSCRIBER_IP>/32`.

Example `pg_hba.conf` rule (authentication secret is not included):

```conf
host    suta_shop    replicator    SUBSCRIBER_HOST/32    scram-sha-256
```

The replication role requires `LOGIN` and `REPLICATION`, and `SELECT` permission on each published table, plus `USAGE` on the schema:

```sql
-- Run on the publisher as an appropriately privileged role.
CREATE ROLE replicator WITH LOGIN REPLICATION;

GRANT USAGE ON SCHEMA logi_repli TO replicator;

GRANT SELECT ON
    logi_repli.employees,
    logi_repli.departments,
    logi_repli.projects
TO replicator;
```

If the role already exists, do not run `CREATE ROLE` again. Apply only the required grants.

### Subscriber password-file setup

The subscriber used a password file owned by the PostgreSQL operating-system account:

```text
/var/lib/pgsql/.pgpass
```

The file was secured with owner-only permissions:

```bash
chmod 600 /var/lib/pgsql/.pgpass
```

The file's contents are deliberately omitted from this document. Never commit `.pgpass`, passwords, connection secrets, or credential-bearing connection strings to Git.

The subscription connection was configured to use the password-file path rather than storing a password in the SQL command:

```sql
ALTER SUBSCRIPTION employee_sub
CONNECTION 'host=PUBLISHER_HOST port=5432 dbname=suta_shop user=replicator passfile=/var/lib/pgsql/.pgpass';
```

The PostgreSQL server process must be able to read the passfile under its operating-system account, and the file must have secure permissions.

## 3. Publication and subscription configuration

### Publisher: create the publication

The publication was configured for INSERT, UPDATE, DELETE, and TRUNCATE operations:

```sql
CREATE PUBLICATION employee_pub
FOR TABLE logi_repli.employees
WITH (
    publish = 'insert, update, delete, truncate'
);
```

The other tables were added during the lab:

```sql
ALTER PUBLICATION employee_pub
ADD TABLE logi_repli.departments;

ALTER PUBLICATION employee_pub
ADD TABLE logi_repli.projects;
```

### Subscriber: create the subscription

The subscriber tables were created first with compatible definitions. The subscription was then created using the publisher connection details and publication:

```sql
CREATE SUBSCRIPTION employee_sub
CONNECTION 'host=PUBLISHER_HOST port=5432 dbname=suta_shop user=replicator passfile=/var/lib/pgsql/.pgpass'
PUBLICATION employee_pub;
```

If a subscription already exists, inspect it before attempting to create it again.

### Important initial-sync behavior

When a table is added to a publication and the subscriber refreshes the publication, PostgreSQL performs initial table synchronization. In `pg_subscription_rel`, state `d` means data copy is in progress and state `r` means the table is ready/replicating. The initial copy requires the publisher connection role to have `SELECT` permission.

## 4. How to run this lab safely

### Identify which side to use

- **Publisher SQL:** connect to database `suta_shop` on the publisher PostgreSQL instance.
- **Subscriber SQL:** connect to database `perf_lab` on the subscriber PostgreSQL instance.
- **Linux commands:** run on the indicated Linux server, using the PostgreSQL operating-system account when required.
- Do not run publisher-only commands on the subscriber or vice versa.

Example connection commands (replace host placeholders with your own private addresses):

```bash
# Connect to the publisher
psql -h <PUBLISHER_HOST> -p 5432 -U <DBA_USER> -d suta_shop

# Connect to the subscriber
psql -h <SUBSCRIBER_HOST> -p 5434 -U <DBA_USER> -d perf_lab
```

If the database is local to the machine where `psql` runs, `-h` may be omitted. These commands intentionally use a DBA login placeholder; do not put passwords directly on the command line.

### Baseline checks before testing

Run on the publisher:

```sql
SELECT version(), current_database(), inet_server_port();
SHOW wal_level;

SELECT pubname
FROM pg_publication
WHERE pubname = 'employee_pub';
```

Run on the subscriber:

```sql
SELECT version(), current_database(), inet_server_port();

SELECT subname, subenabled, subslotname
FROM pg_subscription
WHERE subname = 'employee_sub';
```

Expected baseline:
- Publisher database is `suta_shop`.
- Subscriber database is `perf_lab`.
- Publisher `wal_level` is `logical`.
- Publication `employee_pub` exists.
- Subscription `employee_sub` exists and is enabled before normal replication tests.

### Important safety rules

1. Perform conflict injection, subscription disablement, service stops, and authentication-failure tests only in a lab environment.
2. Before stopping PostgreSQL, confirm the data directory and service/instance name. Do not copy a data-directory path from another server without verifying it.
3. Never place a real password in a SQL script, shell history, Git repository, screenshot, or chat.
4. Keep `.pgpass` outside the repository, owned by the PostgreSQL operating-system account, with mode `0600`.
5. A subscription connection string may reveal hostnames, usernames, database names, or file paths. Sanitize diagnostic output before publishing it.
6. Do not manually modify subscriber rows in production to resolve conflicts without an approved reconciliation procedure.

## 5. The 12 completed challenges

### Challenge 1 — INSERT replication

**Goal:** Prove that an inserted publisher row is applied on the subscriber.

Publisher test:

```sql
INSERT INTO logi_repli.employees (id, name, department)
VALUES (9, 'Sarah', 'Database Engineering');
```

Subscriber verification:

```sql
SELECT *
FROM logi_repli.employees
WHERE id = 9;
```

**Result:** The subscriber received employee `9` automatically.

**What this proves:** The publication and subscription were active and INSERT changes were being applied.

### Challenge 2 — UPDATE replication

**Goal:** Verify that an UPDATE on the publisher reaches the subscriber.

Publisher test:

```sql
UPDATE logi_repli.employees
SET department = 'Senior PostgreSQL DBA'
WHERE id = 9;
```

Subscriber verification:

```sql
SELECT *
FROM logi_repli.employees
WHERE id = 9;
```

**Result:** The subscriber showed the updated department.

**What this proves:** UPDATE changes were replicated for the published table.

### Challenge 3 — DELETE replication

**Goal:** Verify DELETE behavior.

Publisher test:

```sql
DELETE FROM logi_repli.employees
WHERE id = 9;
```

Subscriber verification:

```sql
SELECT *
FROM logi_repli.employees
WHERE id = 9;
```

**Result:** The subscriber returned zero rows for ID `9`.

**What this proves:** DELETE changes were replicated.

### Challenge 4 — Add a table to an existing publication

**Goal:** Add `departments` after the subscription already exists.

Publisher:

```sql
ALTER PUBLICATION employee_pub
ADD TABLE logi_repli.departments;
```

On the subscriber, create the matching table definition before refreshing the publication. Then run:

```sql
ALTER SUBSCRIPTION employee_sub REFRESH PUBLICATION;
```

Check synchronization state:

```sql
SELECT
    sr.srrelid::regclass AS table_name,
    sr.srsubstate AS sync_state
FROM pg_subscription_rel AS sr
JOIN pg_subscription AS s
  ON s.oid = sr.srsubid
WHERE s.subname = 'employee_sub'
ORDER BY 1;
```

During the test, the initial synchronization did not complete because the publisher login lacked `SELECT` permission. The issue was corrected on the publisher:

```sql
GRANT SELECT ON logi_repli.departments TO replicator;
```

**Result:** The table moved to state `r`, and the subscriber received the existing department rows (IDs `1` and `2`). A later test added ID `3` (`Cloud Engineering`).

**What this proves:** Adding a table requires a matching subscriber table, publication refresh, and publisher-side SELECT permission for initial table synchronization.

### Challenge 5 — Monitor replication lag

**Goal:** Inspect the logical replication slot and subscriber apply progress.

Publisher query:

```sql
SELECT
    slot_name,
    active,
    restart_lsn,
    confirmed_flush_lsn,
    pg_size_pretty(
        pg_wal_lsn_diff(
            pg_current_wal_lsn(),
            confirmed_flush_lsn
        )::bigint
    ) AS unacknowledged_wal_distance
FROM pg_replication_slots
WHERE slot_name = 'employee_sub';
```

Subscriber query:

```sql
SELECT
    subname,
    pid,
    received_lsn,
    latest_end_lsn,
    latest_end_time
FROM pg_stat_subscription
WHERE subname = 'employee_sub';
```

**Result:** During the checks, the subscriber's received and latest-end LSNs matched, and the publisher's slot was active. The measured WAL distance was small (56 bytes in one check).

**What this proves:** These views help assess worker health and WAL acknowledgement progress. LSN distance is a byte distance, not a direct measurement of elapsed-time lag.

### Challenge 6 — Disable and re-enable the subscription

**Goal:** Demonstrate that changes made while the subscription is disabled can be applied after it is enabled again.

Subscriber:

```sql
ALTER SUBSCRIPTION employee_sub DISABLE;
```

Check the worker:

```sql
SELECT subname, pid
FROM pg_stat_subscription
WHERE subname = 'employee_sub';
```

While disabled, a new publisher row was inserted into `departments`:

```sql
INSERT INTO logi_repli.departments (id, name)
VALUES (3, 'Cloud Engineering');
```

Re-enable on the subscriber:

```sql
ALTER SUBSCRIPTION employee_sub ENABLE;
```

Verify:

```sql
SELECT *
FROM logi_repli.departments
ORDER BY id;
```

**Result:** The worker restarted and ID `3` appeared on the subscriber.

**What this proves:** The logical slot retained the required changes while the subscription was disabled, allowing the subscriber to catch up when re-enabled.

### Challenge 7 — Troubleshoot a duplicate-key conflict

**Goal:** Simulate a subscriber-side conflicting row and recover the apply worker.

A conflicting row was inserted manually on the subscriber:

```sql
-- Subscriber test only
INSERT INTO logi_repli.departments (id, name)
VALUES (4, 'Conflicting Department');
```

A different row with the same primary key was then inserted on the publisher:

```sql
-- Publisher
INSERT INTO logi_repli.departments (id, name)
VALUES (4, 'Security Engineering');
```

The subscriber apply worker stopped applying changes because the incoming INSERT violated the subscriber's primary key constraint. The error was confirmed in the subscriber PostgreSQL logs.

The conflicting test row was removed on the subscriber:

```sql
-- Subscriber test only
DELETE FROM logi_repli.departments
WHERE id = 4;
```

The worker retried and applied the publisher's row.

**Result:** The subscriber contained ID `4` with `Security Engineering`.

**What this proves:** Logical replication does not silently resolve all data conflicts. Diagnose the error, reconcile the subscriber data carefully, and verify that the apply worker recovers. Avoid manual conflict changes on production systems without an approved reconciliation plan.

### Challenge 8 — Troubleshoot a missing subscriber table

**Goal:** Demonstrate what happens when a publication includes a table that does not yet exist on the subscriber.

Publisher:

```sql
CREATE TABLE logi_repli.projects (
    id   integer PRIMARY KEY,
    name text NOT NULL
);

INSERT INTO logi_repli.projects (id, name)
VALUES
    (1, 'PostgreSQL Migration'),
    (2, 'AWS Database Platform');

ALTER PUBLICATION employee_pub
ADD TABLE logi_repli.projects;
```

The first subscriber refresh failed because the corresponding relation did not exist. The matching table was then created on the subscriber:

```sql
CREATE TABLE logi_repli.projects (
    id   integer PRIMARY KEY,
    name text NOT NULL
);
```

Refresh again:

```sql
ALTER SUBSCRIPTION employee_sub REFRESH PUBLICATION;
```

The initial sync required publisher-side SELECT permission:

```sql
-- Publisher
GRANT SELECT ON logi_repli.projects TO replicator;
```

Verify on the subscriber:

```sql
SELECT *
FROM logi_repli.projects
ORDER BY id;
```

**Result:** Synchronization reached state `r`, and both original project rows appeared.

**What this proves:** Logical replication does not create subscriber table DDL. Create compatible target objects before refreshing the publication, and ensure the publisher connection role has the required SELECT permission.

### Challenge 9 — Demonstrate WAL retention while the subscriber is disabled

**Goal:** Observe how a logical replication slot retains WAL needed by a disconnected/disabled subscriber.

Disable the subscription on the subscriber:

```sql
ALTER SUBSCRIPTION employee_sub DISABLE;
```

On the publisher, insert a batch of 100 rows:

```sql
INSERT INTO logi_repli.projects (id, name)
SELECT
    n,
    'WAL Retention Test ' || n
FROM generate_series(100, 199) AS n;
```

Inspect the slot on the publisher:

```sql
SELECT
    slot_name,
    active,
    restart_lsn,
    confirmed_flush_lsn,
    pg_size_pretty(
        pg_wal_lsn_diff(
            pg_current_wal_lsn(),
            restart_lsn
        )::bigint
    ) AS wal_distance_from_restart_lsn
FROM pg_replication_slots
WHERE slot_name = 'employee_sub';
```

Re-enable the subscription:

```sql
ALTER SUBSCRIPTION employee_sub ENABLE;
```

Verify the batch on the subscriber:

```sql
SELECT count(*) AS replicated_rows,
       min(id) AS first_id,
       max(id) AS last_id
FROM logi_repli.projects
WHERE id BETWEEN 100 AND 199;
```

**Result:** The slot became inactive while the subscription was disabled. The retained WAL distance increased to approximately 15 kB during the test. After re-enabling, all 100 rows arrived and the slot became active again; the measured distance returned to approximately 56 bytes.

**What this proves:** A logical replication slot can retain WAL needed by a subscriber that is temporarily not consuming changes. Long outages can cause WAL accumulation and disk pressure. Monitor slot activity and retained WAL, and do not drop a slot without confirming its purpose and ownership.

**LSN terminology:**
- `restart_lsn`: oldest WAL position that might still be required by the slot.
- `confirmed_flush_lsn`: publisher WAL position the logical consumer has acknowledged.
- An LSN difference is a byte-distance estimate; it is not an exact measure of physical disk space consumed.

### Challenge 10 — Recover after the subscriber server is unavailable

**Goal:** Stop the subscriber PostgreSQL instance, generate publisher changes during the outage, then restart and verify catch-up.

On the subscriber Linux host, as the PostgreSQL operating-system account, the lab instance was stopped:

```bash
/usr/pgsql-17/bin/pg_ctl stop \
  -D /opt/pgsql/data \
  -m fast
```

On the publisher, three rows were inserted during the outage:

```sql
INSERT INTO logi_repli.projects (id, name)
VALUES
    (200, 'Subscriber Outage Test 1'),
    (201, 'Subscriber Outage Test 2'),
    (202, 'Subscriber Outage Test 3');
```

Restart the subscriber instance:

```bash
/usr/pgsql-17/bin/pg_ctl start \
  -D /opt/pgsql/data \
  -l /var/lib/pgsql/pg17-startup.log
```

Connect to the subscriber database on port `5434` and verify:

```sql
SELECT *
FROM logi_repli.projects
WHERE id BETWEEN 200 AND 202
ORDER BY id;
```

**Result:** All three rows arrived after the subscriber restarted.

**What this proves:** The logical slot retained the changes during the subscriber outage, and the subscription resumed applying them after service recovery.

### Challenge 11 — Troubleshoot a publisher authentication failure

**Goal:** Simulate invalid credentials without exposing or committing any real password.

A temporary test password file was created on the subscriber with deliberately invalid credentials. The original password file was backed up securely, and the subscription connection was temporarily pointed to the test file. The actual file contents and credentials are intentionally not documented.

The worker stopped connecting. The subscriber logs showed an authentication failure for the `replicator` login, and `pg_stat_subscription` showed a NULL worker PID during the failure.

The subscription was restored to the original protected password-file path:

```sql
ALTER SUBSCRIPTION employee_sub
CONNECTION 'host=PUBLISHER_HOST port=5432 dbname=suta_shop user=replicator passfile=/var/lib/pgsql/.pgpass';
```

The worker restarted. A publisher recovery test row was inserted:

```sql
INSERT INTO logi_repli.projects (id, name)
VALUES (203, 'Authentication Recovery Test');
```

Subscriber verification:

```sql
SELECT *
FROM logi_repli.projects
WHERE id = 203;
```

The temporary test files were removed after recovery. The original `.pgpass` remained owned by the PostgreSQL OS account with mode `0600`.

**Result:** The worker reconnected and row `203` replicated successfully.

**What this proves:** Authentication problems can prevent the apply worker from connecting. Check the PostgreSQL logs, role/password configuration, passfile path, file ownership, and permissions. Restore the known-good secret source and verify replication with a new test transaction.

**Security reminder:** Never print, paste into chat, or commit the contents of `.pgpass`. Keep all real secrets outside source control.

### Challenge 12 — Build a complete replication monitoring report

**Goal:** Collect a final health snapshot from both publisher and subscriber.

#### Step 1: Publication configuration — publisher

```sql
SELECT
    pubname,
    puballtables,
    pubinsert,
    pubupdate,
    pubdelete,
    pubtruncate
FROM pg_publication
WHERE pubname = 'employee_pub';
```

Observed configuration: `employee_pub`, not an all-tables publication; INSERT, UPDATE, DELETE, and TRUNCATE enabled.

#### Step 2: Published tables — publisher

```sql
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'employee_pub'
ORDER BY schemaname, tablename;
```

Observed tables:
- `logi_repli.departments`
- `logi_repli.employees`
- `logi_repli.projects`

#### Step 3: Subscription configuration — subscriber

```sql
SELECT
    subname,
    subenabled,
    subslotname,
    subpublications,
    subconninfo
FROM pg_subscription
WHERE subname = 'employee_sub';
```

Observed: subscription enabled, slot `employee_sub`, publication `{employee_pub}`, connecting to publisher `PUBLISHER_HOST:5432`, database `suta_shop`, login `replicator`, and passfile path `/var/lib/pgsql/.pgpass`. No password was stored in the displayed connection information.

#### Step 4: Apply worker and received LSN — subscriber

```sql
SELECT
    subname,
    pid,
    received_lsn,
    latest_end_lsn,
    latest_end_time
FROM pg_stat_subscription
WHERE subname = 'employee_sub';
```

Observed at the time of the report:
- Worker PID: `1451379`
- `received_lsn`: `0/2F7E28A0`
- `latest_end_lsn`: `0/2F7E28A0`
- `latest_end_time`: `2026-11-17 11:07:49.167389-05`

#### Step 5: Per-table synchronization state — subscriber

```sql
SELECT
    sr.srrelid::regclass AS table_name,
    sr.srsubstate AS sync_state
FROM pg_subscription_rel AS sr
JOIN pg_subscription AS s
  ON s.oid = sr.srsubid
WHERE s.subname = 'employee_sub'
ORDER BY 1;
```

Observed: `employees`, `departments`, and `projects` were all in state `r`.

#### Step 6: Replication slot health — publisher

```sql
SELECT
    slot_name,
    slot_type,
    active,
    restart_lsn,
    confirmed_flush_lsn,
    pg_size_pretty(
        pg_wal_lsn_diff(
            pg_current_wal_lsn(),
            restart_lsn
        )::bigint
    ) AS wal_distance_from_restart_lsn
FROM pg_replication_slots
WHERE slot_name = 'employee_sub';
```

Observed: logical slot `employee_sub` was active. At that snapshot, the estimated distance from current WAL to `restart_lsn` was approximately 56 bytes.

#### Step 7: Final unacknowledged WAL distance — publisher

```sql
SELECT
    slot_name,
    active,
    pg_current_wal_lsn() AS current_wal_lsn,
    confirmed_flush_lsn,
    pg_size_pretty(
        pg_wal_lsn_diff(
            pg_current_wal_lsn(),
            confirmed_flush_lsn
        )::bigint
    ) AS unacknowledged_wal_distance
FROM pg_replication_slots
WHERE slot_name = 'employee_sub';
```

Final observed result:

| Field | Value |
|---|---|
| `slot_name` | `employee_sub` |
| `active` | `true` |
| `current_wal_lsn` | `0/2F7E29A8` |
| `confirmed_flush_lsn` | `0/2F7E29A8` |
| `unacknowledged_wal_distance` | `0 bytes` |

**Result:** The slot was active and the current publisher WAL LSN matched the subscriber-confirmed LSN at the time of the check. There was no unacknowledged WAL distance in this snapshot.

**Interpretation caution:** This is an instantaneous LSN-distance check, not a measurement of replication delay in seconds. The publisher can generate new WAL immediately after the query. For a more consistent snapshot, capture the current WAL LSN once in a CTE and compare against that value.

## 6. Monitoring reference — what to check first

| View or catalog | Where | What it tells the DBA |
|---|---|---|
| `pg_publication` | Publisher | Publication settings and enabled change types |
| `pg_publication_tables` | Publisher | Tables included in each publication |
| `pg_replication_slots` | Publisher | Slot type, active state, restart LSN, confirmed flush LSN |
| `pg_stat_replication` | Publisher | WAL sender connection statistics; useful for physical replication and sender-side connection monitoring |
| `pg_subscription` | Subscriber | Subscription configuration, enabled state, publication names, connection information |
| `pg_stat_subscription` | Subscriber | Apply worker PID, received LSN, latest end LSN and timestamp |
| `pg_subscription_rel` | Subscriber | Per-table initial synchronization state |
| PostgreSQL server logs | Both | Authentication, permissions, missing relation, duplicate-key, worker and connection errors |

### Practical troubleshooting sequence

When subscriber data is not current:

1. On the subscriber, check whether the subscription is enabled in `pg_subscription`.
2. Check `pg_stat_subscription` for an apply worker PID and received progress.
3. Check `pg_subscription_rel` to see whether every table is ready (`r`).
4. On the publisher, check whether the publication includes the table.
5. On the publisher, inspect `pg_replication_slots` for slot activity and WAL positions.
6. Review subscriber logs for apply errors; review publisher logs for connection/authentication errors.
7. Verify publisher-side SELECT privileges and the subscriber table definition.
8. After correcting the cause, verify that the worker is running and that a controlled test transaction reaches the subscriber.

## 7. Interview-ready explanation

**Question: How do you troubleshoot PostgreSQL logical replication when changes are not appearing on the subscriber?**

**Answer:**

"I first check whether the subscription is enabled and whether the apply worker is running by querying `pg_stat_subscription`. Then I check the publication and its table list on the publisher, and verify each table's synchronization state in `pg_subscription_rel`.

Next, I inspect `pg_replication_slots` on the publisher to confirm that the logical slot is active and to review its WAL positions. If the worker is not running or changes are not applying, I check the PostgreSQL logs for errors such as duplicate-key conflicts, missing subscriber tables, insufficient SELECT privileges, or authentication failures.

After fixing the root cause, I confirm that the apply worker has restarted and verify that a new test transaction is visible on the subscriber."

### Short version

"I check the subscription worker, publication table list, per-table sync state, replication slot, and PostgreSQL logs. I fix the underlying issue—such as permissions, missing tables, data conflicts, or authentication—and then verify that the subscriber catches up."

## 8. Key lessons from this lab

- Logical replication is publication/subscription based and operates at the table level.
- Subscriber table definitions must be managed separately; DDL is not automatically replicated.
- Initial table synchronization needs publisher-side SELECT privileges.
- A logical replication slot retains WAL needed by the subscriber; a disabled or offline subscriber can increase WAL retention.
- Duplicate-key conflicts can stop apply progress until the conflict is reconciled.
- Authentication and network problems can prevent the apply worker from connecting.
- Monitor both worker progress on the subscriber and slot/WAL state on the publisher.
- LSN distance is useful for estimating byte backlog, but it is not the same as time-based replication lag.
- Always protect credentials and avoid exposing secrets in shell output, logs, screenshots, or Git history.

## 9. Lab completion checklist

- [x] 1. INSERT replication
- [x] 2. UPDATE replication
- [x] 3. DELETE replication
- [x] 4. Add a table to an existing publication
- [x] 5. Monitor replication progress and WAL distance
- [x] 6. Disable and re-enable the subscription
- [x] 7. Troubleshoot a duplicate-key conflict
- [x] 8. Troubleshoot a missing subscriber table
- [x] 9. Demonstrate WAL retention while the subscriber is disabled
- [x] 10. Recover after subscriber outage
- [x] 11. Troubleshoot authentication failure and restore connectivity
- [x] 12. Produce a complete monitoring report



## 10. Challenge review: DBA reasoning and interview practice

Use this section to explain not only which command you ran, but also what the result means.

| Challenge | DBA reasoning to demonstrate | Interview practice question |
|---:|---|---|
| 1 — INSERT | Confirm that a committed publisher INSERT is delivered to the subscriber through the publication and apply worker. | How do you prove INSERT changes are being logically replicated? |
| 2 — UPDATE | Explain that UPDATE replication requires a usable row identity on the publisher, normally a primary key or replica identity. | What does PostgreSQL use to identify the row being updated or deleted? |
| 3 — DELETE | Verify that the matching subscriber row is removed after the publisher DELETE is committed. | How would you troubleshoot a DELETE that does not appear on the subscriber? |
| 4 — Add publication table | Explain publication membership, subscriber-side DDL preparation, `REFRESH PUBLICATION`, initial table synchronization, and publisher-side SELECT permission. | What steps are required to add a table to an existing logical subscription? |
| 5 — Monitor progress | Distinguish subscriber worker progress from publisher slot acknowledgement and explain why an LSN byte distance is not a time-based lag measurement. | Which views do you use to monitor logical replication? |
| 6 — Disable/enable | Explain that disabling the subscription stops apply activity while the logical slot can retain required WAL for later catch-up. | What happens to publisher changes while a subscription is disabled? |
| 7 — Duplicate-key conflict | Explain how a conflicting subscriber row can stop apply progress and why the data must be reconciled before the worker can continue. | What happens when the subscriber already has a row with the incoming primary key? |
| 8 — Missing subscriber table | Explain that logical replication does not create subscriber DDL and that each published table needs a compatible target relation. | Does PostgreSQL logical replication replicate CREATE TABLE statements? |
| 9 — WAL retention | Explain `restart_lsn`, `confirmed_flush_lsn`, slot inactivity, WAL retention, and disk-capacity risk. | What is the operational risk of an inactive logical replication slot? |
| 10 — Subscriber outage | Explain that the publisher can continue generating changes while the subscriber is unavailable, provided required WAL remains available through the slot. | How does a logical subscriber catch up after an outage? |
| 11 — Authentication failure | Explain how connection authentication, passfile ownership, permissions, and PostgreSQL logs help isolate a worker connection failure. | How do you troubleshoot a logical replication worker that cannot authenticate? |
| 12 — Monitoring report | Bring publication, subscription, worker, table-sync, and slot information together into one health assessment. | What would you include in a logical replication health report? |

### Key catalog and view reference

| Catalog/view | Query location | Main purpose |
|---|---|---|
| `pg_publication` | Publisher | Publication configuration and published operation types |
| `pg_publication_tables` | Publisher | Tables included in publications |
| `pg_replication_slots` | Publisher | Logical slot state and WAL positions |
| `pg_stat_replication` | Publisher | WAL sender connection statistics; interpret it alongside logical-slot information |
| `pg_subscription` | Subscriber | Subscription configuration and enabled state |
| `pg_stat_subscription` | Subscriber | Apply worker PID and received progress |
| `pg_subscription_rel` | Subscriber | Per-table synchronization state |
| PostgreSQL server logs | Both | Worker, connection, authentication, permission, and apply errors |

### Important logical replication limitations

- DDL changes are not automatically replicated. Coordinate schema changes on publisher and subscriber.
- Sequences are not replicated as ordinary table changes. Plan sequence synchronization separately during migrations or failover.
- Large objects are not replicated by built-in logical replication.
- The subscriber can be writable, but local writes to replicated tables can create conflicts with incoming publisher changes.
- A logical replication slot can retain WAL indefinitely if its consumer stops advancing. Monitor storage and slot health.
- Built-in logical replication is not a substitute for backups or a complete disaster-recovery strategy.

**Final status: 12/12 challenges completed.**
