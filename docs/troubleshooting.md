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

## Producer Cannot Connect

Symptoms:

- Producer times out.
- Bootstrap server cannot be resolved.
- Authentication fails.

Checks:

```sh
kubectl get svc -n kafka-lab
kubectl get pods -n kafka-lab
```

Common fixes:

- Confirm the bootstrap service name and port.
- Use port-forwarding for local host-based producer tests if needed.
- Confirm Kafka listener configuration.
- Confirm producer credentials if SASL/SCRAM is enabled.
- Confirm topic exists.

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

