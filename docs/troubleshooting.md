# Troubleshooting

## Kind Cluster Fails

Symptoms:

- `kind create cluster` fails.
- Cluster is created but nodes are not ready.
- Docker or Podman connection errors appear.

Checks:

```sh
docker ps
kind get clusters
kubectl cluster-info
```

For Podman:

```sh
podman ps
kind get clusters
```

Common fixes:

- Start Docker Desktop or Podman machine.
- Delete a partially created cluster with `make cluster-down`.
- Confirm no old cluster with the same name exists.
- Free local CPU, RAM, or disk.
- Upgrade Kind if the local version is very old.

## Podman Provider Issues

Symptoms:

- Kind cannot connect to Podman.
- Cluster creation hangs or fails.
- Nodes start but Kubernetes is not reachable.

Checks:

```sh
podman info
podman ps
```

Common fixes:

- Start the Podman machine or service.
- Confirm `KIND_EXPERIMENTAL_PROVIDER=podman` is set for the command.
- Prefer Docker if Podman support is unstable on the workstation.
- Avoid debugging Podman and Kafka at the same time; validate the cluster first.

## Not Enough RAM

Symptoms:

- Pods stay pending.
- Kafka containers restart.
- Docker Desktop or Podman becomes slow.
- The workstation becomes unresponsive.

Checks:

```sh
kubectl top nodes
kubectl get pods -A
kubectl describe pod -n kafka-lab <pod-name>
```

Common fixes:

- Allocate more memory to Docker Desktop or Podman machine.
- Stop unrelated containers.
- Start with Kafka only, then add observability.
- Reduce local retention and resource requests in future manifests.

## PVC Pending

Symptoms:

- Kafka pods are pending.
- Persistent volume claims are not bound.

Checks:

```sh
kubectl get storageclass
kubectl get pvc -n kafka-lab
kubectl describe pvc -n kafka-lab <pvc-name>
```

Common fixes:

- Confirm a default storage class exists.
- Confirm Kind local storage provisioner is running.
- Recreate the cluster if the storage provisioner is broken.
- Do not assume Kind storage behavior reflects production storage.

## Strimzi Operator Not Ready

Symptoms:

- Strimzi operator pod is pending or crash looping.
- Kafka custom resources do not reconcile.

Checks:

```sh
kubectl get pods -n kafka-lab
kubectl logs -n kafka-lab deploy/strimzi-cluster-operator
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Common fixes:

- Confirm the namespace exists.
- Confirm CRDs were applied.
- Check operator image pull errors.
- Check resource pressure.
- Pin and document the Strimzi version during implementation.

## Kafka Cluster Not Ready

Symptoms:

- Kafka custom resource is not ready.
- Broker pods are pending, crash looping, or not ready.

Checks:

```sh
kubectl get kafka -n kafka-lab
kubectl describe kafka -n kafka-lab <cluster-name>
kubectl get pods -n kafka-lab -o wide
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Common fixes:

- Check storage and PVC state.
- Check memory pressure.
- Check Strimzi operator logs.
- Confirm KRaft settings match the installed Strimzi version.
- Confirm resource requests fit the local machine.

## KafkaTopic Not Created

Symptoms:

- `kubectl get kafkatopic -n kafka-lab` shows no resources or `NotReady`.
- Producer gets a `TopicAuthorizationException` or `UnknownTopicOrPartitionException`.

Checks:

```sh
kubectl get kafkatopic -n kafka-lab
kubectl describe kafkatopic learning-events -n kafka-lab
kubectl get pods -n kafka-lab | grep entity-operator
kubectl logs -n kafka-lab deploy/kafka-cluster-entity-operator -c topic-operator
```

Common fixes:

- The Entity Operator is responsible for creating topics. Confirm it is running.
- The Entity Operator is part of the Kafka CR deployment and starts after the brokers are ready.
- Wait until `kubectl get kafka -n kafka-lab` shows `READY=True` before applying topic manifests.
- Check that the `strimzi.io/cluster: kafka-cluster` label on the KafkaTopic matches the Kafka CR name.

## Port-Forward Fails or Drops

Symptoms:

- `make port-forward` exits immediately.
- Producer or consumer gets `Connection refused` on `localhost:9092`.
- Port-forward works briefly then disconnects.

Checks:

```sh
kubectl get svc -n kafka-lab
kubectl get pods -n kafka-lab
```

Common fixes:

- Confirm the bootstrap service exists: `kubectl get svc kafka-cluster-kafka-bootstrap -n kafka-lab`.
- Confirm all broker pods are running before starting port-forward.
- Port-forward needs a running pod behind the service. If brokers are starting, wait.
- If port-forward drops during a test, restart it: `make port-forward`.
- Port-forward is not suitable for high-throughput production testing; it is fine for local lab use.

## Producer Cannot Connect

Symptoms:

- Producer prints `[ERROR] Cannot connect to Kafka`.
- `NoBrokersAvailable` error from kafka-python.
- Producer hangs on startup.

Checks:

```sh
# Is port-forward running in another terminal?
# Is the bootstrap service healthy?
kubectl get svc -n kafka-lab
kubectl get pods -n kafka-lab
```

Common fixes:

- Start port-forward first: `make port-forward` in a separate terminal.
- Confirm broker pods are in `1/1 Running` state before running the producer.
- Confirm `BOOTSTRAP_SERVERS` is set to `localhost:9092` (the default).
- If the producer times out immediately, check that the port-forward terminal is still active.

## Consumer Receives No Messages

Symptoms:

- Consumer starts and exits after the timeout with `Consumed 0 messages`.
- No error messages.

Checks:

```sh
kubectl get kafkatopic -n kafka-lab
```

Common fixes:

- Confirm the `learning-events` topic was created: `make create-topic`.
- Run the producer first to send messages: `make produce`.
- If the consumer group already committed offsets past all current messages, reset the group or
  use a new `CONSUMER_GROUP` name to start from the beginning.
- Increase `TIMEOUT_SECONDS` if the producer is slow: `TIMEOUT_SECONDS=60 make consume`.

## Grafana Not Accessible

Symptoms:

- Browser cannot reach Grafana.
- Port-forward command fails.
- Grafana pod is not ready.

Checks:

```sh
kubectl get pods -A | grep grafana
kubectl get svc -A | grep grafana
```

Common fixes:

- Confirm Grafana is installed.
- Confirm the namespace.
- Use `kubectl port-forward` to expose Grafana locally.
- Check Grafana pod logs.
- Confirm Prometheus datasource configuration.

## General Debugging Order

Use this order to avoid chasing the wrong layer:

1. Local runtime: Docker or Podman running.
2. Kind cluster: nodes ready.
3. Storage: default storage class and PVCs.
4. Strimzi: operator ready.
5. Kafka: custom resource and broker pods ready.
6. Topic: `learning-events` exists.
7. Clients: producer and consumer configuration.
8. Observability: Prometheus scrape, Grafana panels, Alertmanager routes.

