# Specification: kafka-k8s-ha-sre-lab

## Problem Statement

Engineers often need practical Kafka high availability experience, but production-like Kafka environments commonly depend on cloud accounts, managed Kubernetes, or shared infrastructure. This blocks learning for engineers without AWS access and makes portfolio projects less reproducible.

`kafka-k8s-ha-sre-lab` provides a local-first SRE lab for running Apache Kafka on Kubernetes with Strimzi in KRaft mode. The lab demonstrates production-minded reliability concepts while staying runnable on a normal PC.

## Target Users

- DevOps and SRE engineers building a portfolio project.
- Backend engineers learning Kafka reliability on Kubernetes.
- Platform engineers evaluating Strimzi concepts locally.
- Students and self-learners without cloud access.
- Teams that want a lightweight lab before moving to VM, k3s, kubeadm, or EKS environments.

## Primary Use Cases

1. Create a local Kubernetes cluster with Kind and Docker.
2. Deploy Strimzi Operator.
3. Deploy a Kafka KRaft cluster.
4. Create a replicated topic named `learning-events`.
5. Produce educational platform events with a Python producer.
6. Consume events with a Python consumer.
7. Observe Kafka health with Prometheus, Grafana, and Alertmanager.
8. Delete one Kafka broker pod and verify recovery.
9. Read practical documentation about Kafka HA, Kubernetes trade-offs, and local limitations.

## Non-Goals

- The MVP is not a drop-in production Kafka platform.
- The MVP does not require AWS, EKS, or any cloud account.
- The MVP does not include ZooKeeper.
- The MVP does not include Elasticsearch.
- The MVP does not implement full multi-cluster disaster recovery.
- The MVP does not benchmark Kafka for production sizing.
- The MVP does not prescribe Kubernetes as universally better than VMs or bare metal for Kafka.

## MVP Scope

The MVP focuses on implementation-ready documentation and a realistic local architecture:

- Repository structure and engineering constitution.
- Kind cluster configuration with one control-plane and three worker nodes.
- Strimzi and Kafka KRaft deployment plan.
- Topic, user, producer, and consumer design.
- Prometheus, Grafana, Alertmanager design.
- Failure simulation design for deleting one broker pod.
- SRE runbooks and troubleshooting documentation.
- Safe Makefile scaffold for repeatable commands.

## Future Scope

- MirrorMaker 2 lab for multi-cluster replication.
- k3s or kubeadm deployment variant.
- Optional EKS documentation.
- GitOps deployment with Argo CD or Flux.
- Upgrade testing and backup automation.
- Load and soak testing.
- kube-state-metrics for Kubernetes-level pod restart alerting.
- Security baseline: SASL/SCRAM, ACLs, and NetworkPolicy.

## Functional Requirements

### FR-001 Local Cluster

The project must define a Kind cluster suitable for local Kafka HA testing with one control-plane node and three worker nodes.

### FR-002 Runtime Support

The project must document Docker as the primary runtime and Podman as an alternative runtime for Kind.

### FR-003 Strimzi

The project must use Strimzi Operator to manage Kafka resources on Kubernetes.

### FR-004 KRaft Mode

Kafka must run in KRaft mode. ZooKeeper must not be part of the MVP architecture.

### FR-005 Kafka Cluster

The Kafka design must support three Kafka broker replicas where local hardware allows it.

### FR-006 Topic

The project must create a topic named `learning-events` with replication factor 3 and `min.insync.replicas=2` where possible.

### FR-007 Producer

The producer must send JSON educational platform events and use durable producer settings, including `acks=all`.

### FR-008 Consumer

The consumer must read from `learning-events`, print received events, and support a stable consumer group for lag observation.

### FR-009 Observability

The project must include a working local observability layer comprising Prometheus, Grafana, and Alertmanager, deployable via `make deploy-observability`.

**Phase 4 Observability implementation requirements:**

- Prometheus must scrape Kafka broker JMX metrics (port 9404) using Kubernetes pod discovery.
- Prometheus must scrape Kafka Exporter metrics (port 9404) for consumer lag.
- Prometheus must scrape the Strimzi Cluster Operator metrics (port 8080).
- Prometheus must load and evaluate Kafka alert rules.
- Prometheus must route firing alerts to Alertmanager.
- Grafana must have Prometheus provisioned as its default datasource.
- Grafana must load the Kafka Overview dashboard automatically on startup.
- Alertmanager must receive alerts from Prometheus and provide a local UI.
- All three components must be accessible locally via `make port-forward-*` targets.
- The Kafka CR must be updated to enable JMX metrics (`metricsConfig`) and Kafka Exporter (`kafkaExporter`).

**Alert rules implemented:**
- KafkaBrokerDown
- KafkaBrokerUnreachable
- KafkaClusterBrokerCountLow
- KafkaUnderReplicatedPartitions
- KafkaOfflinePartitions
- KafkaActiveControllerCount
- StrimziOperatorDown
- ConsumerLagHigh
- KafkaExporterDown

**Local limitation:** KafkaPodCrashLooping based on Kubernetes restart counts requires kube-state-metrics, which is not deployed in this phase. Persistent broker unavailability is covered by KafkaBrokerUnreachable (fires after 5 minutes).

### FR-010 Failure Simulation

The project must include a script or documented command to delete one Kafka broker pod and verify that the cluster recovers.

## Non-Functional Requirements

- The MVP must be understandable by a single engineer.
- Setup steps must be explicit and repeatable.
- Local resource requirements must be documented.
- Documentation must explain limitations of local testing.
- Scripts and Makefile targets must be safe by default.
- The project must avoid cloud assumptions in the MVP path.
- The project must separate MVP from future production extensions.

## Local Testing Requirements

- Primary path: Kind with Docker.
- Alternative path: Kind with Podman.
- Optional path: Minikube documentation only.
- No AWS credentials or cloud resources required.
- Expected minimum local resources for the complete future lab: 4 CPU cores, 8 GB RAM, and 20 GB free disk.
- Recommended resources: 6 to 8 CPU cores, 16 GB RAM, and SSD storage.

## Kafka HA Requirements

- Three Kafka brokers where local resources allow.
- Replication factor 3 for the demo topic where possible.
- `min.insync.replicas=2` for the demo topic where possible.
- Producer `acks=all`.
- Broker pod anti-affinity or topology spread preferences where practical.
- Persistent volumes for broker state, even in local testing.
- Clear explanation of Kafka-level HA versus Kubernetes-level restart behavior.

## Observability Requirements

- Prometheus must scrape Kafka and Strimzi metrics.
- Grafana must show Kafka health, broker state, topic state, and consumer lag.
- Alertmanager must route alerts locally.
- Important alerts must include broker down, under-replicated partitions, offline partitions, high consumer lag, and disk pressure.

## Security Requirements

- Local defaults must be clearly labeled as lab defaults.
- TLS, SASL/SCRAM, ACLs, Kubernetes Secrets, and NetworkPolicy must be documented.
- Future KafkaUser manifests should prefer authenticated users over anonymous access.
- Secrets must not be committed with real credentials.
- The project must distinguish local convenience from production hardening.

## Disaster Recovery Requirements

- MVP must cover broker pod deletion and recovery.
- MVP must document that broker restart is not full disaster recovery.
- Topic definitions and Kafka custom resources must be treated as recoverable configuration.
- Future scope must include MirrorMaker 2, multi-cluster replication, off-cluster backups, and restore tests.

## Success Criteria

The MVP documentation and scaffold are successful when:

- A reader understands the project purpose and limits within five minutes.
- The repository structure clearly maps to implementation phases.
- The Kind cluster configuration exists.
- The Makefile exposes the expected workflow targets.
- The docs explain Kafka HA, Kubernetes trade-offs, local limitations, observability, security, and runbooks.
- The task breakdown can be executed by another engineer without guessing the next step.
- No MVP path requires AWS, EKS, or cloud credentials.

The future runnable lab is successful when:

- A local Kind cluster starts successfully.
- Strimzi becomes ready.
- Kafka KRaft cluster becomes ready.
- `learning-events` topic exists.
- Producer and consumer exchange sample events.
- Prometheus collects Kafka metrics.
- Grafana shows Kafka health and consumer lag.
- Deleting one broker pod does not stop validated message flow.

## Core Demo Scenario

1. User creates a local Kind cluster.
2. User installs Strimzi.
3. User deploys a Kafka KRaft cluster.
4. User creates a topic named `learning-events`.
5. Python producer sends educational platform events.
6. Python consumer reads events.
7. Prometheus collects metrics.
8. Grafana shows Kafka health and consumer lag.
9. User deletes one Kafka broker pod.
10. System recovers.
11. User validates that Kafka is still functional.

Sample event:

```json
{
  "student_id": "u-1021",
  "course": "english-a2",
  "event": "lesson_completed",
  "score": 91,
  "timestamp": "2026-05-19T12:00:00Z"
}
```
