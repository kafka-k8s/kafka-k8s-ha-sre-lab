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
- A default storage class is available (Kind ships a `standard` local provisioner).

## Installing Strimzi

```sh
make install-strimzi
```

The script downloads the Strimzi release manifest, replaces the default namespace,
and applies it to the cluster. Wait for the operator pod:

```sh
kubectl get pods -n kafka-lab
```

Expected: one `strimzi-cluster-operator-*` pod in `Running` state.

See [manifests/strimzi/README.md](../manifests/strimzi/README.md) for details.

## Deploying Kafka

```sh
make deploy-kafka
```

Strimzi reads the `Kafka` and `KafkaNodePool` custom resources and provisions the cluster.
Allow 2-5 minutes for three broker pods to become ready.

Monitor progress:

```sh
make status
kubectl get pods -n kafka-lab -w
```

All three `kafka-cluster-combined-*` pods must reach `1/1 Running`.

```sh
kubectl get kafka -n kafka-lab
```

The `READY` column should show `True`.

## Creating the Topic

```sh
make create-topic
```

The Entity Operator (part of the Strimzi deployment) creates the `learning-events` topic.
Verify:

```sh
kubectl get kafkatopic -n kafka-lab
```

## Running the Producer and Consumer

The Python apps connect via `localhost:9092`. Port-forwarding bridges the local
machine to the Kafka local listener bootstrap service and to the three
advertised broker ports. Kafka clients need the broker ports because broker
metadata returned after bootstrap must be reachable from the local machine.

Install the Python dependency once:

```sh
pip install -r apps/requirements.txt
```

In **terminal 1**, start port-forward (leave this running):

```sh
make port-forward
```

Expected forwarded ports:

```text
localhost:9092   -> local bootstrap
localhost:19092  -> broker 0
localhost:19093  -> broker 1
localhost:19094  -> broker 2
```

In **terminal 2**, send 10 events:

```sh
make produce
```

In **terminal 3**, consume events:

```sh
make consume
```

Customize with environment variables:

```sh
MESSAGE_COUNT=50 DELAY_SECONDS=0.2 make produce
TIMEOUT_SECONDS=60 CONSUMER_GROUP=my-group make consume
```

## Broker Failure Simulation

Delete one broker pod and watch recovery:

```sh
make kill-broker
```

In a separate terminal, wait for the cluster to recover:

```sh
make verify-ha
```

Expected output: `PASS: All 3 Kafka pods are Ready.`

After recovery, run the producer and consumer again to confirm continued message flow.

## Resetting the Lab

To start from a clean state:

```sh
make cluster-down
make cluster-up-docker
make install-strimzi
make deploy-kafka
make create-topic
```
