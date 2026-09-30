# Mattermost Application

Mattermost is the application tier for the PostgreSQL HA lab.

## Architecture

```text
Mattermost
    |
    | PostgreSQL TCP/5432
    v
HAProxy
172.31.10.135:5432
    |
    | Patroni /primary health check
    v
+------------------+
| PostgreSQL HA    |
|                  |
| pg-ha-1          |
| pg-ha-2          |
| pg-ha-3          |
+------------------+

Application Server
Host: mattermost-1
Private IP: 172.31.11.231
Application port: 8065
Mattermost version: 11.11.1
Service account: mattermost
Installation directory: /opt/mattermost
Database

Mattermost connects to PostgreSQL through HAProxy instead of connecting directly to an individual PostgreSQL node.

Database endpoint:

172.31.10.135:5432

Database:

mattermost

Database user:

mmuser

The database password is intentionally NOT stored in Git.

Systemd

Mattermost runs as:

User=mattermost
Group=mattermost

The service is enabled to start automatically.

Validation

Check the Mattermost service:

sudo systemctl status mattermost

Check the application listener:

sudo ss -lntp | grep ':8065'

Test the local HTTP endpoint:

curl -I http://127.0.0.1:8065

Test the Mattermost API:

curl -s http://127.0.0.1:8065/api/v4/system/ping

Expected result contains:

"status":"OK"
PostgreSQL Connectivity

Mattermost connects to:

HAProxy 172.31.10.135:5432

The HAProxy layer routes the connection to the current Patroni PostgreSQL primary.

Security

The following must NOT be committed:

Mattermost config.json
Database passwords
Mattermost admin password
Runtime data
Application logs
Terraform state
SSH private keys
Environment-specific secrets
