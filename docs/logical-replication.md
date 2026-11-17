# PostgreSQL Logical Replication

## 1. Overview

PostgreSQL logical replication copies selected table changes from a publisher to a subscriber. It is useful for selective data distribution, reporting, migrations, and integration between PostgreSQL databases.

Logical replication uses a publisher/subscriber model:

- **Publisher:** source database that exposes changes through a publication.
- **Publication:** publisher-side definition of the tables and operations to replicate.
- **Subscriber:** destination database that receives changes.
- **Subscription:** subscriber-side configuration that connects to a publication and applies changes.

Logical replication uses WAL and logical decoding to produce a stream of row-level changes.

## 2. Architecture and data flow

```text
Application
    |
    v
Publisher database
    |
    | INSERT / UPDATE / DELETE
    v
WAL -> logical decoding
    |
    v
Logical replication connection
    |
    v
Subscriber apply process
    |
    v
Subscriber database
```

For a new subscription with initial table synchronization, PostgreSQL first copies the existing rows for the subscribed tables and then continuously applies subsequent changes.

## 3. Logical replication vs. physical replication

| Feature | Logical replication | Physical streaming replication |
|---|---|---|
| Replication level | Logical row changes | WAL at the storage/cluster level |
| Scope | Selected tables | Entire PostgreSQL cluster |
| Architecture | Publisher and subscriber | Primary and standby |
| Selective table replication | Yes | No |
| Cross-major-version replication | Supported between compatible versions, subject to documented restrictions | Normally requires the same major version |
| Initial data | Table synchronization or preloaded data | Base backup |
| DDL replication | No | DDL is included in WAL |
| Sequence state | Not replicated automatically | Replicated through WAL |
| Typical use | Migration, integration, selective reporting | HA and disaster recovery |

## 4. Prerequisites and important behavior

- Set `wal_level = logical` on the publisher.
- Configure sufficient `max_replication_slots` and `max_wal_senders`.
- Ensure the subscriber can reach the publisher over TCP.
- Create the target database and matching table definitions on the subscriber.
- The subscription connection user needs `LOGIN` and `REPLICATION`, and must have the required `SELECT` privileges on published tables for initial table synchronization.
- For UPDATE and DELETE, tables normally need a primary key or an explicitly configured replica identity.
- DDL, sequence state, and large objects are not replicated by built-in logical replication.
- Logical replication is asynchronous by default.
- A replication slot can retain WAL while a subscriber is disconnected. Monitor retained WAL to avoid filling the publisher's disk.

## 5. Hands-on lab: PostgreSQL 17

This example uses two PostgreSQL 17 instances. Adjust hostnames, ports, database names, and paths to match the lab environment.

| Role | Host | Port | Database |
|---|---|---:|---|
| Publisher | `PUBLISHER_IP` | 5432 | `source_db` |
| Subscriber | `SUBSCRIBER_IP` | 5433 | `target_db` |

### Step 1: Configure the publisher

In the publisher's `postgresql.conf`:

```ini
wal_level = logical
max_replication_slots = 10
max_wal_senders = 10
```

Restart PostgreSQL after changing `wal_level`. A reload is sufficient for settings that PostgreSQL marks as reloadable, but use a restart for this configuration change.

Check the settings:

```sql
SHOW wal_level;
SHOW max_replication_slots;
SHOW max_wal_senders;
```

### Step 2: Create a replication login on the publisher

Run on the publisher:

```sql
CREATE ROLE replicator
WITH LOGIN REPLICATION PASSWORD 'REPLACE_WITH_A_STRONG_PASSWORD';

GRANT CONNECT ON DATABASE source_db TO replicator;
```

Connect to `source_db` and grant access to the table(s) that will be published. For this lab:

```sql
GRANT USAGE ON SCHEMA public TO replicator;
GRANT SELECT ON TABLE public.employees TO replicator;
```

For future tables, grant appropriate privileges explicitly or configure suitable default privileges for the table owner.

### Step 3: Configure publisher `pg_hba.conf`

Add an entry allowing the subscriber host to connect to `source_db`:

```conf
host    source_db    replicator    SUBSCRIBER_IP/32    scram-sha-256
```

Reload the publisher configuration:

```sql
SELECT pg_reload_conf();
```

Confirm network access and firewall/security-group rules allow the subscriber to reach the publisher on TCP port 5432. Use TLS in production where required by the security design.

### Step 4: Create and populate the publisher table

On the publisher, connect to `source_db`:

```sql
CREATE TABLE public.employees (
    id           integer PRIMARY KEY,
    name         varchar(100) NOT NULL,
    department   varchar(100)
);

INSERT INTO public.employees (id, name, department) VALUES
    (1, 'John', 'IT'),
    (2, 'Mary', 'Finance'),
    (3, 'David', 'HR');
```

### Step 5: Create a publication

On the publisher:

```sql
CREATE PUBLICATION employee_pub
FOR TABLE public.employees;
```

To publish all eligible tables instead:

```sql
-- Alternative example; do not run both examples unless intended.
CREATE PUBLICATION all_tables_pub
FOR ALL TABLES;
```

A publication can also specify operations:

```sql
CREATE PUBLICATION employee_insert_pub
FOR TABLE public.employees
WITH (publish = 'insert');
```

### Step 6: Prepare the subscriber table

Create `target_db` on the subscriber if it does not already exist, then connect to it:

```sql
CREATE TABLE public.employees (
    id           integer PRIMARY KEY,
    name         varchar(100) NOT NULL,
    department   varchar(100)
);
```

The table schema is not automatically created by logical replication. The target table must exist and have compatible columns and data types. The subscriber table should normally have the same column names and compatible types. Do not assume indexes, constraints, triggers, or DDL changes are copied from the publisher.

### Step 7: Create a subscription

Run on the subscriber while connected to `target_db`:

```sql
CREATE SUBSCRIPTION employee_sub
CONNECTION 'host=PUBLISHER_IP port=5432 dbname=source_db user=replicator password=REPLACE_WITH_A_STRONG_PASSWORD'
PUBLICATION employee_pub;
```

By default, PostgreSQL creates a replication slot on the publisher and performs an initial copy of the publisher table's existing rows. Protect credentials appropriately; avoid leaving production passwords in shell history, scripts, or source control.

### Step 8: Verify the data

On the subscriber:

```sql
SELECT * FROM public.employees ORDER BY id;
```

The initial rows (John, Mary, and David) should appear.

Insert a new row on the publisher:

```sql
INSERT INTO public.employees (id, name, department)
VALUES (4, 'Peter', 'Operations');
```

Then query the subscriber again:

```sql
SELECT * FROM public.employees ORDER BY id;
```

Peter's row should arrive after the asynchronous apply process catches up.

Test UPDATE and DELETE as well:

```sql
-- Publisher
UPDATE public.employees
SET department = 'Platform'
WHERE id = 4;

DELETE FROM public.employees
WHERE id = 3;
```

Verify the results on the subscriber.

## 6. Monitoring and troubleshooting

### Publisher: replication slots

```sql
SELECT
    slot_name,
    slot_type,
    plugin,
    database,
    active,
    restart_lsn,
    confirmed_flush_lsn
FROM pg_replication_slots;
```

For logical replication, look for a logical slot associated with the subscription. An inactive slot may still retain WAL.

### Publisher: replication connections

```sql
SELECT
    pid,
    usename,
    application_name,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn
FROM pg_stat_replication;
```

Logical replication connections can be identified by their replication activity and application name. This view shows connected walsender processes; it does not by itself provide a complete per-table apply-lag report.

### Subscriber: subscription workers

```sql
SELECT
    subname,
    pid,
    relid,
    received_lsn,
    latest_end_lsn,
    latest_end_time
FROM pg_stat_subscription;
```

A row with `relid` set can represent a table synchronization worker; the main apply worker has a null `relid`.

### Subscriber: table synchronization state

```sql
SELECT
    srsubid,
    srrelid::regclass AS table_name,
    srsubstate,
    srsublsn
FROM pg_subscription_rel;
```

The synchronization state helps identify tables that have not completed their initial copy.

### Common troubleshooting checks

1. **Subscription is not connecting:** check `pg_hba.conf`, password, DNS, routing, firewall rules, and whether the publisher is listening on the expected address and port.
2. **Initial copy fails:** check the replication user's `SELECT` privileges, target table compatibility, constraints, and subscriber logs.
3. **UPDATE or DELETE fails:** verify that the publisher table has a primary key or suitable replica identity and that the subscriber can identify the target row.
4. **Subscriber falls behind:** inspect subscription worker status, server logs, network health, long-running transactions, and apply workload.
5. **Publisher disk usage grows:** inspect inactive replication slots and retained WAL. Do not drop a slot until its purpose and subscriber recovery plan are understood.

## 7. Operational considerations and limitations

- Logical replication does not replicate DDL changes. Apply schema changes to the subscriber using a controlled deployment process.
- Sequence values are not kept synchronized by logical replication. Plan and synchronize sequences separately during migrations or cutovers.
- Large objects are not replicated by built-in logical replication.
- Built-in logical replication does not provide automatic conflict resolution for arbitrary multi-writer designs. Avoid treating a normal subscription as a bidirectional replication solution.
- A subscriber can be used for read workloads, but consider apply lag and consistency requirements.
- Replication slots retain WAL needed by subscribers. Monitor slot activity and retained WAL, and define a recovery procedure for abandoned subscriptions.
- Plan failover and switchover carefully. A logical subscriber is not automatically a physical HA standby.

## 8. Interview explanation

**Question: What is logical replication, and when would you use it?**

"Logical replication allows me to replicate selected tables from one PostgreSQL database to another. On the source, I create a publication. On the destination, I create a subscription that connects to that publication. PostgreSQL uses logical decoding to capture row changes from WAL and the subscriber applies those changes.

I would use it for selective data migration, reporting, and data integration when I do not need to replicate the entire database cluster. I also plan separately for schema changes, sequence synchronization, replication lag, and replication-slot WAL retention."

## 9. Practice checklist

- [ ] Configure `wal_level = logical`.
- [ ] Create a replication login and configure `pg_hba.conf`.
- [ ] Create a publication for one table.
- [ ] Create a publication for multiple tables.
- [ ] Create a subscriber table and subscription.
- [ ] Verify initial table synchronization.
- [ ] Test INSERT, UPDATE, and DELETE.
- [ ] Add a table to an existing publication and subscription.
- [ ] Monitor `pg_stat_replication`, `pg_replication_slots`, and `pg_stat_subscription`.
- [ ] Stop the subscriber and observe slot activity and WAL retention.
- [ ] Troubleshoot a failed subscription and document recovery steps.

## 10. Official PostgreSQL documentation

- [Logical Replication](https://www.postgresql.org/docs/17/logical-replication.html)
- [Logical Replication Publications](https://www.postgresql.org/docs/17/logical-replication-publication.html)
- [Logical Replication Subscriptions](https://www.postgresql.org/docs/17/logical-replication-subscription.html)
- [Logical Replication Monitoring](https://www.postgresql.org/docs/17/monitoring-stats.html)
