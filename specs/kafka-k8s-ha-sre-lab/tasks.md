# P0 Local MVP Validation Tasks

Only P0 validation tasks are in scope for this pass. Do not add AWS/EKS,
Elasticsearch, observability, or new feature work.

| ID | Priority | Task | Acceptance Criteria |
| --- | --- | --- | --- |
| V-001 | P0 | Validate Makefile targets. | Required targets exist and expand to the expected Kind, Strimzi, Kafka, topic, producer, consumer, and failure-test commands. |
| V-002 | P0 | Validate Kind cluster creation. | `make cluster-up-docker` creates one control-plane node and three workers. |
| V-003 | P0 | Validate Kubernetes nodes. | `make nodes` shows all four nodes as `Ready`. |
| V-004 | P0 | Validate Strimzi installation. | `make install-strimzi` completes and `strimzi-cluster-operator` is `1/1 Running`. |
| V-005 | P0 | Validate Kafka readiness. | `make deploy-kafka` completes and `kubectl get kafka -n kafka-lab` shows `READY=True`, `METADATA STATE=KRaft`. |
| V-006 | P0 | Validate topic creation. | `make create-topic` creates `learning-events` with `READY=True`, 3 partitions, and replication factor 3. |
| V-007 | P0 | Validate producer connectivity. | `make produce` sends all requested records to `learning-events`. |
| V-008 | P0 | Validate consumer connectivity. | `make consume` reads the produced records from `learning-events`. |
| V-009 | P0 | Validate broker failure recovery. | `make kill-broker` deletes one broker pod and `make verify-ha` reports `PASS`. |
| V-010 | P0 | Validate post-recovery message flow. | Producer and consumer still work after broker recovery. |
| V-011 | P0 | Add `docs/demo-output.md`. | File includes real or template command output for each validation step. |
| V-012 | P0 | Add `docs/e2e-validation.md`. | File includes exact commands to reproduce the local validation flow. |
| V-013 | P0 | Update troubleshooting with real fixes. | `docs/troubleshooting.md` documents the actual Kind/Strimzi and port-forward fixes. |
| V-014 | P0 | Fix README only where commands are inaccurate. | README quick-start commands remain accurate for the validated MVP path. |

---

# Phase 4 Observability Tasks

## Phase O1: Metrics Foundation

| ID | Priority | Task | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| O1-001 | P0 | Create Kafka JMX metrics ConfigMap. | `manifests/kafka/kafka-metrics-config.yaml` | ConfigMap created with JMX exporter rules covering BrokerTopicMetrics, ReplicaManager, KafkaController, RequestMetrics, and JVM. |
| O1-002 | P0 | Update Kafka CR to enable broker metrics. | `manifests/kafka/kafka-cluster.yaml` | `spec.kafka.metricsConfig` references kafka-metrics-config ConfigMap. `kubectl get kafka -n kafka-lab` shows `READY=True` after apply. |
| O1-003 | P0 | Add Kafka Exporter to Kafka CR. | `manifests/kafka/kafka-cluster.yaml` | `spec.kafkaExporter` is set. Strimzi creates a `kafka-cluster-kafka-exporter` pod. |

## Phase O2: Prometheus

| ID | Priority | Task | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| O2-001 | P0 | Create Prometheus RBAC. | `observability/prometheus/prometheus-rbac.yaml` | ServiceAccount, ClusterRole (pod/service/endpoint read), and ClusterRoleBinding created in kafka-lab. |
| O2-002 | P0 | Create Prometheus scrape ConfigMap. | `observability/prometheus/prometheus-config.yaml` | Four scrape jobs defined: prometheus, kafka-brokers, kafka-exporter, strimzi-operator. Alertmanager routing configured. |
| O2-003 | P0 | Create Kafka alert rules ConfigMap. | `observability/prometheus/kafka-alert-rules.yaml` | Nine alert rules defined covering broker down, replication health, controller, operator, and consumer lag. |
| O2-004 | P0 | Create Prometheus Deployment. | `observability/prometheus/prometheus-deployment.yaml` | Pod reaches 1/1 Ready. Config and rules ConfigMaps mounted correctly. |
| O2-005 | P0 | Create Prometheus Service. | `observability/prometheus/prometheus-service.yaml` | ClusterIP Service on port 9090. Grafana can reach it at `http://prometheus:9090`. |
| O2-006 | P0 | Add Makefile target: deploy-observability. | `Makefile` | `make deploy-observability` applies all observability manifests without error. |
| O2-007 | P0 | Add Makefile target: port-forward-prometheus. | `Makefile` | `make port-forward-prometheus` forwards to localhost:9090. Prometheus UI is accessible. |

## Phase O3: Grafana

| ID | Priority | Task | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| O3-001 | P0 | Create Grafana datasource provisioning ConfigMap. | `observability/grafana/grafana-datasource.yaml` | Grafana auto-configures Prometheus datasource with uid=prometheus pointing to http://prometheus:9090. |
| O3-002 | P0 | Create Grafana dashboard provider ConfigMap. | `observability/grafana/grafana-dashboard-provider.yaml` | Grafana loads dashboards from /var/lib/grafana/dashboards/ on startup. |
| O3-003 | P0 | Create Kafka Overview dashboard ConfigMap. | `observability/grafana/kafka-dashboard.yaml`, `observability/grafana/dashboards/kafka-overview.json` | Dashboard loads in Grafana with 10 panels: broker count, under-replicated partitions, offline partitions, Strimzi status, messages in/sec, consumer lag, ISR rates, broker target status, bytes in/out, JVM heap. |
| O3-004 | P0 | Create Grafana Deployment. | `observability/grafana/grafana-deployment.yaml` | Pod reaches 1/1 Ready. All provisioning ConfigMaps mounted. Dashboard visible in UI. |
| O3-005 | P0 | Create Grafana Service. | `observability/grafana/grafana-service.yaml` | ClusterIP Service on port 3000. |
| O3-006 | P0 | Add Makefile target: port-forward-grafana. | `Makefile` | `make port-forward-grafana` forwards to localhost:3000. Grafana UI accessible at http://localhost:3000 with admin/admin. |
| O3-007 | P1 | Document official Strimzi Grafana dashboards as recommended import. | `docs/observability.md` | Import path documented for strimzi-kafka.json and strimzi-operators.json from the Strimzi GitHub repository. |

## Phase O4: Alertmanager

| ID | Priority | Task | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| O4-001 | P0 | Create Alertmanager config ConfigMap. | `observability/alertmanager/alertmanager-config.yaml` | Routing config with null receiver, inhibit rules, and grouping by alertname and namespace. |
| O4-002 | P0 | Create Alertmanager Deployment. | `observability/alertmanager/alertmanager-deployment.yaml` | Pod reaches 1/1 Ready. Config ConfigMap mounted correctly. |
| O4-003 | P0 | Create Alertmanager Service. | `observability/alertmanager/alertmanager-service.yaml` | ClusterIP Service on port 9093. Prometheus routes alerts to `http://alertmanager:9093`. |
| O4-004 | P0 | Add Makefile target: port-forward-alertmanager. | `Makefile` | `make port-forward-alertmanager` forwards to localhost:9093. Alertmanager UI accessible. |

## Phase O5: Validation

| ID | Priority | Task | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| O5-001 | P0 | Create validate-observability.sh script. | `scripts/validate-observability.sh` | Script checks readiness of Prometheus, Grafana, Alertmanager, and Kafka Exporter pods. Exits 0 on PASS. |
| O5-002 | P0 | Add Makefile target: validate-observability. | `Makefile` | `make validate-observability` runs the script and reports PASS/FAIL. |
| O5-003 | P0 | Add Makefile target: observability-status. | `Makefile` | `make observability-status` shows observability pods and services. |
| O5-004 | P0 | Validate Prometheus targets in local lab. | n/a | After deploy, Prometheus Status → Targets shows kafka-brokers (3 targets up), kafka-exporter (1 up), strimzi-operator (1 up). |
| O5-005 | P0 | Validate Kafka metrics are visible. | n/a | Prometheus Graph: `kafka_server_replicamanager_underreplicatedpartitions` returns data from at least one broker. |
| O5-006 | P0 | Validate Grafana dashboard loads. | n/a | Kafka Overview dashboard loads in Grafana. Active Brokers panel shows 3. |
| O5-007 | P0 | Validate alert fires during broker failure. | n/a | After `make kill-broker`, KafkaBrokerDown fires in Prometheus alerts within 1 minute. Alert resolves after `make verify-ha`. |
| O5-008 | P0 | Validate consumer lag metric. | n/a | After `make produce` and `make consume`, kafka_consumergroup_lag metric is visible in Prometheus for the sre-lab-consumers group. |

## Phase O6: Documentation

| ID | Priority | Task | Files Affected | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| O6-001 | P0 | Update docs/observability.md with implementation details. | `docs/observability.md` | Document scrape strategy, alert rules, dashboard panels, validation commands, and local limitations. |
| O6-002 | P0 | Update docs/incident-runbook.md with alert mappings. | `docs/incident-runbook.md` | Each implemented alert has a runbook entry with checks and actions. |
| O6-003 | P0 | Update docs/troubleshooting.md with observability issues. | `docs/troubleshooting.md` | Sections added for: Prometheus targets down, Grafana cannot reach Prometheus, Alertmanager not receiving alerts, Kafka metrics missing, port-forward conflict. |
| O6-004 | P0 | Update docs/local-testing.md with observability flow. | `docs/local-testing.md` | Full end-to-end validation flow including observability deploy, port-forward, and alert test. |
| O6-005 | P0 | Update README.md with observability commands and access. | `README.md` | Observability quick start section added. Phase 4 marked complete in roadmap. |
