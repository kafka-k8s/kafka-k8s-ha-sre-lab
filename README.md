# kafka-kubernetes-ha-sre-lab

Local-first, production-minded SRE lab for running highly available Apache Kafka on Kubernetes with Strimzi, KRaft mode, Kind, Docker or Podman, Prometheus, Grafana, Alertmanager, and failure simulation workflows.

This repository is intentionally educational. It demonstrates real SRE thinking for Kafka on Kubernetes without requiring AWS, EKS, or any cloud account.

## Why This Project Exists

Many Kafka HA examples assume managed cloud infrastructure, large clusters, or incomplete toy deployments. This lab gives engineers a practical local environment for learning how Kafka replication, Kubernetes reconciliation, Strimzi automation, observability, and failure testing fit together.

The goal is not to claim that Kafka should always run on Kubernetes. The goal is to make the trade-offs visible and give engineers a repeatable place to practice.

## Architecture Summary

The MVP target architecture is:

- Kind Kubernetes cluster with one control-plane node and three worker nodes.
- Docker as the primary local container runtime.
- Podman as an alternative Kind provider.
- Strimzi Operator managing Kafka.
- Kafka in KRaft mode, not ZooKeeper.
- Three Kafka brokers where local resources allow.
- Topic `learning-events` with replication factor 3 and `min.insync.replicas=2` where possible.
- Python producer and consumer for educational platform events.
- Prometheus, Grafana, and Alertmanager for local observability.
- Failure scripts that delete one broker pod and verify recovery.

See [docs/architecture.md](docs/architecture.md) for diagrams and component details.

## Quick Start: Kind + Docker

Current status: this first pass provides documentation, project structure, a Kind cluster config, and safe Makefile targets. Kafka manifests, observability configs, Python apps, and failure scripts are planned in the task breakdown.

Prerequisites:

- Docker running locally.
- `kind` installed.
- `kubectl` installed.
- `make` installed.

Create the local cluster:

```sh
make cluster-up-docker
make nodes
make status
```

Delete the local cluster:

```sh
make cluster-down
```

Later implementation phases will enable:

```sh
make install-strimzi
make deploy-kafka
make create-topic
make produce
make consume
make kill-broker
make verify-ha
```

## Quick Start: Kind + Podman

Podman is supported as an alternative local runtime. Docker remains the primary path because it is the most common Kind setup.

Prerequisites:

- Podman running locally.
- `kind` installed with Podman provider support.
- `kubectl` installed.
- `make` installed.

Create the local cluster:

```sh
make cluster-up-podman
make nodes
make status
```

If Kind cannot connect to Podman, confirm your Podman machine or service is running before retrying.

## Optional Minikube Note

Minikube is documentation-only for the MVP. It can be useful for experiments, but driver, storage, and network behavior vary more than Kind. The main tested path should remain Kind.

## What This Project Demonstrates

- Kafka high availability concepts in a Kubernetes environment.
- Strimzi-managed Kafka lifecycle.
- KRaft-based Kafka deployment planning.
- Topic replication and `min.insync.replicas`.
- Producer durability with `acks=all`.
- Consumer lag as an SRE signal.
- Broker failure and recovery simulation.
- Prometheus metrics, Grafana dashboards, and Alertmanager alerts.
- Incident runbooks and production readiness thinking.

## What This Project Does Not Claim

- It is not a drop-in production Kafka platform.
- It does not prove production storage durability.
- It does not validate multi-zone or multi-region failure behavior.
- It does not replace capacity planning, load testing, security review, or disaster recovery testing.
- It does not claim Kafka on Kubernetes is always better than Kafka on VMs or bare metal.

## SRE Concepts Covered

- Service reliability boundaries.
- Failure mode analysis.
- Health checks and readiness.
- Broker restart versus true disaster recovery.
- Partition replication and ISR behavior.
- Alert design and runbook-driven operations.
- Local testing limits.
- Production checklist discipline.

## Core Demo Scenario

The intended end-to-end demo is:

1. Create a local Kind cluster.
2. Install Strimzi.
3. Deploy a Kafka KRaft cluster.
4. Create a topic named `learning-events`.
5. Send educational platform events with a Python producer.
6. Read events with a Python consumer.
7. Collect metrics with Prometheus.
8. View Kafka health and consumer lag in Grafana.
9. Delete one Kafka broker pod.
10. Validate recovery and continued message flow.

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

## Documentation Map

- [CONSTITUTION.md](CONSTITUTION.md): Engineering principles.
- [specs/kafka-kubernetes-ha-sre-lab/spec.md](specs/kafka-kubernetes-ha-sre-lab/spec.md): Product and technical specification.
- [specs/kafka-kubernetes-ha-sre-lab/plan.md](specs/kafka-kubernetes-ha-sre-lab/plan.md): Implementation plan.
- [specs/kafka-kubernetes-ha-sre-lab/tasks.md](specs/kafka-kubernetes-ha-sre-lab/tasks.md): Step-by-step task breakdown.
- [docs/architecture.md](docs/architecture.md): Architecture diagrams and component flow.
- [docs/ha-design.md](docs/ha-design.md): Kafka HA design notes.
- [docs/kubernetes-vs-vm.md](docs/kubernetes-vs-vm.md): Kubernetes versus VM/bare metal trade-offs.
- [docs/local-testing.md](docs/local-testing.md): Local runtime guide.
- [docs/disaster-recovery.md](docs/disaster-recovery.md): DR boundaries and future design.
- [docs/observability.md](docs/observability.md): Metrics, dashboards, and alerts.
- [docs/security.md](docs/security.md): Local security and hardening plan.
- [docs/incident-runbook.md](docs/incident-runbook.md): Operational runbooks.
- [docs/troubleshooting.md](docs/troubleshooting.md): Common local issues.
- [docs/production-checklist.md](docs/production-checklist.md): Production readiness checklist.

## Roadmap

- Phase 1: Documentation and repository scaffold.
- Phase 2: Kind cluster and local setup validation.
- Phase 3: Strimzi and Kafka KRaft manifests.
- Phase 4: Python producer and consumer.
- Phase 5: Prometheus, Grafana, and Alertmanager assets.
- Phase 6: Failure simulation scripts.
- Phase 7: Documentation polish and consistency checks.
- Phase 8: End-to-end local validation.

## Resume Bullet Example

Designed and implemented a local-first Kafka high availability SRE lab on Kubernetes using Kind, Strimzi, KRaft mode, Prometheus, Grafana, Alertmanager, and failure simulation scripts to demonstrate broker recovery, topic replication, consumer lag monitoring, and production-minded operational runbooks without cloud dependencies.

