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

### WSL command shims

Symptoms:

- `make cluster-up-docker` prints `kind: Permission denied` or cannot find `kind`.
- `make nodes` prints `kubectl: Permission denied` or cannot find `kubectl`.
- `docker version` from WSL says Docker Desktop WSL integration is not active.

Checks:

```sh
command -v kind
command -v kubectl
command -v docker
kind.exe version
kubectl.exe version --client
docker.exe version
```

Common fixes:

- Install Linux `kind` and `kubectl` inside WSL, or use the Makefile binary overrides:

  ```sh
  KIND_BIN=kind.exe KUBECTL_BIN=kubectl.exe make cluster-up-docker
  KIND_BIN=kind.exe KUBECTL_BIN=kubectl.exe make nodes
  ```

- If you create the cluster with `kind.exe` but run producer and consumer from WSL, export a kubeconfig for Linux `kubectl` before port-forwarding:

  ```sh
  kind.exe get kubeconfig --name kafka-k8s-ha-sre-lab > /tmp/kafka-lab-kind-kubeconfig
  export KUBECONFIG=/tmp/kafka-lab-kind-kubeconfig
  make port-forward
  ```

- Keep the port-forward and Python producer/consumer in the same OS/network context.

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

### Strimzi crashes on Kubernetes version parsing

Symptoms:

- `make install-strimzi` times out waiting for the Strimzi deployment.
- `strimzi-cluster-operator` repeatedly restarts.
- Operator logs include:

  ```text
  Unrecognized field "emulationMajor" (class io.fabric8.kubernetes.client.VersionInfo)
  Failed to gather environment facts
  ```

Cause:

- Kind `v0.30.0` defaults to Kubernetes `v1.34.0`.
- Strimzi `0.43.0` uses a Fabric8 Kubernetes client version that does not parse the Kubernetes `v1.34.0` version payload.

Fix:

- Use the pinned Kind node image in `kind/kind-cluster.yaml`:

  ```yaml
  image: kindest/node:v1.31.1
  ```

- Recreate the cluster after changing the Kind node image:

  ```sh
  make cluster-down
  make cluster-up-docker
  make install-strimzi
  ```

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

- Confirm the local listener services exist:

  ```sh
  kubectl get svc -n kafka-lab | grep local
  ```

- Confirm all broker pods are running before starting port-forward.
- Port-forward needs a running pod behind the service. If brokers are starting, wait.
- If port-forward drops during a test, restart it: `make port-forward`.
- Port-forward is not suitable for high-throughput production testing; it is fine for local lab use.

The validated local path forwards four services, not just the bootstrap service:

```text
localhost:9092   -> kafka-cluster-kafka-local-bootstrap:9094
localhost:19092  -> kafka-cluster-combined-local-0:9094
localhost:19093  -> kafka-cluster-combined-local-1:9094
localhost:19094  -> kafka-cluster-combined-local-2:9094
```

A single Kafka bootstrap port-forward is not enough for local clients because Kafka returns advertised broker endpoints after the initial bootstrap connection.

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

---

## Observability Troubleshooting

### Prometheus Target Down

Symptoms:
- Prometheus Status → Targets shows a target in `DOWN` state.
- No metrics from Kafka brokers, Kafka Exporter, or Strimzi operator.

Checks:

```sh
kubectl get pods -n kafka-lab -o wide
kubectl get pods -n kafka-lab -l strimzi.io/broker-role=true
kubectl get pods -n kafka-lab -l strimzi.io/name=kafka-cluster-kafka-exporter
kubectl get pods -n kafka-lab -l name=strimzi-cluster-operator
```

For Kafka brokers:
- Confirm `spec.kafka.metricsConfig` is set in the Kafka CR (`kafka-cluster.yaml`).
- Confirm the `kafka-metrics-config` ConfigMap exists.
- The broker pod must be `1/1 Running` for the metrics endpoint to be reachable.

For Kafka Exporter:
- Confirm `spec.kafkaExporter` is set in the Kafka CR.
- Strimzi creates the exporter deployment after the cluster is `READY=True`.
- Check exporter logs: `kubectl logs -n kafka-lab deploy/kafka-cluster-kafka-exporter`.
- In this Strimzi-managed deployment, Kafka Exporter exposes metrics on port
  9404 (`tcp-prometheus`). If Prometheus targets show `kafka-exporter` down on
  port 9308, apply the corrected Prometheus config and restart Prometheus:
  ```sh
  kubectl apply -n kafka-lab -f observability/prometheus/prometheus-config.yaml
  kubectl rollout restart deployment/prometheus -n kafka-lab
  ```

For Strimzi operator:
- Confirm the operator pod is `1/1 Running`.
- The operator exposes metrics on port 8080 by default.

For all targets:
- Confirm the Prometheus ServiceAccount has ClusterRole bound:
  ```sh
  kubectl get clusterrolebinding prometheus
  kubectl get serviceaccount -n kafka-lab prometheus
  ```

### Prometheus RBAC Missing

Symptoms:
- All Kubernetes pod discovery targets fail.
- Prometheus logs show `403 Forbidden` or permission errors.

Checks:

```sh
kubectl get clusterrole prometheus
kubectl get clusterrolebinding prometheus
```

Fix:

```sh
kubectl apply -f observability/prometheus/prometheus-rbac.yaml
```

Note: `kubectl apply -n kafka-lab -f` ignores the namespace flag for
cluster-scoped resources (ClusterRole, ClusterRoleBinding). The
`deploy-observability` Makefile target applies RBAC without `-n`.

### Grafana Cannot Reach Prometheus

Symptoms:
- Grafana dashboard shows "No data" for all panels.
- Grafana Explore shows "Error: error parsing regexp".
- Grafana reports "Failed to call resource" for the Prometheus datasource.

Checks:

```sh
kubectl get svc -n kafka-lab prometheus
kubectl get pods -n kafka-lab -l app=prometheus
# Confirm Grafana datasource config:
kubectl get configmap -n kafka-lab grafana-datasource -o yaml
```

Common fixes:
- Confirm Prometheus pod is `1/1 Running`.
- The datasource URL is `http://prometheus:9090`. If you changed the Service
  name, update the ConfigMap.
- Delete and re-create the Grafana pod to reload provisioning:
  ```sh
  kubectl rollout restart deployment/grafana -n kafka-lab
  ```

### Alertmanager Not Receiving Alerts

Symptoms:
- Prometheus alert rules are firing but Alertmanager UI shows no alerts.
- Alertmanager UI shows "0 active alerts".

Checks:

```sh
kubectl get svc -n kafka-lab alertmanager
kubectl get pods -n kafka-lab -l app=alertmanager
# Check Prometheus alerting config:
kubectl get configmap -n kafka-lab prometheus-config -o yaml | grep alertmanager
```

Common fixes:
- Confirm the Alertmanager Service exists on port 9093.
- Confirm the Prometheus ConfigMap points to `alertmanager:9093`.
- Check if the alert's `for:` duration has elapsed (e.g., `for: 1m` means the
  condition must hold for 1 minute before the alert fires).
- Reload Prometheus config: `curl -X POST http://localhost:9090/-/reload`
  (requires port-forward-prometheus to be running).

### Kafka Metrics Missing

Symptoms:
- Prometheus targets for `kafka-brokers` are UP but no `kafka_*` metrics exist.
- Querying `kafka_server_replicamanager_underreplicatedpartitions` returns no data.

Checks:

```sh
# Confirm metricsConfig is set in Kafka CR:
kubectl get kafka -n kafka-lab kafka-cluster -o jsonpath='{.spec.kafka.metricsConfig}'
# Confirm the ConfigMap exists:
kubectl get configmap -n kafka-lab kafka-metrics-config
# Check broker pod for jmx_exporter process:
kubectl exec -n kafka-lab <broker-pod> -- ls /tmp/jmx_prometheus_javaagent*.jar 2>/dev/null || true
```

Common fixes:
- If `spec.kafka.metricsConfig` is not set, apply the updated Kafka CR:
  ```sh
  make deploy-kafka
  ```
  Strimzi will roll broker pods to add the JMX exporter. Allow 2-5 minutes.
- If the ConfigMap is missing:
  ```sh
  kubectl apply -n kafka-lab -f manifests/kafka/kafka-metrics-config.yaml
  ```
- After the Kafka CR is updated, Strimzi may restart broker pods one at a time.
  Monitor with: `kubectl get pods -n kafka-lab -w`

### Kafka Deploy Fails Because Metrics Config Is Missing

Symptoms:

- `make deploy-kafka` applies the Kafka CR, but Kafka never becomes Ready.
- `kubectl describe kafka kafka-cluster -n kafka-lab` shows:

  ```text
  ConfigMap kafka-metrics-config does not exist
  ```

Cause:

- The Kafka CR references `spec.kafka.metricsConfig`, so the
  `kafka-metrics-config` ConfigMap must exist before Strimzi reconciles Kafka.

Fix:

```sh
make deploy-kafka
```

The `deploy-kafka` target applies `manifests/kafka/kafka-metrics-config.yaml`
before `manifests/kafka/kafka-cluster.yaml`.

If you are debugging an older checkout manually:

```sh
kubectl apply -n kafka-lab -f manifests/kafka/kafka-metrics-config.yaml
kubectl apply -n kafka-lab -f manifests/kafka/kafka-cluster.yaml
```

### Kafka Port-Forward Lost After Broker Deletion

Symptoms:

- `make produce` fails after `make kill-broker` with `NoBrokersAvailable`.
- The `make port-forward` terminal shows `lost connection to pod`.

Cause:

- Local `kubectl port-forward` attaches to selected pods behind the services.
  Deleting a broker can invalidate one of those forwarding streams.

Fix:

1. Stop the stale `make port-forward` terminal.
2. Start it again:

   ```sh
   make port-forward
   ```

3. Re-run producer and consumer:

   ```sh
   make produce
   make consume
   ```

### Port-Forward Conflict

Symptoms:
- `make port-forward-prometheus` fails with "address already in use".
- Port 9090, 3000, or 9093 is occupied by another process.

Checks:

```sh
# Linux/macOS:
lsof -i :9090
lsof -i :3000
lsof -i :9093
```

Common fixes:
- Stop the existing process using the port.
- Override the local port with Makefile variables:
  ```sh
  PROM_LOCAL_PORT=19090 make port-forward-prometheus
  GRAFANA_LOCAL_PORT=13000 make port-forward-grafana
  ALERTMANAGER_LOCAL_PORT=19093 make port-forward-alertmanager
  ```

### Grafana Dashboard Shows "No Data"

Symptoms:
- Grafana dashboard loads but all panels show "No data" or "N/A".

Common causes and fixes:

1. **Prometheus target is not yet up**: Wait for broker pods to be ready and
   Prometheus to complete a scrape cycle (up to 15 seconds after deploy).

2. **metricsConfig not yet applied**: Strimzi needs to roll broker pods after
   `make deploy-kafka` updates the Kafka CR. This takes 2-5 minutes.

3. **Wrong time range**: The dashboard defaults to "Last 1 hour". If
   observability was just deployed, no historical data exists. Set the time
   range to "Last 15 minutes" or "Last 5 minutes" to see recent data.

4. **Grafana datasource misconfigured**: Go to Configuration → Data Sources →
   Prometheus → Test. If it fails, check the Service name and port.

5. **Consumer lag panel empty**: The consumer lag panel requires Kafka Exporter
   (`kafkaExporter` in Kafka CR) and a consumer group to have committed offsets.
   Run `make produce` and `make consume` first.

### Grafana Restarts During First Startup

Symptoms:

- Grafana eventually becomes Ready, but the pod has one or more restarts.
- Events show liveness probe failures while Grafana is still starting:

  ```text
  Liveness probe failed: Get "http://<pod-ip>:3000/api/health": connect: connection refused
  ```

Cause:

- On slower local Docker Desktop or WSL environments, Grafana startup and SQLite
  migrations can take longer than a short liveness delay.

Fix:

- Use the manifest with the Grafana `startupProbe` and longer readiness/liveness
  timeouts:

  ```sh
  kubectl apply -n kafka-lab -f observability/grafana/grafana-deployment.yaml
  kubectl rollout status deployment/grafana -n kafka-lab --timeout=600s
  ```

### Observability Pods Not Starting

Symptoms:
- Prometheus, Grafana, or Alertmanager pods stay in `Pending` or `CrashLoopBackOff`.

Checks:

```sh
kubectl describe pod -n kafka-lab <pod-name>
kubectl logs -n kafka-lab <pod-name>
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Common fixes:
- **Pending**: Check resource pressure. Observability pods need approximately
  450 MB RAM total. Free up resources or increase Docker Desktop/Podman limits.
- **ImagePullBackOff**: Check internet connectivity. The images are pulled from
  Docker Hub (prom/prometheus, grafana/grafana, prom/alertmanager).
- **CrashLoopBackOff for Prometheus**: Check that the config ConfigMap syntax
  is valid. A YAML error in prometheus.yml causes immediate crash.
- **CrashLoopBackOff for Grafana**: Check that the provisioning ConfigMaps
  have valid YAML. Grafana is strict about provisioning file format.
