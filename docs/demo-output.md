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
