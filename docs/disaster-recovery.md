# Disaster Recovery

## Scope

The MVP covers local failure simulation, not full disaster recovery.

The required MVP test deletes one Kafka broker pod and verifies that Kubernetes, Strimzi, and Kafka recover the local cluster. This is a useful reliability exercise, but it is not the same as recovering from disk loss, cluster loss, region loss, or data corruption.

## What the MVP Covers

- Broker pod deletion.
- Kubernetes pod recreation.
- Strimzi reconciliation.
- Temporary reduced ISR.
- Kafka returning to healthy state.
- Producer and consumer validation after recovery.
- Alert and runbook behavior during a broker event.

## What the MVP Does Not Cover

- Full Kubernetes cluster loss.
- Persistent volume loss.
- Corrupt Kafka log recovery.
- Multi-cluster failover.
- Cross-region replication.
- Backup and restore from object storage.
- DNS failover.
- Client failover across clusters.
- Recovery time objective and recovery point objective validation.

## Broker Restart vs Real DR

Deleting a broker pod tests restart behavior. The replacement pod usually reuses the broker's persistent volume. If the volume is healthy, the broker rejoins the cluster and catches up.

Real disaster recovery asks harder questions:

- What if the broker volume is gone?
- What if the Kubernetes cluster is gone?
- What if the entire site is unavailable?
- What if a bad topic config or application bug corrupts logical data?
- How are clients redirected?
- How much data loss is acceptable?
- How long can the business tolerate outage?

The MVP must not blur these categories.

## Configuration Backup

Kafka and Strimzi configuration should be recoverable from Git:

- Kafka custom resources.
- KafkaTopic resources.
- KafkaUser resources.
- Prometheus rules.
- Grafana dashboards.
- Alertmanager routes.
- NetworkPolicy resources.

Future implementation should include a command or workflow to export live custom resources and compare them with Git.

## Future MirrorMaker 2

MirrorMaker 2 is the natural future extension for multi-cluster replication.

A future DR lab can include:

- Two local Kind clusters or one Kind cluster plus k3s.
- MirrorMaker 2 managed by Strimzi.
- Replication of `learning-events`.
- Consumer offset sync experiments.
- Planned failover runbook.
- Failback limitations.

## Future Multi-Cluster Design

A production-minded multi-cluster design must define:

- Source and target clusters.
- Replication topology.
- Topic naming policy.
- Offset sync policy.
- Client bootstrap behavior.
- DNS or service discovery behavior.
- RTO and RPO targets.
- Security model across clusters.
- Monitoring on both clusters.
- Regular failover drills.

## DR Success Criteria for Future Versions

A future DR extension should be considered successful only when:

- Replication is observable.
- Failover steps are documented and tested.
- Consumers can resume with understood offset behavior.
- Data loss expectations are explicit.
- Restore and failback risks are documented.
- Operators can run the procedure without guessing.

