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
