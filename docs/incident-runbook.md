# Incident Runbook

## General Incident Flow

1. Identify the failing symptom.
2. Check Kubernetes pod and node state.
3. Check Strimzi custom resource readiness.
4. Check Kafka metrics and alerts.
5. Confirm producer and consumer impact.
6. Apply the smallest safe corrective action.
7. Validate recovery.
8. Record what happened and update docs or automation.

Useful commands:

```sh
kubectl get nodes -o wide
kubectl get pods -n kafka-lab -o wide
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
kubectl describe pod -n kafka-lab <pod-name>
kubectl logs -n kafka-lab <pod-name>
```

## Broker Down

Symptoms:

- One Kafka broker pod is not running or not ready.
- Alerts report broker down.
- Under-replicated partitions may appear.

Checks:

```sh
kubectl get pods -n kafka-lab -o wide
kubectl describe pod -n kafka-lab <broker-pod>
kubectl logs -n kafka-lab <broker-pod>
```

Actions:

- Wait briefly if this was an intentional delete test.
- Confirm Kubernetes creates a replacement pod.
- Check for scheduling, image pull, or volume attach errors.
- Confirm Kafka readiness returns.
- Produce and consume a test message after recovery.

Escalate if:

- The broker cannot mount its volume.
- Multiple brokers are down.
- Under-replicated partitions do not clear.
- Producers or consumers remain unavailable.

## Consumer Lag High

Symptoms:

- Grafana shows lag increasing for the demo consumer group.
- Consumers are running but not keeping up.

Checks:

```sh
kubectl get pods -n kafka-lab
kubectl logs -n kafka-lab <consumer-pod>
```

Actions:

- Confirm consumer is running and connected.
- Confirm topic partitions are available.
- Check for application errors.
- Restart the local consumer only if it is stuck and stateless.
- Reduce producer rate for local testing if the workstation is overloaded.

Escalate if:

- Lag grows after broker recovery.
- Consumers repeatedly crash.
- Topic partitions are unavailable.

## Under-Replicated Partitions

Symptoms:

- Prometheus alert for under-replicated partitions.
- Grafana partition health panel is unhealthy.

Checks:

```sh
kubectl get pods -n kafka-lab -o wide
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Actions:

- Identify whether a broker is down or restarting.
- Check disk, CPU, and memory pressure.
- Wait for replicas to catch up after an intentional broker delete.
- Validate that the alert clears.

Escalate if:

- Under-replication persists after all brokers are ready.
- More than one broker is unavailable.
- Disk pressure or volume errors appear.

## Disk Pressure

Symptoms:

- Kubernetes reports disk pressure.
- Kafka pods are evicted or cannot write.
- PVC usage is high.

Checks:

```sh
kubectl describe node <node-name>
kubectl get pvc -n kafka-lab
kubectl describe pvc -n kafka-lab <pvc-name>
```

Actions:

- Stop producers if this is a local test.
- Delete unneeded local clusters or images.
- Increase local disk allocation if using Docker Desktop or Podman machine.
- Review Kafka retention settings before resuming load.

Escalate if:

- Kafka logs show write failures.
- PVCs cannot bind or mount.
- Data loss is suspected.

## Pod Crash Loop

Symptoms:

- Pod status is `CrashLoopBackOff`.
- Restart count is increasing.

Checks:

```sh
kubectl describe pod -n kafka-lab <pod-name>
kubectl logs -n kafka-lab <pod-name> --previous
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Actions:

- Read the previous container logs.
- Check resource limits and local memory.
- Check configuration errors.
- Check image pull and command errors.
- Apply a targeted fix and watch reconciliation.

Escalate if:

- Strimzi repeatedly rolls Kafka pods.
- The same error affects multiple brokers.
- The operator itself is crash looping.

## Kafka Unavailable

Symptoms:

- Producer cannot send.
- Consumer cannot read.
- Kafka custom resource is not ready.
- Multiple broker pods are unavailable.

Checks:

```sh
kubectl get pods -n kafka-lab -o wide
kubectl get kafka -n kafka-lab
kubectl describe kafka -n kafka-lab <cluster-name>
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Actions:

- Confirm Kubernetes cluster nodes are ready.
- Confirm Strimzi operator is running.
- Check Kafka broker pod status.
- Check persistent volume state.
- Check recent config changes.
- Roll back only the specific bad change if identified.

Escalate if:

- More than one broker is permanently unavailable.
- Volumes are missing or corrupted.
- Kafka custom resources cannot reconcile.
- The issue is outside the local lab and affects shared infrastructure.


---

## Alert Runbooks

The following runbooks map directly to Prometheus alert rules defined in
`observability/prometheus/kafka-alert-rules.yaml`.

### KafkaBrokerDown

**Alert:** `up{job="kafka-brokers"} == 0` for 1 minute.

Symptoms:
- One Kafka broker scrape target is down.
- Prometheus alerts page shows KafkaBrokerDown firing.
- Grafana Active Brokers drops from 3 to 2.

Checks:

```sh
kubectl get pods -n kafka-lab -o wide
kubectl describe pod -n kafka-lab <broker-pod>
kubectl logs -n kafka-lab <broker-pod>
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Actions:
- If this is an intentional `make kill-broker` test: wait for `make verify-ha` to confirm recovery.
- If this is unexpected: check pod scheduling, image pull, and volume attach errors.
- Confirm Kafka readiness returns: `kubectl get kafka -n kafka-lab`.

Resolves when: Prometheus can scrape the broker again and `up == 1`.

---

### KafkaBrokerUnreachable

**Alert:** `up{job="kafka-brokers"} == 0` for 5 minutes.

Same as KafkaBrokerDown but indicates the broker has been unavailable long
enough to suggest a crash loop or scheduling failure rather than a normal restart.

Additional checks:

```sh
kubectl describe pod -n kafka-lab <broker-pod>
kubectl logs -n kafka-lab <broker-pod> --previous
```

---

### KafkaClusterBrokerCountLow

**Alert:** `count(up{job="kafka-brokers"} == 1) < 3` for 2 minutes.

Symptoms:
- Fewer than 3 Kafka brokers are reachable.
- Producer `acks=all` may start failing if fewer than 2 brokers are in sync.

This alert is inhibited when KafkaBrokerDown fires for the same namespace,
so it typically appears without the accompanying KafkaBrokerDown only if
a broker is partially degraded rather than fully down.

Checks and actions: same as KafkaBrokerDown above.

---

### KafkaUnderReplicatedPartitions

**Alert:** `sum(kafka_server_replicamanager_underreplicatedpartitions) > 0` for 2 minutes.

Symptoms:
- One or more partitions have fewer replicas in sync than the replication factor.
- May appear briefly during a broker restart.

Checks:

```sh
kubectl get pods -n kafka-lab -o wide
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Actions:
- If a broker is restarting: wait for it to recover and for ISR to rebuild.
- If all brokers are ready but alert persists: check disk and network pressure.
- Confirm the alert clears within a few minutes of all brokers being ready.

Escalate if: under-replication persists after all brokers are ready.

---

### KafkaOfflinePartitions

**Alert:** `sum(kafka_controller_kafkacontroller_offlinepartitionscount) > 0` for 0 minutes (immediate).

Symptoms:
- One or more topic partitions have no available leader.
- Producers and consumers for affected topics will fail immediately.

Checks:

```sh
kubectl get pods -n kafka-lab -o wide
kubectl get kafka -n kafka-lab
kubectl describe kafka -n kafka-lab kafka-cluster
```

Actions:
- Identify which broker is down and why.
- Confirm Strimzi is reconciling the cluster.
- Check for volume mount or scheduling failures.
- If more than one broker is down, multiple partitions may be offline.

This is a critical alert requiring immediate attention.

---

### KafkaActiveControllerCount

**Alert:** `sum(kafka_controller_kafkacontroller_activecontrollercount) != 1` for 1 minute.

Symptoms:
- There is no active KRaft controller (count = 0) or more than one (unexpected split-brain).

A count of 0 means a controller election is in progress or has failed.
In a healthy 3-node KRaft cluster, one node is always the active controller.

Checks:

```sh
kubectl get pods -n kafka-lab -o wide
kubectl logs -n kafka-lab <broker-pod>
```

---

### StrimziOperatorDown

**Alert:** `up{job="strimzi-operator"} == 0` for 2 minutes.

Symptoms:
- The Strimzi Cluster Operator cannot be scraped.
- Kafka, KafkaTopic, and KafkaUser changes will not reconcile.
- New topics will not be created; broker crashes will not trigger restart logic.

Checks:

```sh
kubectl get pods -n kafka-lab | grep strimzi
kubectl logs -n kafka-lab deploy/strimzi-cluster-operator
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Actions:
- Confirm the Strimzi deployment exists and is scheduled.
- Check for image pull errors or resource pressure.
- Kafka will continue serving existing traffic but no reconciliation occurs.

---

### ConsumerLagHigh

**Alert:** `sum(kafka_consumergroup_lag{topic="learning-events"}) > 100` for 5 minutes.

Symptoms:
- The total consumer group lag for `learning-events` exceeds 100 messages.
- Consumers are falling behind producers.

Note: This alert fires at a low threshold intentionally for the local lab.
In production, tune the threshold to your SLO requirements.

Checks:

```sh
kubectl get pods -n kafka-lab
kubectl logs -n kafka-lab <consumer-pod>
# Or for the local Python consumer:
make port-forward
make consume
```

Actions:
- Confirm the consumer is running and not stuck.
- Check for errors in consumer logs.
- After a broker failure and recovery, lag may spike as consumers reconnect.
- If lag grew during a `make kill-broker` test, run `make consume` to drain it.

---

### KafkaExporterDown

**Alert:** `up{job="kafka-exporter"} == 0` for 2 minutes.

Symptoms:
- Kafka Exporter is unreachable.
- Consumer lag metrics are unavailable in Prometheus and Grafana.

Checks:

```sh
kubectl get pods -n kafka-lab | grep exporter
kubectl logs -n kafka-lab <kafka-exporter-pod>
```

Actions:
- Confirm `kafkaExporter: {}` is set in the Kafka CR.
- Strimzi reconciles the exporter deployment automatically.
- If the pod is crash looping, check for connectivity issues to the Kafka bootstrap.
