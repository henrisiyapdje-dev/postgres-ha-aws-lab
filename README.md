# PostgreSQL DBA & Database Engineering Labs

A hands-on portfolio demonstrating PostgreSQL database administration, high availability, backup and recovery, replication, monitoring, automation, and AWS infrastructure.

## About This Repository

This repository contains practical PostgreSQL projects and database administration labs developed to demonstrate real-world DBA and database engineering skills.
The projects cover PostgreSQL infrastructure deployment, high availability, disaster recovery, backup automation, database maintenance, and operational monitoring.
The primary focus is building, configuring, testing, and documenting reliable PostgreSQL environments.

## Technical Skills Demonstrated

- PostgreSQL administration and troubleshooting
- PostgreSQL high availability with Patroni
- Distributed Configuration Store (DCS) with etcd
- HAProxy connection routing
- AWS infrastructure provisioning with Terraform
- PostgreSQL backup automation and monitoring
- Logical replication
- Database maintenance and index bloat investigation
- Linux administration and Bash scripting
- Cron scheduling and operational automation

## Projects

### 1. PostgreSQL High Availability on AWS

**Technologies:** PostgreSQL, Patroni, etcd, HAProxy, AWS, Terraform

This project demonstrates a PostgreSQL high-availability environment using three PostgreSQL nodes.

Key components:
- Patroni for PostgreSQL cluster management.
- etcd for distributed configuration and cluster state.
- HAProxy for database connection routing.
- Terraform for AWS infrastructure provisioning.
- Mattermost integration with the PostgreSQL HA environment.

Documentation and configuration:
- `patroni/`
- `etcd/`
- `haproxy/`
- `terraform/`
- `mattermost/`
- [Patroni failover test](docs/tests/patroni-ha-failover-test.md)

### 2. PostgreSQL Backup Automation

**Technologies:** PostgreSQL, Bash, pg_dump, pg_restore, Cron
Demonstrates automated PostgreSQL backup operations with separate daily, weekly, and monthly backup schedules.

Key capabilities:
- Daily, weekly, and monthly backups.
- Backup retention management.
- Cron-based scheduling.
- Backup archive validation.
- Operational logging.

Documentation:
- [Backup automation](docs/maintenance/postgresql-backup-automation.md)
- [Cron scheduling](docs/maintenance/postgresql-cron-scheduling.md)

Scripts:
- `scripts/backup/`

### 3. PostgreSQL Backup Monitoring

**Technologies:** Bash, PostgreSQL, pg_restore, Linux

A separate monitoring script checks daily backup status and backup storage.

Monitoring capabilities:
- Verify that today's backup exists.
- Check backup archive readability.
- Monitor backup filesystem usage.
- Report total backup storage.
- Confirm successful backup execution through log validation.
- Return exit codes to identify monitoring failures.

Documentation:
- [Backup monitoring](docs/maintenance/postgresql-backup-monitoring.md)

Script:
- `scripts/monitoring/monitor_backup.sh`

### 4. PostgreSQL Logical Replication

**Technologies:** PostgreSQL, Logical Replication

Demonstrates PostgreSQL logical replication concepts and practical replication operations.

Documentation:
- [Logical replication](docs/logical-replication.md)

### 5. PostgreSQL Table and Index Bloat

**Technologies:** PostgreSQL, SQL, Database Maintenance

Explores PostgreSQL table and index bloat, monitoring techniques, and database maintenance considerations.

Documentation:
- [Table and index bloat](docs/maintenance/postgresql-table-index-bloat.md)

## Repository Structure

```text
postgresql-dba-labs/
├── docs/
│   ├── maintenance/
│   ├── tests/
│   └── logical-replication.md
├── etcd/
│   ├── dcs-1/
│   ├── dcs-2/
│   └── dcs-3/
├── haproxy/
├── mattermost/
├── patroni/
│   ├── pg-ha-1/
│   ├── pg-ha-2/
│   └── pg-ha-3/
├── scripts/
│   ├── backup/
│   └── monitoring/
├── terraform/
├── .gitignore
└── README.md
```

## Environment and Technologies

| Area | Technologies |
|---|---|
| Database | PostgreSQL |
| High availability | Patroni |
| Distributed configuration | etcd |
| Connection routing | HAProxy |
| Cloud | AWS |
| Infrastructure as Code | Terraform |
| Operating system | Linux |
| Automation | Bash and Cron |
| Collaboration platform | Mattermost |

## Learning and Testing Approach

Projects are developed through hands-on configuration, execution, testing, troubleshooting, and documentation.

The repository focuses on practical database administration scenarios rather than theoretical examples alone.

## Future Improvements

Planned areas for continued development include:

- PostgreSQL physical replication and recovery scenarios.
- Point-in-time recovery (PITR) demonstrations.
- PostgreSQL performance tuning and query optimization.
- Advanced monitoring and alerting.
- Automated infrastructure and database validation.
- Additional disaster recovery and failover scenarios.

## Author

PostgreSQL Database Administrator | Database Engineer

Focused on PostgreSQL administration, high availability, performance optimization, backup and recovery, Linux, and AWS.

---

**Note:** This repository is a hands-on learning and portfolio environment. Configurations should be reviewed and hardened before being used in production.
