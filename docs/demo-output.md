# Demo Output

Validation date: 2026-05-19

Environment used for this validation:

- WSL2 on Docker Desktop.
- Kind `v0.30.0` via `kind.exe`.
- Docker Desktop `4.44.1`.
- Kubernetes node image pinned to `kindest/node:v1.31.1`.
- Strimzi `0.43.0`.
- Kafka `3.7.1` in KRaft mode.
- Python `3.10.12`.

## Step Results

| Step | Result | Evidence |
| --- | --- | --- |
| Makefile targets | PASS | `make -n ...` expanded cluster, Strimzi, Kafka, topic, port-forward, producer, consumer, and failure-test targets. |
| Kind cluster creation | PASS | `make cluster-up-docker` created `kafka-k8s-ha-sre-lab`. |
| Kubernetes nodes | PASS | One control-plane and three workers reached `Ready`. |
| Strimzi installation | PASS | `deployment "strimzi-cluster-operator" successfully rolled out`. |
| Kafka readiness | PASS | Kafka reported `READY=True`, `METADATA STATE=KRaft`. |
| Topic creation | PASS | `learning-events` reported 3 partitions, replication factor 3, `READY=True`. |
| Python requirements | PASS | `kafka-python-2.3.1` installed successfully. |
| Port-forward | PASS | Bootstrap and all three broker ports forwarded to localhost. |
| Producer | PASS | Sent 10/10 messages before broker failure. |
| Consumer | PASS | Consumed 10 messages before broker failure. |
| Broker deletion | PASS | Deleted `kafka-cluster-combined-0`. |
| HA recovery | PASS | All 3 Kafka pods Ready after 44 seconds with broker-only selector. |
| Post-recovery producer | PASS | Sent 3/3 messages after broker recovery. |
| Post-recovery consumer | PASS | Consumed 3 messages after broker recovery. |

## Command Output Excerpts

### Nodes

```text
NAME                                 STATUS   ROLES           VERSION
kafka-k8s-ha-sre-lab-control-plane   Ready    control-plane   v1.31.1
kafka-k8s-ha-sre-lab-worker          Ready    <none>          v1.31.1
kafka-k8s-ha-sre-lab-worker2         Ready    <none>          v1.31.1
kafka-k8s-ha-sre-lab-worker3         Ready    <none>          v1.31.1
```

### Strimzi

```text
deployment "strimzi-cluster-operator" successfully rolled out

Strimzi 0.43.0 is ready in namespace 'kafka-lab'.
```

### Kafka Status

```text
NAME            DESIRED KAFKA REPLICAS   READY   METADATA STATE
kafka-cluster                          3 True    KRaft

NAME                       READY   STATUS
kafka-cluster-combined-0   1/1     Running
kafka-cluster-combined-1   1/1     Running
kafka-cluster-combined-2   1/1     Running
```

### Topic

```text
NAME              CLUSTER         PARTITIONS   REPLICATION FACTOR   READY
learning-events   kafka-cluster   3            3                    True
```

### Producer

```text
Producer starting.
  Bootstrap: localhost:9092
  Topic:     learning-events
  Messages:  10

[1/10] OK  partition=0 offset=0  {"student_id": "u-1000", "course": "math-b1", "event": "lesson_completed", "score": 64, "timestamp": "2026-05-19T15:22:51.955452Z"}
[10/10] OK  partition=1 offset=2  {"student_id": "u-1009", "course": "science-a1", "event": "assignment_submitted", "score": 96, "timestamp": "2026-05-19T15:23:02.327040Z"}

Done. Sent 10/10 messages to 'learning-events'.
```

### Consumer

```text
Consumer starting.
  Bootstrap:  localhost:9092
  Topic:      learning-events
  Group:      sre-lab-consumers

[1] partition=1 offset=0  {"student_id": "u-1002", "course": "coding-101", "event": "quiz_submitted", "score": 100, "timestamp": "2026-05-19T15:22:54.732982Z"}
[10] partition=0 offset=3  {"student_id": "u-1006", "course": "science-a1", "event": "lesson_completed", "score": 63, "timestamp": "2026-05-19T15:22:59.291371Z"}

Done. Consumed 10 messages from 'learning-events'.
```

### Broker Failure

```text
=== Kafka Broker Failure Simulation ===
Namespace: kafka-lab

Target pod: kafka-cluster-combined-0

Deleting pod...
pod "kafka-cluster-combined-0" deleted
```

### HA Verification

```text
=== HA Recovery Verification ===

Namespace:      kafka-lab
Expected pods:  3
Timeout:        180s

  [0s] Pods total=3 ready=2
  [5s] Pods total=3 ready=2
  [10s] Pods total=3 ready=2
  [16s] Pods total=3 ready=2
  [21s] Pods total=3 ready=2
  [28s] Pods total=3 ready=2
  [33s] Pods total=3 ready=2
  [38s] Pods total=3 ready=2
  [44s] Pods total=3 ready=3

PASS: All 3 Kafka pods are Ready. Elapsed: 44s.
```

### Post-Recovery Message Flow

```text
Done. Sent 3/3 messages to 'learning-events'.

Done. Consumed 3 messages from 'learning-events'.
```

## Failures Found And Fixed

- Kind `v0.30.0` defaulted to Kubernetes `v1.34.0`; Strimzi `0.43.0`
  crashed while parsing the API server version field `emulationMajor`.
  Fixed by pinning Kind nodes to `kindest/node:v1.31.1`.
- WSL had Windows `kind.exe` and `kubectl.exe`, but not Linux `kind` or
  `kubectl`. Fixed repo automation by making `KIND_BIN`, `KUBECTL_BIN`,
  and `PYTHON_BIN` overridable.
- A single bootstrap port-forward was not enough for Kafka clients because
  Kafka advertises broker endpoints after bootstrap. Fixed by adding a local
  `cluster-ip` listener and forwarding bootstrap plus broker ports.

## Phase 4 Observability Validation

Validation date: 2026-05-19

Environment:

- WSL2 on Docker Desktop.
- Kind `v0.30.0` via Windows `kind.exe`.
- Docker Desktop `4.44.1`.
- Kubernetes node image pinned to `kindest/node:v1.31.1`.
- Strimzi `0.43.0`.
- Kafka `3.7.1` in KRaft mode.
- Grafana `10.4.3`.
- Prometheus `v2.51.2`.
- Alertmanager `v0.27.0`.
- Python `3.10.12`.

### Phase 4 Validation Task Results

| Task ID | Priority | Description | Commands | Expected result | Actual result | PASS/FAIL | Files changed | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| V4-001 | P0 | Validate repository main branch is clean and up to date. | `git fetch origin main`; `git pull --ff-only`; `git status --short --branch` | Clean `main`, up to date with `origin/main`. | `## main...origin/main`; `Already up to date.` before validation changes. | PASS | None at start | Worktree became dirty only after validation fixes and docs updates. |
| V4-002 | P0 | Validate Kind cluster creation. | `KIND_BIN=/mnt/c/Users/Hatef/AppData/Local/Microsoft/WindowsApps/kind.exe make cluster-up-docker`; `kubectl wait node --all --for=condition=Ready --timeout=180s` | One control-plane and three workers Ready. | All four Kind nodes reached `Ready` on Kubernetes `v1.31.1`. | PASS | None | Existing lab cluster was deleted first for a fresh run. |
| V4-003 | P0 | Validate Strimzi installation. | `make install-strimzi` | Strimzi Cluster Operator rollout succeeds. | `deployment "strimzi-cluster-operator" successfully rolled out`. | PASS | None | Image pull took about 2 minutes. |
| V4-004 | P0 | Validate Kafka KRaft readiness. | `make deploy-kafka`; `kubectl wait kafka/kafka-cluster -n kafka-lab --for=condition=Ready --timeout=600s` | Kafka `READY=True`, `METADATA STATE=KRaft`. | Initial run failed because `kafka-metrics-config` was missing. After fix, Kafka became `READY=True`, `KRaft`. | PASS | `Makefile` | `deploy-kafka` now applies the metrics ConfigMap before the Kafka CR. |
| V4-005 | P0 | Validate `learning-events` topic. | `make create-topic`; `kubectl wait kafkatopic/learning-events -n kafka-lab --for=condition=Ready --timeout=180s` | Topic Ready with replication factor 3. | `learning-events` Ready, 3 partitions, replication factor 3. | PASS | None | Topic Operator reconciled successfully. |
| V4-006 | P0 | Validate producer before observability. | `make port-forward`; `make produce` | Producer sends all messages. | Sent `10/10` messages. | PASS | None | Kafka client used localhost listener and `acks=all`. |
| V4-007 | P0 | Validate consumer before observability. | `make consume` | Consumer reads produced messages. | Consumed `10` messages from `learning-events`. | PASS | None | Consumer group: `sre-lab-consumers`. |
| V4-008 | P0 | Validate observability deployment. | `make deploy-observability` | Prometheus, Grafana, Alertmanager manifests apply. | All manifests applied. Grafana needed a startup-probe fix for clean rollout. | PASS | `observability/grafana/grafana-deployment.yaml` | Initial Grafana pod restarted during cold start. |
| V4-009 | P0 | Validate observability pod status. | `make observability-status` | Prometheus, Grafana, Alertmanager, Kafka Exporter all Ready. | All were `1/1 Running`; current Grafana pod had `0` restarts after fix. | PASS | `observability/grafana/grafana-deployment.yaml` | Startup probe prevents early liveness kills. |
| V4-010 | P0 | Validate Prometheus UI through port-forward. | `make port-forward-prometheus`; `curl http://localhost:9090/-/ready` | Prometheus reachable locally. | `Prometheus Server is Ready.` | PASS | None | Port-forward was restarted after Prometheus rollout restart. |
| V4-011 | P0 | Validate Prometheus targets. | `make validate-observability`; `curl http://localhost:9090/api/v1/targets` | `kafka-brokers`, `kafka-exporter`, `strimzi-operator`, `prometheus` up. | 6/6 targets up: 3 brokers, 1 exporter, 1 Strimzi operator, 1 Prometheus. | PASS | `observability/prometheus/prometheus-config.yaml`; `scripts/validate-observability.sh` | Kafka Exporter target initially failed because Prometheus scraped port 9308; actual Strimzi exporter port is 9404. |
| V4-012 | P0 | Validate Prometheus metrics. | Prometheus API queries | Broker availability, URP, offline partitions, active controller count, and consumer lag visible. | Active brokers `3`; URP `0`; offline `0`; active controller `1`; consumer lag `0`. | PASS | None | Kafka Exporter lag series existed for all three partitions. |
| V4-013 | P0 | Validate Grafana UI through port-forward. | `make port-forward-grafana`; `curl -u admin:admin http://localhost:3000/api/health` | Grafana reachable locally. | API health returned database `ok`, version `10.4.3`. | PASS | None | Login: `admin/admin`. |
| V4-014 | P0 | Validate Grafana Prometheus datasource. | `curl -u admin:admin http://localhost:3000/api/datasources` | Default Prometheus datasource provisioned. | Datasource `Prometheus`, uid `prometheus`, URL `http://prometheus:9090`, `isDefault=true`. | PASS | None | Provisioning ConfigMap loaded. |
| V4-015 | P0 | Validate Kafka Overview dashboard loads. | `curl -u admin:admin http://localhost:3000/api/search?query=Kafka` | Kafka Overview dashboard present. | Dashboard `Kafka Overview`, uid `kafka-overview`, found in `Kafka` folder. | PASS | None | Dashboard URL: `/d/kafka-overview/kafka-overview`. |
| V4-016 | P0 | Validate dashboard panels show real data. | Grafana dashboard API plus Prometheus queries for each panel expression. | Panel queries return Prometheus data. | 10 panels loaded; all panel expressions returned data, including Active Brokers `3`, consumer lag `0`, JVM heap per broker. | PASS | None | Panel validation was API-based. |
| V4-017 | P0 | Validate Alertmanager UI through port-forward. | `make port-forward-alertmanager`; `curl http://localhost:9093/-/ready`; `curl http://localhost:9093/api/v2/status` | Alertmanager reachable locally. | `OK`; status `ready`; null receiver config loaded. | PASS | None | No active alerts before failure. |
| V4-018 | P0 | Trigger broker failure using `make kill-broker`. | `make kill-broker` | One Kafka broker pod is deleted. | Deleted `kafka-cluster-combined-0`. | PASS | None | Replacement pod kept the same pod name and received a new IP. |
| V4-019 | P0 | Validate Prometheus alert behavior during broker failure. | Sampled `/api/v1/alerts` every 15s for 2 minutes. | Relevant alerts become pending/firing according to rule timing. | `KafkaBrokerDown`, `KafkaClusterBrokerCountLow`, `KafkaBrokerUnreachable`, `KafkaUnderReplicatedPartitions`, and `KafkaActiveControllerCount` entered `pending`; none reached `firing` before recovery. | PASS | None | Recovery was faster than the alert `for` durations. |
| V4-020 | P0 | Validate Grafana dashboard shows broker count drop. | Prometheus query used by dashboard: `min_over_time((count(up{job="kafka-brokers"} == 1))[5m:15s])` | Active Brokers drops from 3 to 2 during failure. | Range query returned minimum `2`; instant samples after recovery returned `3`. | PASS | None | Dashboard panel uses the same broker-count expression. |
| V4-021 | P1 | Validate Alertmanager receives relevant alert if routing is active. | `curl http://localhost:9093/api/v2/alerts` during failure window. | Alertmanager receives firing alerts if Prometheus alerts fire. | Alertmanager showed no alerts because all Prometheus alerts resolved before reaching `firing`. | PASS | None | Routing is configured; this short local failure did not exercise a firing route. |
| V4-022 | P0 | Run `make verify-ha`. | `make verify-ha` | All three Kafka broker pods Ready. | PASS at `0s`; all three broker pods `1/1 Running`. | PASS | None | The broker had already recovered before the command ran. |
| V4-023 | P0 | Validate alerts resolve after recovery. | Prometheus and Alertmanager API queries. | No active alerts after recovery. | Prometheus alerts `[]`; Alertmanager alerts `[]`. | PASS | None | URP returned to `0`; active controller returned to `1`. |
| V4-024 | P0 | Validate post-recovery producer. | Restarted `make port-forward`; `make produce` | Producer sends all messages after recovery. | Initial attempt failed with `NoBrokersAvailable` because the old port-forward lost its pod; after restarting port-forward, sent `10/10`. | PASS | `docs/e2e-validation.md`; `docs/troubleshooting.md` | Local port-forward must be restarted after broker deletion if it loses the selected pod. |
| V4-025 | P0 | Validate post-recovery consumer. | `make consume` | Consumer reads post-recovery messages. | Consumed `10` post-recovery messages. | PASS | None | Consumer group offsets advanced correctly. |
| V4-026 | P1 | Update `docs/demo-output.md` with real Phase 4 validation output. | Edited this file. | Real outputs documented. | Phase 4 section added with task results and command excerpts. | PASS | `docs/demo-output.md` | This section is the validation record. |
| V4-027 | P1 | Update `docs/e2e-validation.md` if commands changed or missing. | Edited `docs/e2e-validation.md`. | Observability validation commands documented. | Added deploy/status/port-forward/validation/API checks and post-failure port-forward note. | PASS | `docs/e2e-validation.md` | Previous runbook said Prometheus/Grafana/Alertmanager were not installed. |
| V4-028 | P1 | Update `docs/troubleshooting.md` only if real issues were discovered. | Edited `docs/troubleshooting.md`. | Real issues documented. | Added missing metrics ConfigMap, exporter port, Grafana startup probe, and port-forward recovery notes. | PASS | `docs/troubleshooting.md` | No speculative troubleshooting added. |
| V4-029 | P0 | Produce final validation report. | Final Codex response. | Overall PASS/FAIL and details. | Final report prepared from this validation run. | PASS | None | Report summarizes validated behavior and limitations. |

### Observability Command Output Excerpts

Prometheus, Grafana, Alertmanager, and Kafka Exporter status:

```text
=== Observability Pods ===
NAME                            READY   STATUS    RESTARTS
alertmanager-56cb7d99f5-vr4bn   1/1     Running   0
grafana-6bf9889d58-l6pfs        1/1     Running   0
prometheus-57f4b57778-xz677     1/1     Running   0

=== Kafka Exporter ===
NAME                                            READY   STATUS    RESTARTS
kafka-cluster-kafka-exporter-6d4bd455b4-m47q4   1/1     Running   0
```

`make validate-observability` after fixes:

```text
--- Prometheus target check (requires port-forward on localhost:9090) ---
  Total targets:         6
  Targets up:            6
  Kafka brokers up:      3
  Kafka Exporter up:     1
  Strimzi Operator up:   1
  PASS: All 3 Kafka broker targets are up
  PASS: Kafka Exporter target is up
  PASS: Strimzi Operator target is up

=== Summary ===
  PASS: 10
  FAIL: 0

Observability validation PASSED.
```

Prometheus targets:

```text
kafka-brokers kafka-cluster-combined-0 up http://10.244.2.3:9404/metrics
kafka-brokers kafka-cluster-combined-1 up http://10.244.3.3:9404/metrics
kafka-brokers kafka-cluster-combined-2 up http://10.244.1.4:9404/metrics
kafka-exporter kafka-cluster-kafka-exporter-6d4bd455b4-m47q4 up http://10.244.2.4:9404/metrics
prometheus localhost:9090 up http://localhost:9090/metrics
strimzi-operator strimzi-cluster-operator-7599c657cc-r2gd5 up http://10.244.1.2:8080/metrics
```

Prometheus metric checks before failure:

```text
active_brokers 3
under_replicated_partitions 0
offline_partitions 0
active_controller_count 1
consumer_lag_learning_events 0
```

Grafana API checks:

```text
Grafana health: database ok, version 10.4.3
Datasource: Prometheus, uid prometheus, url http://prometheus:9090, default true
Dashboard: Kafka Overview, uid kafka-overview
Panel count: 10
```

Dashboard panel query samples:

```text
Active Brokers: 3
Under-Replicated Partitions: 0
Offline Partitions: 0
Consumer Lag - learning-events: 0
Broker Target Status: 3 broker series
JVM Heap Usage: 3 broker series
```

Alert rules loaded:

```text
alert_rules=9
KafkaBrokerDown state=inactive
KafkaClusterBrokerCountLow state=inactive
KafkaBrokerUnreachable state=inactive
ConsumerLagHigh state=inactive
KafkaExporterDown state=inactive
KafkaUnderReplicatedPartitions state=inactive
KafkaOfflinePartitions state=inactive
KafkaActiveControllerCount state=inactive
StrimziOperatorDown state=inactive
```

Failure observation after `make kill-broker`:

```text
Target pod: kafka-cluster-combined-0
pod "kafka-cluster-combined-0" deleted

max_under_replicated_5m 53
min_active_brokers_5m 2
max_offline_5m 0
```

Prometheus alert behavior during the two-minute observation window:

```text
KafkaBrokerDown pending
KafkaClusterBrokerCountLow pending
KafkaBrokerUnreachable pending
KafkaUnderReplicatedPartitions pending
KafkaActiveControllerCount pending

Alertmanager alerts: []
```

The broker recovered before any alert satisfied its `for` duration, so
Alertmanager correctly had no routed firing alert for this short local failure.

Post-recovery checks:

```text
make verify-ha
PASS: All 3 Kafka pods are Ready. Elapsed: 0s.

active_brokers 3
under_replicated_partitions 0
offline_partitions 0
active_controller_count 1
consumer_lag_learning_events 0
prometheus_alerts []
alertmanager_alerts []

make produce
Done. Sent 10/10 messages to 'learning-events'.

make consume
Done. Consumed 10 messages from 'learning-events'.
```

### Phase 4 Failures Found And Fixed

- `make deploy-kafka` applied a Kafka CR that referenced
  `kafka-metrics-config` before that ConfigMap existed. Fixed by applying
  `manifests/kafka/kafka-metrics-config.yaml` in the `deploy-kafka` target.
- Prometheus scraped Kafka Exporter on port 9308, but the Strimzi-managed
  exporter exposed metrics on port 9404. Fixed the scrape config and docs.
- `make validate-observability` did not fail when Kafka Exporter or Strimzi
  Operator targets were down, and it treated missing Prometheus port-forward as
  a skip. Fixed the script to validate all required targets and fail when
  Prometheus is unreachable.
- Grafana liveness probes were too aggressive for cold startup on this local
  Docker Desktop/WSL run. Fixed by adding a startup probe and longer health
  probe timeouts.

### Phase 4 Limitations Confirmed

- A short local broker deletion may recover before alert rules reach `firing`.
  In this run, Prometheus showed `pending` alerts and then resolved them; no
  Alertmanager alert was routed.
- `KafkaBrokerUnreachable` has a 5-minute `for` duration and is not expected to
  fire during a two-minute observation window if the broker recovers quickly.
- Local `kubectl port-forward` is not HA. A port-forward attached to a deleted
  broker pod can lose its socket and must be restarted before post-recovery
  producer/consumer tests.
