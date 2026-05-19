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

---

## Deploying Observability

After the Kafka cluster is ready and the topic is created, deploy the
observability stack with a single command:

```sh
make deploy-observability
```

This applies:
- Kafka broker JMX metrics ConfigMap and updates the Kafka CR.
- Prometheus RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding).
- Prometheus ConfigMap, alert rules, Deployment, and Service.
- Grafana datasource, dashboard provider, Kafka Overview dashboard, Deployment, and Service.
- Alertmanager config, Deployment, and Service.

Allow 1-2 minutes for all pods to reach Ready state.

Check status:

```sh
make observability-status
```

## Accessing Observability UIs

Each UI requires a port-forward (run each in a separate terminal):

**Terminal A:**
```sh
make port-forward-prometheus
# Prometheus: http://localhost:9090
```

**Terminal B:**
```sh
make port-forward-grafana
# Grafana: http://localhost:3000  Login: admin / admin
```

**Terminal C:**
```sh
make port-forward-alertmanager
# Alertmanager: http://localhost:9093
```

## Validating Observability

Run the automated validation (after observability is deployed):

```sh
make validate-observability
```

This checks:
- Prometheus pod is 1/1 Ready.
- Grafana pod is 1/1 Ready.
- Alertmanager pod is 1/1 Ready.
- Kafka Exporter pod is 1/1 Ready.
- With `make port-forward-prometheus` running: checks that all 3 Kafka broker
  targets, the Kafka Exporter target, and the Strimzi Operator target are UP.

For manual validation:

```sh
# Check Prometheus targets
# Open: http://localhost:9090/targets
# Expected: kafka-brokers (3 up), kafka-exporter (1 up), strimzi-operator (1 up)

# Check Kafka metric
curl -s 'http://localhost:9090/api/v1/query?query=kafka_server_replicamanager_underreplicatedpartitions' \
  | python3 -m json.tool

# Check consumer lag (after running producer and consumer)
curl -s 'http://localhost:9090/api/v1/query?query=kafka_consumergroup_lag' \
  | python3 -m json.tool
```

## Full Local Validation Flow Including Observability

```sh
# 1. Create the cluster
make cluster-up-docker
make nodes

# 2. Install Strimzi
make install-strimzi

# 3. Deploy Kafka
make deploy-kafka
make status

# 4. Create topic
make create-topic

# 5. Install Python dependency
pip install -r apps/requirements.txt

# 6. In Terminal A: start Kafka port-forward
make port-forward

# 7. In Terminal B: produce events
make produce

# 8. In Terminal C: consume events
make consume

# 9. Deploy observability
make deploy-observability
make observability-status

# 10. In separate terminals: access UIs
make port-forward-prometheus    # http://localhost:9090
make port-forward-grafana       # http://localhost:3000
make port-forward-alertmanager  # http://localhost:9093

# 11. Validate observability
make validate-observability

# 12. Trigger broker failure
make kill-broker

# 13. Watch recovery
make verify-ha

# 14. Observe in Prometheus (Status → Alerts):
#     KafkaBrokerDown should fire within 1 minute of kill-broker
#     KafkaBrokerDown should resolve after verify-ha reports PASS

# 15. Check Grafana Kafka Overview:
#     Active Brokers drops from 3 to 2 during failure
#     Broker Target Status drops to 0 for the deleted pod
#     Active Brokers returns to 3 after recovery

# 16. Run producer and consumer again to confirm continued message flow
make produce
make consume
```

## Observability Local Limitations

- Prometheus metrics are lost when the pod restarts (emptyDir storage).
- Grafana user data is lost when the pod restarts. Provisioned dashboards survive.
- No real alerting: Alertmanager uses a null receiver. No external notifications are sent.
- No Kafka restart-count alerts without kube-state-metrics.
- All components share the same Kind cluster. They do not provide independent failure detection.

See [docs/observability.md](observability.md) for complete observability documentation.
