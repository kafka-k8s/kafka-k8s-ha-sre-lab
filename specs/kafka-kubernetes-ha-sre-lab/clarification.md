# Clarification: kafka-kubernetes-ha-sre-lab

This file records implementation defaults for open questions. These decisions allow the MVP to move forward without blocking on optional architecture choices.

## Clarified Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Should the MVP include Elasticsearch? | No. Keep it for future extension. | Elasticsearch adds memory pressure and a second distributed system. The MVP should focus on Kafka HA, not log search. |
| Should the MVP include AWS? | No. AWS/EKS is optional future documentation only. | The project must be usable by engineers without cloud access. |
| Should we use ZooKeeper? | No. Use KRaft mode. | Modern Kafka deployments are moving toward KRaft. ZooKeeper would complicate the lab and dilute the learning goal. |
| Should we use Helm? | Avoid Helm in the MVP unless Strimzi installation requires it. Prefer plain YAML and `kubectl`. | Plain manifests make the operator resources easier to inspect and learn from. |
| Should we support Podman? | Yes, as an alternative path. Docker remains primary. | Podman support helps Linux-first users, but Docker is the most common Kind path. |
| Should we support Minikube? | Documentation only, not the main path. | Minikube behavior varies by driver and storage setup. Kind keeps the primary path reproducible. |
| Should we implement full multi-cluster DR? | No. Document it as future scope. MVP focuses on local failure simulation. | Multi-cluster DR requires more infrastructure and would overcomplicate the first version. |
| Should this be production-ready? | No. It is production-minded and educational, not a drop-in production platform. | Local testing cannot validate real storage, networking, capacity, or operational maturity. |

## Defaults for MVP Implementation

- Kubernetes distribution: Kind.
- Runtime: Docker first, Podman second.
- Kafka operator: Strimzi.
- Kafka mode: KRaft.
- Topic: `learning-events`.
- Replication factor: 3 where local resources allow.
- `min.insync.replicas`: 2 where local resources allow.
- Producer setting: `acks=all`.
- Monitoring: Prometheus and Grafana.
- Alerting: Alertmanager.
- Failure simulation: delete one Kafka broker pod and verify recovery.

## Explicit Local Testing Boundary

The MVP validates control-plane behavior, operator reconciliation, broker pod recovery, topic availability, and basic message flow. It does not validate production storage durability, noisy-neighbor behavior, cloud load balancer behavior, multi-zone placement, realistic throughput, or cross-region disaster recovery.

