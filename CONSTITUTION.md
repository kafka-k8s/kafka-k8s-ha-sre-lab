# kafka-k8s-ha-sre-lab Constitution

Version: 1.0.0
Ratified: 2026-05-19

## Purpose

This repository exists to provide a local-first, production-minded SRE lab for learning, demonstrating, and validating highly available Apache Kafka on Kubernetes with Strimzi and KRaft mode. It is designed for engineers who want real operational practice without requiring AWS, EKS, or other cloud access.

The project must be impressive because it is clear, reproducible, observable, and honest. It must not claim to be a universal production blueprint.

## Engineering Principles

### 1. Local-First Design

The MVP must run on a normal developer workstation using Kind and Docker. Kind with Podman is supported as an alternative path. Cloud providers are optional future extensions, never a prerequisite for the MVP.

### 2. Reproducibility

Every setup, validation, and failure test must be scriptable or documented as explicit commands. A new engineer should be able to rebuild the lab from a clean checkout with predictable steps and clear prerequisites.

### 3. Clear SRE Thinking

The repository must explain not only what to deploy, but why each reliability choice exists. Design documents must connect Kafka settings, Kubernetes behavior, monitoring, alerts, and runbooks to concrete failure modes.

### 4. Honest Production Trade-Offs

Kafka on Kubernetes has operational benefits and real risks. The project must explain storage, scheduling, network, upgrade, and team maturity trade-offs clearly. It must avoid presenting Kubernetes as the right answer for every Kafka deployment.

### 5. Observability First

Monitoring, dashboards, alerts, and health checks are core project features, not optional polish. The lab must make Kafka health, broker availability, replication status, and consumer lag visible.

### 6. Failure Testing Is Required

The project must include repeatable failure simulations. At minimum, the MVP must test deleting one Kafka broker pod and validating recovery, topic availability, and producer/consumer functionality.

### 7. Security by Default Where Practical

The project must prefer secure defaults where they do not block local learning. TLS, SASL/SCRAM, ACLs, Kubernetes Secrets, and NetworkPolicy must be documented and introduced progressively. Any insecure local shortcut must be clearly labeled.

### 8. Simplicity Before Overengineering

The MVP must be small enough to run and understand locally. Features such as Elasticsearch, MirrorMaker 2, multi-cluster disaster recovery, EKS, GitOps, and service mesh belong in future versions unless they are required for the current learning goal.

### 9. Documentation Quality Is a First-Class Requirement

Documentation must be accurate, structured, and implementation-ready. Diagrams, runbooks, troubleshooting notes, and production checklists must be maintained alongside manifests and scripts.

### 10. No Cloud Dependency for the MVP

The MVP must not require AWS credentials, EKS, managed load balancers, cloud disks, cloud IAM, or any cloud-hosted monitoring service. Optional cloud notes may exist only as future extension documentation.

## Technical Guardrails

- Kubernetes distribution for MVP: Kind.
- Primary container runtime: Docker.
- Alternative local runtime: Podman.
- Optional local runtime: Minikube documentation only.
- Kafka operator: Strimzi.
- Kafka mode: KRaft, not ZooKeeper.
- Observability stack: Prometheus, Grafana, and Alertmanager.
- Core topic: `learning-events`.
- Preferred replication factor: 3 where local resources allow it.
- Preferred `min.insync.replicas`: 2 where local resources allow it.
- Producer durability setting: `acks=all`.
- Required failure simulation: delete one broker pod and verify recovery.

## Change Discipline

Changes should preserve the local-first path before adding optional environments. New features should include documentation, validation steps, and operational notes. Any production-sounding claim must be supported by a specific design explanation or clearly scoped as educational.
