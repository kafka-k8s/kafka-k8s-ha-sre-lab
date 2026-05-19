# Local Testing Guide

## Primary Path: Kind + Docker

Docker is the primary runtime for this lab.

Prerequisites:

- Docker installed and running.
- Kind installed.
- kubectl installed.
- make installed.

Create the cluster:

```sh
make cluster-up-docker
```

Check nodes:

```sh
make nodes
make status
```

Delete the cluster:

```sh
make cluster-down
```

## Alternative Path: Kind + Podman

Podman is supported as an alternative runtime.

Create the cluster:

```sh
make cluster-up-podman
```

If this fails, check:

- Podman machine or service is running.
- Your Kind version supports the Podman provider on your OS.
- No old cluster with the same name exists.

## Optional Path: Minikube

Minikube is not the main MVP path. It can be used for experiments, but storage, networking, and drivers vary.

If a future Minikube guide is added, it should clearly state:

- Tested driver.
- CPU and memory allocation.
- Storage behavior.
- Differences from the Kind path.

## Hardware Requirements

Minimum expected resources for the full future lab:

- 4 CPU cores.
- 8 GB RAM.
- 20 GB free disk.

Recommended resources:

- 6 to 8 CPU cores.
- 16 GB RAM.
- SSD storage.

Kafka plus observability can be memory-heavy. If the workstation is small, run Kafka first and add Prometheus/Grafana after the cluster is stable.

## Local Limitations

A Kind cluster is useful for learning control-plane behavior and failure workflows, but it is not production infrastructure.

Local testing does not prove:

- Real disk durability.
- Independent node failure domains.
- Rack or availability zone tolerance.
- Production network latency.
- Realistic throughput.
- Multi-cluster disaster recovery.
- Cloud load balancer behavior.

Local testing does help validate:

- Kubernetes manifests.
- Strimzi reconciliation.
- Kafka broker restart behavior.
- Topic and producer/consumer configuration.
- Basic metrics and alert behavior.
- Runbook quality.

## Cluster Validation

After creating the cluster:

```sh
kubectl cluster-info
kubectl get nodes -o wide
kubectl get storageclass
```

Expected result:

- One control-plane node is ready.
- Three worker nodes are ready.
- A default storage class is available.

After future Kafka manifests are implemented:

```sh
kubectl get pods -n kafka-lab
kubectl get kafka -n kafka-lab
kubectl get kafkatopic -n kafka-lab
```

Expected result:

- Strimzi operator is running.
- Kafka custom resource is ready.
- Kafka broker pods are ready.
- `learning-events` topic exists.

