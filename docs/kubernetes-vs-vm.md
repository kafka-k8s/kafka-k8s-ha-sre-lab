# Kafka on Kubernetes vs VM or Bare Metal

## Summary

Kafka can run successfully on Kubernetes, VMs, or bare metal. The right choice depends on team experience, storage requirements, operational model, failure domains, and existing platform investment.

This project demonstrates Kafka on Kubernetes for learning and SRE practice. It does not claim Kubernetes is always the best production choice.

## Kafka on Kubernetes: Advantages

- Declarative deployment with Kubernetes resources.
- Operator-driven lifecycle management through Strimzi.
- Consistent local and cluster workflows.
- Integrated scheduling, service discovery, and health checks.
- Easier integration with Kubernetes-native observability.
- Good fit for teams already operating Kubernetes well.
- Useful for ephemeral labs, integration testing, and platform standardization.

## Kafka on Kubernetes: Risks

- Storage behavior is more complex and highly dependent on the CSI driver.
- Broker identity and persistent volume handling must be understood clearly.
- Kubernetes node drains and upgrades can disrupt brokers if poorly planned.
- Scheduling decisions can reduce failure isolation if constraints are weak.
- Network overlays and service abstractions can complicate debugging.
- Operators reduce manual work but add another control plane to understand.
- Local Kind behavior is not equivalent to production Kubernetes behavior.

## Kafka on VM or Bare Metal: Advantages

- Direct control over disks, network, and OS tuning.
- Operational model is familiar to many Kafka teams.
- Fewer abstraction layers between Kafka and storage.
- Easier to reason about dedicated broker hosts.
- Often preferred for very large or latency-sensitive Kafka clusters.

## Kafka on VM or Bare Metal: Risks

- More manual lifecycle management.
- Less declarative automation unless paired with strong config management.
- Scaling, upgrades, and replacement workflows may be slower.
- Observability and runbooks must be assembled outside a Kubernetes platform.
- Environment drift can accumulate across hosts.

## Storage Concerns

Kafka is storage-sensitive. Production Kafka needs predictable disk latency, throughput, capacity, and failure behavior.

On Kubernetes, storage quality depends on:

- CSI driver behavior.
- Persistent volume reclaim policy.
- Node and volume topology.
- Disk performance.
- Volume attachment semantics.
- Backup and restore strategy.

On VMs or bare metal, storage quality depends on:

- Disk type and RAID or local disk design.
- Filesystem and OS tuning.
- Replacement procedures.
- Monitoring and capacity management.

For production Kafka on Kubernetes, storage must be tested with realistic workloads and failure scenarios. A local Kind cluster cannot validate this.

## Operational Complexity

Kafka on Kubernetes shifts some complexity from manual operations to platform operations.

Teams must understand:

- Kafka internals.
- Kubernetes scheduling and storage.
- Strimzi custom resources.
- Operator reconciliation.
- Kubernetes upgrades and node maintenance.
- Observability across Kafka and Kubernetes layers.

If a team is weak in Kubernetes operations, running Kafka on Kubernetes can increase risk instead of reducing it.

## Team Maturity

Kafka on Kubernetes is more reasonable when:

- The team already runs critical workloads on Kubernetes.
- Storage classes and node maintenance are well understood.
- The team has strong monitoring and incident response.
- Platform engineers can support Strimzi and Kubernetes upgrades.
- Kafka users accept the operational model.

Kafka on VMs or bare metal may be more reasonable when:

- The Kafka team already has mature host-based operations.
- Storage performance and isolation are the top priority.
- Kubernetes expertise is limited.
- The cluster is very large or latency-sensitive.
- Organizational standards favor dedicated infrastructure for stateful systems.

## Final Recommendation

Use this lab to learn the mechanics and trade-offs of Kafka on Kubernetes. For real production, choose Kubernetes only after validating storage, failure domains, upgrade workflows, monitoring, security, and team readiness.

Kafka on Kubernetes can be a strong platform choice for the right team. It is not a universal recommendation.

