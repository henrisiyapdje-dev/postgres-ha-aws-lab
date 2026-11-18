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

---

# Test 2 — Controlled Patroni Switchover with Mattermost

## Test Date

2026-10-01

## Objective

Verify that:

1. The current primary can be safely switched to a healthy replica.
2. Patroni promotes the selected candidate.
3. HAProxy automatically follows the new primary.
4. Mattermost continues to access PostgreSQL through HAProxy.
5. The previous primary rejoins as a replica.
6. Replication returns to zero lag.

## Initial Cluster State

Before the switchover:

```text
pg-ha-1  Leader   running
pg-ha-2  Replica  streaming  lag 0
pg-ha-3  Replica  streaming  lag 0
```

## Controlled Switchover

The leader was changed from `pg-ha-1` to `pg-ha-2` using:

```bash
sudo patronictl -c /etc/patroni/patroni.yml switchover \
  suta-ha001 \
  --leader pg-ha-1 \
  --candidate pg-ha-2 \
  --force
```

Patroni reported:

```text
Successfully switched over to "pg-ha-2"
```

## Resulting Cluster State

Immediately after the switchover:

```text
pg-ha-1  Replica  stopped
pg-ha-2  Leader   running
pg-ha-3  Replica  running
```

The PostgreSQL timeline changed from `18` to `19`.

## Patroni Primary Health Check

The `/primary` endpoint was tested:

```bash
curl -s -o /dev/null -w "pg-ha-1 /primary HTTP=%{http_code}\n" \
  http://172.31.4.103:8008/primary

curl -s -o /dev/null -w "pg-ha-2 /primary HTTP=%{http_code}\n" \
  http://172.31.6.248:8008/primary

curl -s -o /dev/null -w "pg-ha-3 /primary HTTP=%{http_code}\n" \
  http://172.31.5.186:8008/primary
```

Result:

```text
pg-ha-1 /primary HTTP=503
pg-ha-2 /primary HTTP=200
pg-ha-3 /primary HTTP=503
```

This confirmed that Patroni correctly identified `pg-ha-2` as the new primary.

## HAProxy and Mattermost Database Test

From `mattermost-1`, the application database connection was tested through HAProxy:

```bash
psql -h 172.31.10.135 -U mmuser -d mattermost -p 5432 \
  -c "SELECT inet_server_addr(), inet_server_port(), current_user, current_database(), pg_is_in_recovery();"
```

Observed result:

```text
172.31.6.248 | 5432 | mmuser | mattermost | f
```

This confirmed:

- Mattermost connected to HAProxy.
- HAProxy routed the connection to `pg-ha-2`.
- `pg-ha-2` was the active primary.
- The correct database and application user were used.
- `pg_is_in_recovery() = f` confirmed the server was primary.

## Mattermost Application Health

Mattermost API health check:

```bash
curl -s http://127.0.0.1:8065/api/v4/system/ping
```

Result included:

```text
"status":"OK"
```

Mattermost systemd service remained:

```text
Active: active (running)
```

This confirmed that Mattermost remained operational after the PostgreSQL switchover.

## Previous Primary Rejoin

After the switchover, `pg-ha-1` automatically rejoined the cluster.

Final cluster state:

```text
pg-ha-1  Replica  streaming  TL 18  lag 0
pg-ha-2  Leader   running    TL 18
pg-ha-3  Replica  streaming  TL 18  lag 0
```

Both replicas were streaming with zero replication lag.

## Result

**PASS**

The controlled switchover test verified:

- Controlled Patroni leader transition
- `pg-ha-2` promotion
- Patroni primary health detection
- HAProxy automatic primary routing
- Mattermost database connectivity
- Mattermost application availability
- Previous primary rejoin
- PostgreSQL timeline advancement
- Zero replication lag
