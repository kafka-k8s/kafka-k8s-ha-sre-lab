# Observability

## Goal

The lab treats observability as a core reliability feature. Kafka HA cannot be evaluated only by checking that pods are running. Operators need Kafka-level signals, Kubernetes signals, and client behavior.

## Metrics

Important metric categories:

- Broker availability.
- Kafka cluster readiness.
- Partition leadership.
- Under-replicated partitions.
- Offline partitions.
- ISR shrink and expansion.
- Request rate and latency.
- Producer errors and retries.
- Consumer lag.
- JVM memory and garbage collection.
- Disk usage and persistent volume pressure.
- Pod restarts and crash loops.

## Prometheus

Prometheus is the local metrics backend.

The future implementation should:

- Scrape Strimzi operator metrics.
- Scrape Kafka broker metrics.
- Scrape Kubernetes pod and node metrics where practical.
- Load Kafka alert rules.
- Expose Prometheus locally for debugging.

Prometheus data in this lab is local and disposable. It is not a long-term metrics store.

## Grafana

Grafana should show enough information to understand the demo scenario without reading raw metrics.

Initial dashboard panels should include:

- Kafka cluster readiness.
- Broker pod status.
- Broker count.
- Under-replicated partitions.
- Offline partitions.
- Consumer lag for `learning-events`.
- Produce and consume rate.
- Pod restarts.
- Disk usage or PVC usage where available.

## Alertmanager

Alertmanager receives alerts from Prometheus and routes them locally.

The MVP should keep routing simple. Future versions can add email, Slack, or webhook receivers, but those must remain optional.

## Important Kafka Alerts

Recommended starting alerts:

- Kafka broker down.
- Kafka cluster not ready.
- Under-replicated partitions greater than zero.
- Offline partitions greater than zero.
- Consumer lag above a defined local threshold.
- Persistent volume usage high.
- Kafka pod crash looping.
- Strimzi operator unavailable.

Alert thresholds should be conservative for local testing and documented as lab defaults.

## Consumer Lag

Consumer lag is one of the most important application-facing Kafka signals. A healthy broker set is not enough if consumers are falling behind.

The lab should use a stable consumer group, such as `learning-events-demo`, so lag can be observed consistently.

Consumer lag can increase during:

- Consumer downtime.
- Broker leadership changes.
- Slow consumer processing.
- Network issues.
- Topic partition imbalance.

## Under-Replicated Partitions

Under-replicated partitions indicate that one or more replicas are not in sync. This can happen during broker failure, slow disks, network issues, or recovery.

In the broker deletion demo, under-replication may briefly appear. The key question is whether it clears after the broker recovers.

## Broker Availability

Broker availability should be monitored at both layers:

- Kubernetes pod status.
- Kafka broker metrics.

A pod can be running while Kafka is not healthy. Kafka-level readiness matters.

## Runbook Integration

Every important alert should map to a runbook entry in [incident-runbook.md](incident-runbook.md). Alerts without actions create noise.

