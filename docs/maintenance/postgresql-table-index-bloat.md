# PostgreSQL Table and Index Bloat Lab

## 1. Overview

This hands-on lab demonstrates PostgreSQL table bloat, index bloat, dead tuples, VACUUM, VACUUM FULL, and REINDEX.

The objective is to understand how UPDATE and DELETE operations affect physical storage and how PostgreSQL maintenance operations reclaim or reuse that storage.

## 2. Lab Environment

| Component | Configuration |
|---|---|
| Operating System | CentOS Stream 9 |
| PostgreSQL Version | 17.11 |
| Database | perf_lab_full_restore_test |
| Port | 5434 |
| Table | public.bloat_lab |
| Extensions | pgstattuple 1.5 |

## 3. Create the Lab Table

```sql
CREATE TABLE public.bloat_lab (
    id BIGSERIAL PRIMARY KEY,
    customer_name VARCHAR(100),
    email VARCHAR(150),
    balance NUMERIC(12,2),
    description TEXT
);
```

Insert 10,000 sample records:

```sql
INSERT INTO public.bloat_lab
    (customer_name, email, balance, description)
SELECT
    'Customer_' || g,
    'customer_' || g || '@example.com',
    (random() * 10000)::NUMERIC(12,2),
    repeat(md5(random()::text), 5)
FROM generate_series(1, 10000) AS g;
```

## 4. Generate Table Bloat

Temporarily disable autovacuum for the lab table:

```sql
ALTER TABLE public.bloat_lab
SET (autovacuum_enabled = false);
```

Update all records:

```sql
UPDATE public.bloat_lab
SET balance = balance + 100,
    description = repeat(md5(random()::text), 5);
```

Delete half the records:

```sql
DELETE FROM public.bloat_lab
WHERE id <= 5000;
```

Inspect table statistics:

```sql
SELECT
    relname,
    n_live_tup,
    n_dead_tup,
    last_autovacuum
FROM pg_stat_user_tables
WHERE relname = 'bloat_lab';
```

## 5. VACUUM vs. VACUUM FULL

Run normal VACUUM:

```sql
VACUUM (VERBOSE) public.bloat_lab;
```

Normal VACUUM removes dead tuples and makes the space available for reuse. It does not normally shrink the physical table file.

Run VACUUM FULL:

```sql
VACUUM FULL VERBOSE public.bloat_lab;
```

VACUUM FULL rewrites the table and compacts its storage. It requires an ACCESS EXCLUSIVE lock and additional disk space during the rewrite.

### Observed Results

| Metric | Before VACUUM FULL | After VACUUM FULL |
|---|---:|---:|
| Table size | 5,000 KB | 1,256 KB |
| Index size | 456 KB | 128 KB |
| Total size | 5,496 KB | 1,392 KB |

The total storage reduction was approximately 74.7%.

Note: Dead tuples had already been removed by normal VACUUM before VACUUM FULL. VACUUM FULL reclaimed the unused physical space through rewriting.

## 6. Install pgstattuple

Install the extension:

```sql
CREATE EXTENSION pgstattuple;
```

Inspect physical table statistics:

```sql
SELECT *
FROM pgstattuple('public.bloat_lab');
```

Important fields:

- `table_len`: Physical relation size.
- `tuple_count`: Number of live tuples.
- `dead_tuple_count`: Number of dead tuples.
- `dead_tuple_percent`: Percentage of space occupied by dead tuples.
- `free_space`: Available free space.

## 7. Inspect B-tree Indexes with pgstatindex

Inspect the primary key index:

```sql
SELECT *
FROM pgstatindex('public.bloat_lab_pkey');
```

Important fields:

- `index_size`: Physical index size.
- `leaf_pages`: Number of leaf pages.
- `deleted_pages`: Number of deleted pages.
- `avg_leaf_density`: Average leaf-page occupancy.
- `leaf_fragmentation`: Physical ordering fragmentation.

## 8. Generate Index Bloat

Create a secondary index:

```sql
CREATE INDEX idx_bloat_lab_balance
ON public.bloat_lab (balance);
```

Record its initial size:

```sql
SELECT
    indexrelname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE relname = 'bloat_lab';
```

Temporarily disable autovacuum again:

```sql
ALTER TABLE public.bloat_lab
SET (autovacuum_enabled = false);
```

Update the indexed column:

```sql
UPDATE public.bloat_lab
SET balance = balance + 10;
```

Repeat the update to generate additional row versions and index maintenance activity:

```sql
UPDATE public.bloat_lab
SET balance = balance + 10;
```

Inspect the secondary index:

```sql
SELECT *
FROM pgstatindex('public.idx_bloat_lab_balance');
```

Inspect physical index statistics:

```sql
SELECT *
FROM pgstattuple('public.idx_bloat_lab_balance');
```

Inspect the primary key index:

```sql
SELECT *
FROM pgstattuple('public.bloat_lab_pkey');
```

### Observed Index Statistics

After repeated UPDATE operations:

| Metric | Primary Key | Secondary Index |
|---|---:|---:|
| Index size | 240 KB | 456 KB |
| Leaf pages | 28 | 29 |
| Average leaf density | 81.80% | 85.25% |
| Leaf fragmentation | 46.43% | 48.28% |

The indexed column update prevented HOT updates because an indexed column changed. PostgreSQL had to maintain new index entries for the new row versions.

## 9. Run VACUUM and Compare Index Sizes

Run:

```sql
VACUUM (VERBOSE) public.bloat_lab;
```

Inspect the index sizes again:

```sql
SELECT
    indexrelname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE relname = 'bloat_lab';
```

### Observed Results

| Index | Before VACUUM | After VACUUM |
|---|---:|---:|
| Primary key | 240 KB | 240 KB |
| Secondary index | 456 KB | 456 KB |

VACUUM removed obsolete row versions and dead index item identifiers, but the physical index sizes remained unchanged.

## 10. Rebuild the Secondary Index with REINDEX

Run:

```sql
REINDEX INDEX public.idx_bloat_lab_balance;
```

Inspect its new size:

```sql
SELECT
    indexrelname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE indexrelname = 'idx_bloat_lab_balance';
```

### Observed Results

| Metric | Before REINDEX | After REINDEX |
|---|---:|---:|
| Index size | 456 KB | 128 KB |
| Leaf pages | 57 | 14 |
| Average leaf density | 85.25% | 88.34% |
| Leaf fragmentation | 48.28% | 0% |

REINDEX reduced the secondary index size by approximately 71.9%.

### Verify the Rebuilt Index

```sql
SELECT *
FROM pgstatindex('public.idx_bloat_lab_balance');
```

The rebuilt index showed:

- 128 KB index size
- 14 leaf pages
- 88.34% average leaf density
- 0% leaf fragmentation
- 0 deleted pages

## 11. Re-enable Autovacuum

Always restore autovacuum after completing the lab:

```sql
ALTER TABLE public.bloat_lab
SET (autovacuum_enabled = true);
```

Verify:

```sql
SELECT
    c.relname AS table_name,
    c.reloptions
FROM pg_class c
WHERE c.oid = 'public.bloat_lab'::regclass;
```

Expected setting:

```text
{autovacuum_enabled=true}
```

## 12. Key DBA Takeaways

| Operation | Purpose |
|---|---|
| Autovacuum | Automatically maintains tables and indexes |
| VACUUM | Removes dead tuples and makes space reusable |
| VACUUM FULL | Rewrites and compacts table storage |
| REINDEX | Rebuilds an index structure |
| pgstattuple | Inspects physical table and index statistics |
| pgstatindex | Inspects B-tree index structure |

Important production considerations:

- Do not routinely disable autovacuum.
- Monitor dead tuples and table/index growth.
- VACUUM does not necessarily reduce physical file size.
- VACUUM FULL requires an ACCESS EXCLUSIVE lock.
- REINDEX can reclaim index storage, but requires planning for locking and disk space.
- Do not diagnose index bloat using only one metric.

## 13. Interview Explanation

I created a PostgreSQL table with a primary key and a secondary index. I disabled autovacuum temporarily and performed repeated UPDATE and DELETE operations to generate dead tuples and index growth.

I used pgstattuple and pgstatindex to inspect the physical table and index structures.

Normal VACUUM removed obsolete tuples, but the index file sizes remained unchanged. I then rebuilt the secondary index using REINDEX, reducing its size from 456 KB to 128 KB, approximately 72% smaller.

This exercise helped me understand the difference between removing dead tuples, reusing free space, compacting table storage, and rebuilding indexes.