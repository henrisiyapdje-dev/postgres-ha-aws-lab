# Patroni PostgreSQL HA Failover Test

## Test Date

2026-09-24

## Cluster

- Patroni scope: `suta-ha001`
- PostgreSQL: 17.11
- DCS: 3-node etcd
- HAProxy: `db-router-1`
- PostgreSQL nodes:
  - `pg-ha-1` - `172.31.4.103`
  - `pg-ha-2` - `172.31.6.248`
  - `pg-ha-3` - `172.31.5.186`

## Test Objective

Verify that:

1. Patroni detects a failed PostgreSQL node.
2. A healthy replica is promoted to primary.
3. HAProxy follows the new primary automatically.
4. The failed node can rejoin the cluster as a replica.
5. Replication returns to zero lag.

## Test 1 — Controlled Patroni Failure

The original leader was:

```text
pg-ha-1
```

Patroni was stopped on `pg-ha-1`:

```bash
sudo systemctl stop patroni
sleep 15
sudo patronictl -c /etc/patroni/patroni.yml list
```

Result:

```text
pg-ha-2  Replica  streaming
pg-ha-3  Leader   running
```

`pg-ha-3` was automatically promoted to leader.

## Test 2 — Patroni REST API

From `db-router-1`:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://172.31.4.103:8008/primary
curl -s -o /dev/null -w "%{http_code}\n" http://172.31.6.248:8008/primary
curl -s -o /dev/null -w "%{http_code}\n" http://172.31.5.186:8008/primary
```

Result:

```text
000
503
200
```

Meaning:

- `pg-ha-1` — Patroni stopped
- `pg-ha-2` — replica
- `pg-ha-3` — current primary

## Test 3 — HAProxy End-to-End Test

From `db-router-1`:

```bash
psql -h 127.0.0.1 -p 5432 -U postgres -d postgres \
  -c "SELECT inet_server_addr(), inet_server_port(), pg_is_in_recovery();"
```

Observed result:

```text
172.31.5.186 | 5432 | f
```

This confirmed that HAProxy routed the PostgreSQL connection to the new primary.

`pg_is_in_recovery() = f` confirms that the connected PostgreSQL server was not in recovery and was therefore the primary.

## Test 4 — Failed Node Rejoin

Patroni was restarted on `pg-ha-1`:

```bash
sudo systemctl start patroni
sleep 20
sudo patronictl -c /etc/patroni/patroni.yml list
```

Final cluster state:

```text
pg-ha-1  Replica  streaming  TL 11  lag 0
pg-ha-2  Replica  streaming  TL 11  lag 0
pg-ha-3  Leader   running    TL 11
```

This confirmed that `pg-ha-1` successfully rejoined the cluster as a replica and caught up with zero replication lag.

## Result

**PASS**

The controlled failure test verified:

- Automatic leader promotion
- Patroni health detection
- HAProxy primary routing
- PostgreSQL replication
- Failed-node recovery
- Automatic rejoin as a replica
- Zero replication lag
