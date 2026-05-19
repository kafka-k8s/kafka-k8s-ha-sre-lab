# Observability

## Goal

The lab treats observability as a core reliability feature. Kafka HA cannot be
evaluated only by checking that pods are running. Operators need Kafka-level
signals, Kubernetes signals, and client behavior to understand the actual state
of the cluster.

Phase 4 of this project implements a working local observability layer using
Prometheus, Grafana, and Alertmanager. Everything runs inside the Kind cluster.
No cloud service, managed monitoring platform, or Prometheus Operator is needed.

## Architecture

```
Kafka Brokers (port 9404)    ──┐
Kafka Exporter (port 9404)   ──┼──→ Prometheus (port 9090) ──→ Alertmanager (port 9093)
Strimzi Operator (port 8080) ──┘           │
                                           ↓
                                     Grafana (port 3000)
```

All components run in the `kafka-lab` namespace alongside Kafka.

Local access is through `kubectl port-forward`. No Ingress or LoadBalancer is
required.

## Quick Start

```sh
# After make deploy-kafka and make create-topic:
make deploy-observability
make observability-status

# In separate terminals (each port-forward blocks):
make port-forward-prometheus        # http://localhost:9090
make port-forward-grafana           # http://localhost:3000  (admin/admin)
make port-forward-alertmanager      # http://localhost:9093

# Validate:
make validate-observability
```

## Kafka Metrics

### JMX Prometheus Exporter

Strimzi starts the JMX Prometheus Exporter on each broker pod when
`spec.kafka.metricsConfig` is set in the Kafka CR. The exporter listens on
port 9404 and translates JMX beans to Prometheus metrics.

The exporter configuration is in:

```
manifests/kafka/kafka-metrics-config.yaml
```

Key metrics categories captured:

| Category             | Example Metric                                           |
|----------------------|----------------------------------------------------------|
| Throughput           | `kafka_server_brokertopicmetrics_messagesinpersec_total` |
| Replication health   | `kafka_server_replicamanager_underreplicatedpartitions`  |
| Partition health     | `kafka_controller_kafkacontroller_offlinepartitionscount`|
| Controller           | `kafka_controller_kafkacontroller_activecontrollercount` |
| ISR events           | `kafka_server_replicamanager_isrshrinkspersec_total`     |
| Request rates        | `kafka_network_requestmetrics_requests_total`            |
| JVM heap             | `jvm_memory_heap_used`                                   |
| JVM GC               | `jvm_gc_collection_total`                                |

### Kafka Exporter

Strimzi deploys a Kafka Exporter pod when `spec.kafkaExporter` is set in the
Kafka CR. In this Strimzi-managed deployment, the Exporter exposes consumer
group lag and topic partition metrics on the `tcp-prometheus` port 9404.

Key metrics from Kafka Exporter:

| Metric                                  | Description                          |
|-----------------------------------------|--------------------------------------|
| `kafka_consumergroup_lag`               | Lag per group + topic + partition    |
| `kafka_consumergroup_current_offset`    | Current consumer offset              |
| `kafka_topic_partition_current_offset`  | Latest message offset                |
| `kafka_topic_partitions`                | Number of partitions per topic       |
| `kafka_topic_partition_in_sync_replica` | In-sync replica count                |

Consumer lag is the most important client-facing Kafka signal. Without Kafka
Exporter, lag is not visible in Prometheus.

## Prometheus

### Scrape Strategy

Prometheus uses Kubernetes pod-role service discovery to find scrape targets
dynamically. No static pod IPs are hardcoded.

| Job              | Port | Label filter                                         |
|------------------|------|------------------------------------------------------|
| kafka-brokers    | 9404 | `strimzi.io/broker-role=true`                        |
| kafka-exporter   | 9404 | `strimzi.io/name=kafka-cluster-kafka-exporter`       |
| strimzi-operator | 8080 | `name=strimzi-cluster-operator`                      |
| prometheus       | 9090 | static self-scrape                                   |

### Alert Rules

Alert rules are in `observability/prometheus/kafka-alert-rules.yaml` and
loaded from `/etc/prometheus/rules/` inside the Prometheus pod.

| Alert                          | Condition                                                        | Severity | For  |
|--------------------------------|------------------------------------------------------------------|----------|------|
| KafkaBrokerDown                | `up{job="kafka-brokers"} == 0`                                   | critical | 1m   |
| KafkaBrokerUnreachable         | `up{job="kafka-brokers"} == 0`                                   | critical | 5m   |
| KafkaClusterBrokerCountLow     | `count(up{job="kafka-brokers"} == 1) < 3`                        | warning  | 2m   |
| KafkaUnderReplicatedPartitions | `sum(replicamanager_underreplicatedpartitions) > 0`              | warning  | 2m   |
| KafkaOfflinePartitions         | `sum(kafkacontroller_offlinepartitionscount) > 0`                | critical | 0m   |
| KafkaActiveControllerCount     | `sum(kafkacontroller_activecontrollercount) != 1`                | critical | 1m   |
| StrimziOperatorDown            | `up{job="strimzi-operator"} == 0`                                | critical | 2m   |
| ConsumerLagHigh                | `sum(kafka_consumergroup_lag{topic="learning-events"}) > 100`    | warning  | 5m   |
| KafkaExporterDown              | `up{job="kafka-exporter"} == 0`                                  | warning  | 2m   |

### Validating Prometheus Targets

```sh
make port-forward-prometheus
# Then in another terminal:
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep '"health"'
```

Or open the Prometheus UI → Status → Targets.

Expected targets:
- `kafka-brokers`: 3 pods up
- `kafka-exporter`: 1 pod up
- `strimzi-operator`: 1 pod up
- `prometheus`: 1 instance up

## Grafana

### Datasource

Prometheus is provisioned automatically as the default datasource with
`uid=prometheus`. The provisioning ConfigMap is in
`observability/grafana/grafana-datasource.yaml`.

### Dashboard: Kafka Overview

The `kafka-overview` dashboard is provisioned from
`observability/grafana/kafka-dashboard.yaml`. It loads automatically at
Grafana startup from `/var/lib/grafana/dashboards/`.

Dashboard panels:

| Panel                       | Query                                                                    | Type        |
|-----------------------------|--------------------------------------------------------------------------|-------------|
| Active Brokers              | `count(up{job="kafka-brokers"} == 1)`                                    | Stat        |
| Under-Replicated Partitions | `sum(kafka_server_replicamanager_underreplicatedpartitions)`             | Stat        |
| Offline Partitions          | `sum(kafka_controller_kafkacontroller_offlinepartitionscount)`           | Stat        |
| Strimzi Operator            | `max(up{job="strimzi-operator"}) or on() vector(0)`                      | Stat        |
| Messages In/sec             | `sum(rate(kafka_server_brokertopicmetrics_messagesinpersec_total[5m]))` | Time series |
| Consumer Lag                | `sum by (consumergroup) (kafka_consumergroup_lag{topic="learning-events"})` | Time series |
| ISR Shrink/Expand Rate      | `rate(isrshrinkspersec_total[5m])` + `rate(isrexpandspersec_total[5m])` | Time series |
| Broker Target Status        | `up{job="kafka-brokers"}`                                                | Time series |
| Bytes In/Out per sec        | Rate of bytes in and out                                                 | Time series |
| JVM Heap Usage              | `jvm_memory_heap_used{job="kafka-brokers"}`                              | Time series |

### Accessing Grafana

```sh
make port-forward-grafana
# Open: http://localhost:3000
# Login: admin / admin
# Navigate to: Dashboards → Kafka → Kafka Overview
```

### Official Strimzi Dashboards

The starter dashboard covers the key signals for this lab. For a more
comprehensive dashboard set, import the official Strimzi Grafana dashboards:

1. Download from the Strimzi GitHub repository:
   ```
   https://github.com/strimzi/strimzi-kafka-operator/tree/main/examples/metrics/grafana-dashboards
   ```

2. In Grafana UI: `+` → Import → Upload JSON file.
   - `strimzi-kafka.json` — detailed Kafka broker metrics.
   - `strimzi-operators.json` — Strimzi operator metrics.
   - `strimzi-kafka-exporter.json` — consumer lag and topic metrics.

### Default Credentials

Grafana admin credentials are `admin / admin` for the local lab. Never use
these defaults on any shared or production system. Use a Kubernetes Secret for
`GF_SECURITY_ADMIN_PASSWORD` in production.

## Alertmanager

### Routing

The local Alertmanager uses a `null-receiver` that accepts all alerts without
sending external notifications. This is appropriate for a learning lab where
the goal is to observe alert behavior, not page a team.

Grouping configuration:
- Group by `alertname` and `namespace`.
- `group_wait: 30s` — batch related alerts.
- `repeat_interval: 1h` — silence for 1 hour before re-notifying.

Inhibit rule: `KafkaClusterBrokerCountLow` is suppressed when
`KafkaBrokerDown` fires for the same namespace, to reduce alert noise.

### Accessing Alertmanager

```sh
make port-forward-alertmanager
# Open: http://localhost:9093
```

### Future Integrations

To add a real receiver, edit `observability/alertmanager/alertmanager-config.yaml`:

```yaml
receivers:
  - name: slack
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/...'
        channel: '#kafka-alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## Validation Commands

```sh
# Check observability pods
make observability-status

# Run automated checks
make validate-observability

# Query Prometheus directly (requires port-forward-prometheus)
curl -s 'http://localhost:9090/api/v1/query?query=up{job="kafka-brokers"}' | python3 -m json.tool

# Check alert rules loaded
curl -s 'http://localhost:9090/api/v1/rules' | python3 -m json.tool | grep '"name"'

# Check active alerts
curl -s 'http://localhost:9090/api/v1/alerts' | python3 -m json.tool

# Check Kafka broker metric (under-replicated partitions)
curl -s 'http://localhost:9090/api/v1/query?query=kafka_server_replicamanager_underreplicatedpartitions' | python3 -m json.tool

# Check consumer lag
curl -s 'http://localhost:9090/api/v1/query?query=kafka_consumergroup_lag' | python3 -m json.tool
```

## Observability During Broker Failure

Expected alert sequence when `make kill-broker` is run:

1. Broker pod is deleted.
2. Prometheus next scrape fails for that broker.
3. `KafkaBrokerDown` fires after 1 minute (for: 1m).
4. `KafkaClusterBrokerCountLow` fires after 2 minutes.
5. `KafkaUnderReplicatedPartitions` may fire if replication degrades.
6. Grafana: Active Brokers drops from 3 to 2.
7. Grafana: Broker Target Status drops to 0 for the deleted pod.

Expected recovery sequence when `make verify-ha` reports PASS:

1. Broker pod restarts and becomes ready.
2. Prometheus scrapes the broker again.
3. `KafkaBrokerDown` resolves.
4. `KafkaClusterBrokerCountLow` resolves.
5. `KafkaUnderReplicatedPartitions` resolves as replicas catch up.
6. Grafana: Active Brokers returns to 3.

## Local Limitations

- **Ephemeral metrics**: Prometheus uses emptyDir. All metric history is lost
  when the Prometheus pod restarts. Acceptable for a local lab.

- **Ephemeral Grafana state**: User-created dashboards and preferences are
  lost on pod restart. Provisioned dashboards (from ConfigMaps) survive.

- **No persistent alert state**: Alertmanager silences and notification log
  are lost on pod restart.

- **No authentication hardening**: Grafana uses admin/admin. Prometheus and
  Alertmanager have no auth. Do not expose these endpoints outside a local
  machine without authentication.

- **No restart-count alerting**: KafkaPodCrashLooping based on Kubernetes
  restart counts requires kube-state-metrics, which is not deployed in this
  phase. Persistent unavailability is covered by KafkaBrokerUnreachable
  (fires after 5 minutes of target being down).

- **No cross-namespace scraping restrictions**: Prometheus can discover pods
  in any namespace. In production, restrict the ClusterRole scope.

- **All components co-located**: Prometheus, Grafana, Alertmanager, and Kafka
  share the same Kind cluster. Losing the cluster loses all observability. In
  production, run the monitoring stack independently.
