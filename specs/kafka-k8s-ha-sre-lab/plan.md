# Implementation Plan: kafka-k8s-ha-sre-lab

## Technical Architecture

The lab runs Kafka on a local Kind Kubernetes cluster. Strimzi manages Kafka custom resources. Kafka runs in KRaft mode. Prometheus collects metrics, Grafana visualizes health, and Alertmanager handles local alerts. Python producer and consumer apps generate and read educational platform events.

The first implementation pass creates documentation, project structure, the Kind cluster config, and safe Makefile targets. Later phases add Kubernetes manifests, observability assets, Python apps, and failure scripts.

## Repository Layout

```text
README.md
CONSTITUTION.md
specs/
  kafka-k8s-ha-sre-lab/
    spec.md
    clarification.md
    plan.md
    tasks.md
docs/
  architecture.md
  ha-design.md
  kubernetes-vs-vm.md
  local-testing.md
  disaster-recovery.md
  observability.md
  security.md
  incident-runbook.md
  troubleshooting.md
  production-checklist.md
kind/
  kind-cluster.yaml
manifests/
  namespace.yaml
  strimzi/
  kafka/
  topics/
  users/
observability/
  prometheus/
  grafana/
  alertmanager/
apps/
  producer.py
  consumer.py
scripts/
  install.sh
  verify-ha.sh
  kill-broker.sh
  check-cluster-health.sh
Makefile
```

## Required Tools

Required for the primary path:

- Docker
- Kind
- kubectl
- make
- Python 3.11 or newer for producer and consumer phases

Alternative local path:

- Podman
- Kind with the Podman provider enabled

Optional:

- Minikube for documentation-only experiments
- k9s, kubectx, and jq for operator convenience

## Local Setup Flow

1. Clone the repository.
2. Confirm Docker or Podman is running.
3. Create the Kind cluster.
4. Confirm all Kubernetes nodes are ready.
5. Install Strimzi.
6. Deploy Kafka KRaft resources.
7. Create topic and user resources.
8. Start producer and consumer.
9. Install or expose observability services.
10. Run broker failure simulation.
11. Validate recovery.

## Kind Cluster Design

The Kind cluster uses:

- One control-plane node.
- Three worker nodes.
- Local container networking.
- Default local storage class for persistent volume claims.

The three worker nodes allow the lab to demonstrate broker spreading and pod-level recovery. This does not equal true physical failure isolation because all nodes still run on one workstation.

## Strimzi Deployment Flow

The MVP should prefer transparent `kubectl apply` installation over Helm. A later implementation should pin a tested Strimzi version and document how to upgrade it.

Planned flow:

1. Create `kafka-lab` namespace.
2. Apply Strimzi operator manifests.
3. Wait for Strimzi Cluster Operator readiness.
4. Apply Kafka custom resources.
5. Watch Strimzi reconcile the Kafka cluster.

## Kafka KRaft Cluster Design

Planned cluster:

- Kafka mode: KRaft.
- Broker count: 3 where possible.
- Controller role: combined or dedicated depending on Strimzi support and local resource budget.
- Storage: persistent volume claims.
- Listeners: internal listener for in-cluster clients; optional local access path for developer apps.
- Topic replication factor: 3 where possible.
- `min.insync.replicas`: 2 where possible.

The design must explain how Kafka replication protects partitions and how Kubernetes restarts failed pods. Kubernetes does not replace Kafka replication.

## Topic and User Design

Topic:

- Name: `learning-events`.
- Partitions: start with 3 for local testing.
- Replicas: 3 where possible.
- Topic-level `min.insync.replicas`: 2 where possible.

User:

- MVP may start with a simple internal connection for learning.
- Preferred future direction: Strimzi `KafkaUser` with SASL/SCRAM and ACLs.
- Producer should have write access to `learning-events`.
- Consumer should have read access to `learning-events` and its consumer group.

## Producer and Consumer Test Design

Producer:

- Python script.
- Sends JSON educational platform events.
- Uses `acks=all`.
- Supports configurable bootstrap servers, topic, message count, and delay.

Consumer:

- Python script.
- Reads from `learning-events`.
- Uses a stable group ID such as `learning-events-demo`.
- Prints decoded JSON events.
- Keeps running long enough to observe consumer lag.

## Observability Design

Prometheus:

- Scrapes Strimzi and Kafka metrics.
- Stores local time series only.
- Includes alert rules for important Kafka failure modes.

Grafana:

- Shows broker availability, Kafka readiness, partition health, consumer lag, and JVM/resource indicators.
- Starts with import instructions or placeholder dashboards, then evolves into checked-in dashboards.

Alertmanager:

- Receives alerts from Prometheus.
- Uses local routing only in MVP.
- Future versions can add email, Slack, or webhook receivers.

## Alerting Design

Initial alert classes:

- Kafka broker down.
- Kafka cluster not ready.
- Under-replicated partitions.
- Offline partitions.
- Consumer lag high.
- Persistent volume or disk pressure.
- Pod crash looping.

Alerts should include runbook references once dashboards and alert rules are implemented.

## Failure Simulation Design

Minimum failure test:

1. Identify Kafka broker pods.
2. Delete one broker pod.
3. Watch Kubernetes recreate it.
4. Watch Strimzi reconcile cluster state.
5. Confirm Kafka returns to ready state.
6. Produce and consume messages after recovery.
7. Check metrics and alerts during the event.

This validates local broker restart and Kafka replication behavior. It does not validate zone failure, disk loss, or full disaster recovery.

## Security Design

MVP security posture:

- No real secrets committed.
- Namespace isolation.
- Document TLS, SASL/SCRAM, ACLs, NetworkPolicy, and Kubernetes Secrets.
- Prefer authenticated Kafka users in future manifests.
- Label local shortcuts clearly.

Production-minded future hardening:

- TLS for all Kafka listeners.
- SASL/SCRAM or mTLS for clients.
- Least-privilege ACLs.
- NetworkPolicy limiting access to Kafka, Prometheus, Grafana, and Alertmanager.
- Secret rotation plan.
- Image provenance and version pinning.

## Documentation Plan

Required documents:

- README quick start and project summary.
- Constitution with engineering principles.
- Specification, clarification, plan, and tasks.
- Architecture diagrams.
- Kafka HA design.
- Kubernetes versus VM/bare metal trade-off analysis.
- Local testing guide.
- Disaster recovery guide.
- Observability guide.
- Security guide.
- Incident runbook.
- Troubleshooting guide.
- Production checklist.

## Validation Plan

Documentation validation:

- Confirm all requested files exist.
- Confirm README links point to existing docs.
- Confirm no MVP step requires AWS.
- Confirm Docker is primary and Podman is alternative.
- Confirm KRaft is specified and ZooKeeper is excluded.

Implementation validation for later phases:

- `kind create cluster --config kind/kind-cluster.yaml`
- `kubectl get nodes`
- `kubectl get pods -n kafka-lab`
- `kubectl wait` for Strimzi readiness.
- `kubectl wait` for Kafka readiness.
- Produce sample events.
- Consume sample events.
- Delete one broker pod.
- Verify recovery.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Local machine lacks RAM or CPU | Kafka pods may not schedule or may be unstable | Document minimum and recommended hardware; keep MVP small |
| Kind storage differs from production storage | False confidence about durability | Clearly document storage limitations |
| Podman provider behavior differs by OS | Setup friction | Keep Docker primary and Podman alternative |
| Strimzi API changes over time | Manifests may drift | Pin tested Strimzi versions in implementation phase |
| Users confuse broker restart with DR | Incorrect production assumptions | Separate failure simulation from disaster recovery docs |
| Observability stack consumes too many resources | Local instability | Keep dashboard and alerting minimal at first |

## MVP Implementation

This first pass implements:

- Professional README.
- Constitution.
- Specification, clarification, plan, and task breakdown.
- Architecture, HA, trade-off, local testing, DR, observability, security, runbook, troubleshooting, and production checklist docs.
- Kind cluster config.
- Safe Makefile scaffold.
- Directory structure for later manifests, apps, observability, and scripts.

## Future Versions

Future versions will implement:

- Strimzi operator manifests.
- Kafka KRaft cluster manifests.
- Topic and user manifests.
- Python producer and consumer.
- Prometheus, Grafana, Alertmanager configs.
- Failure scripts.
- YAML validation workflow.
- End-to-end local smoke test.
- Optional k3s, kubeadm, and EKS guides.
