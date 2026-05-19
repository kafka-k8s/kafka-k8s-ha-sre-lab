# Production Checklist

This checklist is for production-minded review. Completing this local lab does not mean a production Kafka platform is ready.

## Storage

- [ ] Storage class is tested with Kafka-like workloads.
- [ ] Disk latency and throughput are measured.
- [ ] Volume expansion behavior is understood.
- [ ] Reclaim policy is intentional.
- [ ] Backup and restore procedures are tested.
- [ ] Disk pressure alerts exist.
- [ ] Retention policies are documented.

## Node Isolation

- [ ] Kafka brokers run on appropriate node pools.
- [ ] Anti-affinity or topology spread constraints are configured.
- [ ] Maintenance and drain procedures are tested.
- [ ] Node failure domains map to real infrastructure failure domains.
- [ ] No unrelated noisy workloads share critical broker capacity.

## Monitoring

- [ ] Broker availability is monitored.
- [ ] Kafka readiness is monitored.
- [ ] Under-replicated partitions are monitored.
- [ ] Offline partitions are monitored.
- [ ] Consumer lag is monitored.
- [ ] JVM, CPU, memory, and disk signals are monitored.
- [ ] Dashboards are reviewed by operators.

## Alerting

- [ ] Alerts are actionable.
- [ ] Alerts link to runbooks.
- [ ] Thresholds are tested against normal and failure behavior.
- [ ] Notification routes are owned.
- [ ] Alert noise is reviewed after drills.

## Security

- [ ] TLS is enabled for required listeners.
- [ ] Kafka client authentication is enabled.
- [ ] ACLs follow least privilege.
- [ ] Kubernetes RBAC is reviewed.
- [ ] NetworkPolicy is enforced where supported.
- [ ] Secrets are rotated.
- [ ] Images are pinned and scanned.

## Backup

- [ ] Kafka and Strimzi custom resources are stored in Git.
- [ ] Topic and user definitions are recoverable.
- [ ] Critical dashboards and alert rules are recoverable.
- [ ] Data backup strategy is defined where required.
- [ ] Restore tests are scheduled.

## Disaster Recovery

- [ ] RTO and RPO are defined.
- [ ] Multi-cluster replication strategy is selected if required.
- [ ] Failover runbook is tested.
- [ ] Failback process is documented.
- [ ] Client routing during failover is understood.
- [ ] DR drills are scheduled.

## Capacity Planning

- [ ] Expected throughput is known.
- [ ] Partition count strategy is documented.
- [ ] Retention and storage growth are modeled.
- [ ] Producer and consumer patterns are understood.
- [ ] Headroom targets are defined.
- [ ] Load tests are run before production launch.

## Upgrade Strategy

- [ ] Strimzi upgrade path is tested.
- [ ] Kafka version upgrade path is tested.
- [ ] Kubernetes upgrade impact is tested.
- [ ] Broker rolling restart behavior is understood.
- [ ] Rollback conditions are documented.

## Runbooks

- [ ] Broker down.
- [ ] Consumer lag high.
- [ ] Under-replicated partitions.
- [ ] Offline partitions.
- [ ] Disk pressure.
- [ ] Pod crash loop.
- [ ] Kafka unavailable.
- [ ] Strimzi operator failure.

## Access Control

- [ ] Admin access is limited.
- [ ] Producer and consumer users are separated.
- [ ] ACL changes are reviewed.
- [ ] Credentials are not shared between applications.
- [ ] Audit requirements are understood.

## Final Production Gate

Do not treat this lab as production-ready until realistic infrastructure, storage, security, monitoring, upgrades, backup, DR, and operational ownership have all been validated.

