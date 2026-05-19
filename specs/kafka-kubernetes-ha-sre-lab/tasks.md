# Task Breakdown: kafka-kubernetes-ha-sre-lab

## Phase 1: Repository Foundation

| ID | Priority | Description | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| P1-001 | P0 | Create README with project purpose, quick start, scope, and roadmap. | `README.md` | README explains local-first Kafka HA lab, Docker primary path, Podman alternative, limitations, and resume value. |
| P1-002 | P0 | Create project constitution. | `CONSTITUTION.md` | Constitution includes local-first design, reproducibility, SRE thinking, production trade-offs, observability, failure testing, security, simplicity, documentation quality, and no cloud dependency. |
| P1-003 | P0 | Create specs directory and core spec files. | `specs/kafka-kubernetes-ha-sre-lab/*` | Spec, clarification, plan, and tasks exist and are internally consistent. |
| P1-004 | P0 | Create docs directory and architecture overview. | `docs/architecture.md` | Architecture document includes component descriptions and Mermaid diagrams. |

## Phase 2: Local Kubernetes Foundation

| ID | Priority | Description | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| P2-001 | P0 | Add Kind cluster config. | `kind/kind-cluster.yaml` | Config defines one control-plane and three worker nodes. |
| P2-002 | P0 | Add Makefile targets for Docker and Podman cluster flows. | `Makefile` | `cluster-up-docker`, `cluster-up-podman`, `cluster-down`, `nodes`, and `status` targets exist. |
| P2-003 | P1 | Add local setup documentation. | `docs/local-testing.md`, `README.md` | Docs explain Docker, Podman, optional Minikube, hardware requirements, and local limitations. |

## Phase 3: Strimzi and Kafka

| ID | Priority | Description | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| P3-001 | P0 | Add namespace manifest. | `manifests/namespace.yaml` | Namespace `kafka-lab` can be applied with `kubectl`. |
| P3-002 | P0 | Add Strimzi installation instructions or manifests. | `manifests/strimzi/`, `README.md`, `docs/local-testing.md` | Strimzi can be installed locally and operator readiness can be checked. |
| P3-003 | P0 | Add Kafka KRaft manifest. | `manifests/kafka/` | Kafka custom resource deploys a three-broker KRaft cluster where resources allow. |
| P3-004 | P0 | Add topic manifest. | `manifests/topics/` | `learning-events` topic is created with documented partitions, replication factor, and `min.insync.replicas`. |
| P3-005 | P1 | Add user manifest if needed. | `manifests/users/` | Producer and consumer user access is defined or deliberately deferred with explanation. |

## Phase 4: Producer and Consumer

| ID | Priority | Description | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| P4-001 | P0 | Add Python producer. | `apps/producer.py` | Producer sends JSON educational platform events to `learning-events` with `acks=all`. |
| P4-002 | P0 | Add Python consumer. | `apps/consumer.py` | Consumer reads events from `learning-events` using a stable consumer group. |
| P4-003 | P0 | Add Python dependencies. | `apps/requirements.txt` | Dependencies install successfully in a virtual environment. |
| P4-004 | P1 | Add sample event payloads. | `apps/sample-events.jsonl` | Sample includes educational platform events such as lesson completion and quiz score events. |

## Phase 5: Observability

| ID | Priority | Description | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| P5-001 | P0 | Add Prometheus config. | `observability/prometheus/` | Prometheus can scrape Strimzi and Kafka metrics locally. |
| P5-002 | P1 | Add Grafana dashboard placeholder or import instructions. | `observability/grafana/`, `docs/observability.md` | Dashboard guidance covers broker health, partition health, and consumer lag. |
| P5-003 | P1 | Add Alertmanager config. | `observability/alertmanager/` | Alertmanager can receive local Prometheus alerts. |
| P5-004 | P0 | Add alert rules. | `observability/prometheus/` | Rules cover broker down, under-replicated partitions, offline partitions, and high consumer lag. |

## Phase 6: Failure Testing

| ID | Priority | Description | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| P6-001 | P0 | Add broker kill script. | `scripts/kill-broker.sh` | Script deletes one Kafka broker pod by label or explicit pod name and prints recovery instructions. |
| P6-002 | P0 | Add cluster health check script. | `scripts/check-cluster-health.sh` | Script checks Kubernetes pods, Strimzi resource readiness, and Kafka topic availability. |
| P6-003 | P0 | Add HA verification script. | `scripts/verify-ha.sh` | Script validates the delete-broker scenario and confirms producer/consumer flow after recovery. |
| P6-004 | P0 | Add incident runbook. | `docs/incident-runbook.md` | Runbook covers broker down, consumer lag, under-replicated partitions, disk pressure, crash loops, and Kafka unavailable. |

## Phase 7: Documentation Polish

| ID | Priority | Description | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| P7-001 | P0 | Complete Kubernetes vs VM trade-off document. | `docs/kubernetes-vs-vm.md` | Document explains advantages, risks, storage concerns, operational complexity, team maturity, and final recommendation. |
| P7-002 | P0 | Complete troubleshooting document. | `docs/troubleshooting.md` | Document covers common local failures and concrete diagnostic commands. |
| P7-003 | P0 | Complete production checklist. | `docs/production-checklist.md` | Checklist covers storage, node isolation, monitoring, alerting, security, backup, DR, capacity, upgrades, runbooks, and access control. |
| P7-004 | P0 | Complete README quick start. | `README.md` | README has Docker and Podman quick starts plus an optional Minikube note. |

## Phase 8: Validation

| ID | Priority | Description | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| P8-001 | P0 | Validate YAML. | `kind/`, `manifests/`, `observability/` | YAML parses and Kubernetes resources are structurally valid where tools are available. |
| P8-002 | P0 | Validate Makefile commands. | `Makefile` | Makefile target list works and safe placeholder targets do not perform destructive actions. |
| P8-003 | P0 | Validate documentation consistency. | `README.md`, `docs/`, `specs/` | Docs consistently describe Docker primary, Podman alternative, Kind primary, KRaft mode, and no AWS dependency. |
| P8-004 | P0 | Validate local setup flow. | `README.md`, `docs/local-testing.md`, `Makefile` | A clean machine can follow the documented setup path to the current implementation stage. |
| P8-005 | P0 | Validate no AWS dependency exists in MVP. | All docs and scripts | No MVP command requires AWS credentials, EKS, IAM, cloud storage, or cloud load balancers. |

