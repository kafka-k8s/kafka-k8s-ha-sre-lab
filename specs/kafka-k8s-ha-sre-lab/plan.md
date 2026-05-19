# Local MVP Validation Plan: kafka-k8s-ha-sre-lab

## Goal

Prove the current MVP works end-to-end on a local Kind cluster using Docker as
the primary runtime. This validation pass does not add AWS, EKS,
Elasticsearch, Prometheus, Grafana, Alertmanager, or any new feature scope.

## Scope

In scope:

- Create a local Kind cluster.
- Install Strimzi.
- Deploy the Kafka KRaft cluster.
- Create the `learning-events` topic.
- Run the local Python producer and consumer.
- Delete one Kafka broker pod.
- Verify the broker pod recovers.
- Confirm producer and consumer flow still works after broker recovery.
- Document command output and minimal fixes discovered during validation.

Out of scope:

- AWS or EKS.
- Elasticsearch.
- Prometheus, Grafana, Alertmanager, dashboards, or alert rules.
- Architecture rewrites.
- Security hardening beyond documenting local lab defaults.
- Performance or production sizing tests.

## Validation Flow

Run the MVP in this order:

1. `make cluster-up-docker`
2. `make nodes`
3. `make install-strimzi`
4. `make deploy-kafka`
5. `make status`
6. `make create-topic`
7. `pip install -r apps/requirements.txt`
8. `make port-forward`
9. `make produce`
10. `make consume`
11. `make kill-broker`
12. `make verify-ha`
13. Run producer and consumer once more after recovery.
14. Capture outputs in `docs/demo-output.md`.
15. Record exact commands in `docs/e2e-validation.md`.
16. Record real fixes in `docs/troubleshooting.md`.

## Current Local Fixes Required By Validation

- Kind must use a Kubernetes version compatible with Strimzi `0.43.0`.
  The cluster config pins `kindest/node:v1.31.1`; Kind `v0.30.0` otherwise
  defaults to Kubernetes `v1.34.0`, where Strimzi `0.43.0` crashes while
  parsing the API server version payload.
- Makefile command binaries are overridable through `KIND_BIN`,
  `KUBECTL_BIN`, and `PYTHON_BIN`. This keeps normal Linux/macOS usage
  unchanged while allowing WSL users to run `kind.exe` and `kubectl.exe`
  where needed.
- Local Kafka clients need more than a single bootstrap port-forward.
  The Kafka manifest includes a `local` `cluster-ip` listener with
  `localhost` advertised broker ports, and `make port-forward` forwards
  bootstrap plus all three broker services.

## Acceptance Criteria

The validation passes when:

- Kind creates one control-plane node and three worker nodes.
- All four Kubernetes nodes are `Ready`.
- Strimzi Cluster Operator rolls out successfully.
- Kafka reports `READY=True` and `METADATA STATE=KRaft`.
- All three Kafka pods report `1/1 Running`.
- `learning-events` reports `READY=True`, `PARTITIONS=3`, and
  `REPLICATION FACTOR=3`.
- Producer sends all requested messages with `acks=all`.
- Consumer reads the produced messages.
- Deleting one Kafka broker pod does not prevent recovery.
- `make verify-ha` reports `PASS`.
- Producer and consumer still work after broker recovery.

## Production Honesty

This validation proves a local educational workflow only. It does not prove
production storage durability, independent failure domains, multi-zone
placement, throughput, noisy-neighbor behavior, cloud load balancer behavior,
or disaster recovery.

---

# Phase 4 Observability Implementation Plan

## Goal

Deploy a working local observability layer for the Kafka HA SRE lab using
Prometheus, Grafana, and Alertmanager. Observability runs in the same Kind
cluster as Kafka, in the same `kafka-lab` namespace, with no cloud dependency.

## Scope

In scope:

- Kafka broker JMX metrics via Strimzi JMX Prometheus Exporter.
- Kafka Exporter for consumer group lag metrics.
- Strimzi operator metrics scraping.
- Prometheus deployment with Kubernetes pod discovery and alert rules.
- Grafana deployment with provisioned datasource and Kafka Overview dashboard.
- Alertmanager deployment with local routing (no external integrations).
- Makefile targets for deploy, delete, status, port-forward, and validate.
- Updated documentation and runbooks.

Out of scope:

- kube-state-metrics or node-exporter (add in a future phase).
- External alert integrations (Slack, email, PagerDuty).
- Production storage for metrics data (emptyDir used for lab).
- Prometheus Operator (plain Deployment used for simplicity).
- Security hardening (next phase: SASL/SCRAM, ACLs, NetworkPolicy).

## Observability Validation Flow

```sh
make deploy-observability
make observability-status

# In separate terminals:
make port-forward-prometheus   # http://localhost:9090
make port-forward-grafana      # http://localhost:3000  (admin/admin)
make port-forward-alertmanager # http://localhost:9093

make validate-observability

# Trigger alerts:
make kill-broker
# Observe in Prometheus: Status → Alerts
# Observe in Grafana: Active Brokers drops, Broker Target Status drops to 0
# Observe in Alertmanager: KafkaBrokerDown alert fires

make verify-ha
# Confirm alerts resolve after broker recovery
```

## Files Created

```
manifests/kafka/kafka-metrics-config.yaml    JMX exporter ConfigMap
manifests/kafka/kafka-cluster.yaml           Updated: metricsConfig + kafkaExporter

observability/prometheus/
  prometheus-rbac.yaml                       ServiceAccount, ClusterRole, ClusterRoleBinding
  prometheus-config.yaml                     ConfigMap: prometheus.yml with scrape jobs
  kafka-alert-rules.yaml                     ConfigMap: 9 alert rules
  prometheus-deployment.yaml                 Deployment
  prometheus-service.yaml                    ClusterIP Service (port 9090)

observability/grafana/
  grafana-datasource.yaml                    ConfigMap: Prometheus datasource provisioning
  grafana-dashboard-provider.yaml            ConfigMap: dashboard provider config
  kafka-dashboard.yaml                       ConfigMap: Kafka Overview dashboard (10 panels)
  grafana-deployment.yaml                    Deployment
  grafana-service.yaml                       ClusterIP Service (port 3000)
  dashboards/kafka-overview.json             Raw dashboard JSON for direct import

observability/alertmanager/
  alertmanager-config.yaml                   ConfigMap: routing config (null receiver)
  alertmanager-deployment.yaml               Deployment
  alertmanager-service.yaml                  ClusterIP Service (port 9093)

scripts/validate-observability.sh            Validation script
```

## Prometheus Scrape Strategy

| Job              | Discovery              | Port | Label filter                                   |
|------------------|------------------------|------|------------------------------------------------|
| kafka-brokers    | pod role, kafka-lab ns | 9404 | strimzi.io/broker-role=true                    |
| kafka-exporter   | pod role, kafka-lab ns | 9308 | strimzi.io/name=kafka-cluster-kafka-exporter   |
| strimzi-operator | pod role, kafka-lab ns | 8080 | name=strimzi-cluster-operator                  |
| prometheus       | static localhost       | 9090 | n/a                                            |

## Alert Rules

| Alert                        | Condition                                                | Severity | For  |
|------------------------------|----------------------------------------------------------|----------|------|
| KafkaBrokerDown              | up{job="kafka-brokers"} == 0                             | critical | 1m   |
| KafkaBrokerUnreachable       | up{job="kafka-brokers"} == 0                             | critical | 5m   |
| KafkaClusterBrokerCountLow   | count(up{job="kafka-brokers"} == 1) < 3                  | warning  | 2m   |
| KafkaUnderReplicatedPartitions | sum(replicamanager_underreplicatedpartitions) > 0      | warning  | 2m   |
| KafkaOfflinePartitions       | sum(kafkacontroller_offlinepartitionscount) > 0          | critical | 0m   |
| KafkaActiveControllerCount   | sum(kafkacontroller_activecontrollercount) != 1          | critical | 1m   |
| StrimziOperatorDown          | up{job="strimzi-operator"} == 0                          | critical | 2m   |
| ConsumerLagHigh              | sum(kafka_consumergroup_lag{topic="learning-events"}) > 100 | warning | 5m |
| KafkaExporterDown            | up{job="kafka-exporter"} == 0                            | warning  | 2m   |

## Production Limitations

- Prometheus data is ephemeral (emptyDir). All metrics are lost when the pod restarts.
- Grafana user data (saved dashboards, preferences) is ephemeral. Provisioned dashboard survives restart.
- Alertmanager silences and inhibitions are ephemeral.
- No authentication hardening on Grafana (admin/admin), Prometheus, or Alertmanager.
- No PersistentVolumeClaims for any observability component.
- No Prometheus HA or federation.
- Consumer lag restart-count alerting requires kube-state-metrics (not deployed).
- All observability is co-located with Kafka on the same Kind cluster (no network separation).
