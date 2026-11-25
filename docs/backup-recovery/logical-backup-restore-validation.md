# PostgreSQL Logical Backup and Restore Validation

## 1. Overview

This lab demonstrates how to restore a PostgreSQL logical backup into a separate database and validate the restored database.

The objective is to verify that the restored database contains the expected data, database objects, definitions, ownership, and privileges.

The validation was performed using PostgreSQL 17.11.

## 2. Environment

| Item | Value |
|---|---|
| PostgreSQL version | 17.11 |
| PostgreSQL port | 5434 |
| Source database | `perf_lab` |
| Restore database | `perf_lab_restore_validation` |
| Backup format | Custom (`pg_dump -Fc`) |
| Backup file | `perf_lab_20261125_020001.dump` |
| Backup directory | `/pgBACKUP/daily/` |

The restore was performed into a separate database. The source database was not modified.

## 3. Restore Procedure

### Create the validation database

```sql
CREATE DATABASE perf_lab_restore_validation;
```

### Restore the logical backup

```bash
pg_restore -p 5434 \
  -d perf_lab_restore_validation \
  --no-owner \
  --exit-on-error \
  /pgBACKUP/daily/perf_lab_20261125_020001.dump
```

Options:

- `-p 5434`: Connect to PostgreSQL on port 5434.
- `-d`: Specify the target database.
- `--no-owner`: Do not restore original object ownership commands.
- `--exit-on-error`: Stop immediately if a restore error occurs.

The restore completed without errors.

The restored database size was approximately 249 MB.

## 4. Restore Validation

The source database and restored database were compared.

### 4.1 Database and schema inventory

Four user-defined schemas were present:

- `logi_repli`
- `public`
- `sales`
- `training`

PostgreSQL internal schemas were also present.

### 4.2 Table counts

A total of 12 user tables were verified.

| Schema | Table count |
|---|---:|
| `logi_repli` | 4 |
| `public` | 1 |
| `sales` | 5 |
| `training` | 2 |
| **Total** | **12** |

### 4.3 Row counts

Exact row counts were compared for all 12 tables.

| Table | Expected rows |
|---|---:|
| `logi_repli.departments` | 4 |
| `logi_repli.employees` | 7 |
| `logi_repli.employees_no_pk` | 3 |
| `logi_repli.projects` | 106 |
| `public.hot_update_lab` | 10,000 |
| `sales.customers` | 10,000 |
| `sales.order_items` | 1,500,000 |
| `sales.orders` | 500,000 |
| `sales.performance_test` | 100,000 |
| `sales.products` | 5,000 |
| `training.customers` | 0 |
| `training.orders` | 0 |
| **Total** | **2,125,120** |

All row counts matched between the source and restored databases.

### 4.4 Indexes and constraints

The following object counts matched:

| Object | Count |
|---|---:|
| Indexes | 20 |
| CHECK constraints | 9 |
| FOREIGN KEY constraints | 4 |
| PRIMARY KEY constraints | 11 |
| UNIQUE constraints | 2 |
| **Total constraints** | **26** |

### 4.5 Sequences

All eight sequences were present in both databases.

Sequence definitions, ownership associations, and current values were compared.

Selected sequence values:

| Sequence | Last value |
|---|---:|
| `sales.orders_order_id_seq` | 500,000 |
| `sales.order_items_order_item_id_seq` | 1,500,000 |
| `sales.customers_customer_id_seq` | 10,000 |
| `sales.products_product_id_seq` | 5,000 |
| `sales.performance_test_id_seq` | 100,000 |
| `public.hot_update_lab_id_seq` | 10,000 |

The two training sequences were unused and had NULL last values in both databases.

### 4.6 Extensions and views

The following extensions were present in both databases:

| Extension | Version |
|---|---|
| `pg_stat_statements` | 1.11 |
| `plpgsql` | 1.0 |

The following views also matched:

- `public.pg_stat_statements`
- `public.pg_stat_statements_info`

### 4.7 Column definitions

The `information_schema.columns` comparison returned 104 rows in each database.

The following attributes were compared:

- Schema and table names
- Column names and column order
- Data types
- Nullability
- Default expressions

The results matched.

### 4.8 Ownership and privileges

The following were compared:

- Database ownership
- Schema ownership
- Table ownership
- Database ACLs
- Schema ACLs
- Table privileges

All compared ownership and privilege results matched.

The restore used `--no-owner`, and the restore execution role was `postgres`, which also owned the source user tables.

### 4.9 Additional database objects

The following object categories were checked and matched:

| Object category | Result |
|---|---|
| User-defined triggers | None |
| Large objects | 0 |
| Materialized views | 0 |
| Foreign-data wrappers | 0 |
| Foreign servers | 0 |
| User mappings | 0 |
| Event triggers | 0 |
| Table inheritance / partition relationships | 0 |
| Row-level security policies | 0 |
| Rules | 0 |
| Custom data types | 0 |

No differences were found in the checked categories.

## 5. VACUUM and ANALYZE

After the restore validation, maintenance was performed on the restored database only.

Command:

```bash
vacuumdb -p 5434 -d perf_lab_restore_validation --analyze --verbose
```

This command performs VACUUM and ANALYZE.

- VACUUM makes space occupied by dead tuples reusable and performs routine maintenance.
- ANALYZE collects table statistics used by the PostgreSQL query planner.

The command completed successfully.

The `pg_stat_user_tables` view was queried to verify analysis timestamps:

```sql
SELECT
    schemaname,
    relname AS table_name,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY schemaname, relname;
```

All 12 user tables had a recent `last_analyze` timestamp.

## 6. Validation Results

| Validation | Result |
|---|---|
| Logical restore | Successful |
| Database size check | Successful |
| Schema inventory | Matched |
| Table counts | Matched |
| Exact row counts | Matched |
| Index counts | Matched |
| Constraint counts | Matched |
| Sequence definitions and states | Matched |
| Extensions and views | Matched |
| Column definitions | Matched |
| Ownership and privileges | Matched |
| Additional object checks | Matched |
| VACUUM and ANALYZE | Successful |
| Analyze timestamp verification | Successful |

## 7. Scope and Limitations

This exercise validates the restored database and the objects explicitly checked above.

A logical database backup does not, by itself, provide a complete backup of the entire PostgreSQL cluster.

The following items require separate backup or validation procedures when needed:

- Cluster-wide roles and role memberships
- Tablespaces
- Replication configuration and replication slots
- Server configuration files
- Operating-system and infrastructure configuration

Restore duration and Recovery Time Objective (RTO) were not measured during this exercise.

Recovery Point Objective (RPO) was also not independently measured.

## 8. Conclusion

The logical backup of `perf_lab` was successfully restored into `perf_lab_restore_validation`.

All checked table counts, row counts, indexes, constraints, sequences, extensions, schemas, column definitions, ownership, and privileges matched the source database.

VACUUM and ANALYZE completed successfully, and fresh planner statistics were confirmed.

The validation database was retained for further testing.

**Final status: Logical backup restore validation successful.**
