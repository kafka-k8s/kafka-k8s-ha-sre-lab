# Architecture

## Overview

`kafka-k8s-ha-sre-lab` is a local-first Kafka HA lab. It uses Kind to run a Kubernetes cluster on a developer workstation and Strimzi to operate Kafka in KRaft mode.

The architecture is intentionally small enough to run locally, but it mirrors production concerns: broker placement, persistent storage, replication, monitoring, alerts, runbooks, and failure testing.

## Infrastructure Diagram

![Infrastructure architecture diagram](images/infrastructure-architecture.png)

## Component Diagram

```mermaid
flowchart TB
  subgraph Workstation["Developer Workstation"]
    Runtime["Docker primary\nPodman alternative"]
    Kubectl["kubectl and make"]
    Apps["Python producer and consumer"]

    subgraph Kind["Kind Kubernetes Cluster"]
      CP["Control-plane node"]
      W1["Worker node 1"]
      W2["Worker node 2"]
      W3["Worker node 3"]

      subgraph KafkaNs["Namespace: kafka-lab"]
        Strimzi["Strimzi Cluster Operator"]
        Kafka["Kafka KRaft Cluster\n3 brokers where possible"]
        Topic["KafkaTopic\nlearning-events"]
        Users["KafkaUser resources\nfuture authenticated clients"]
      end

      subgraph ObsNs["Observability"]
        Prom["Prometheus"]
        Grafana["Grafana"]
        Alerts["Alertmanager"]
      end
    end
  end

  Kubectl --> Kind
  Runtime --> Kind
  Strimzi --> Kafka
  Strimzi --> Topic
  Strimzi --> Users
  Apps --> Kafka
  Prom --> Kafka
  Prom --> Strimzi
  Grafana --> Prom
  Prom --> Alerts
```

## Request and Metrics Flow

```mermaid
sequenceDiagram
  participant User
  participant Make as Makefile
  participant K8s as Kubernetes API
  participant Strimzi as Strimzi Operator
  participant Kafka as Kafka Brokers
  participant Producer as Python Producer
  participant Consumer as Python Consumer
  participant Prom as Prometheus
  participant Grafana

  User->>Make: make cluster-up-docker
  Make->>K8s: kind create cluster
  User->>Make: make install-strimzi
  Make->>K8s: apply operator manifests
  K8s->>Strimzi: start operator
  User->>Make: make deploy-kafka
  Make->>K8s: apply Kafka custom resource
  Strimzi->>Kafka: reconcile KRaft cluster
  User->>Make: make create-topic
  Strimzi->>Kafka: create learning-events
  Producer->>Kafka: publish educational events
  Consumer->>Kafka: consume educational events
  Prom->>Kafka: scrape broker metrics
  Prom->>Strimzi: scrape operator metrics
  Grafana->>Prom: query Kafka health
```

## Kubernetes Design

The Kind cluster has one control-plane node and three worker nodes. The worker count is deliberate: it allows the lab to demonstrate spreading Kafka broker pods across separate Kubernetes nodes.

This is still a single-machine lab. It does not provide real hardware isolation, rack awareness, power isolation, or independent disk failure domains.

## Kafka Design

Kafka runs in KRaft mode. ZooKeeper is not used.

The intended Kafka deployment uses three brokers where local resources allow. The topic `learning-events` should use replication factor 3 and `min.insync.replicas=2`. Producers should use `acks=all`.

These settings demonstrate a common durability pattern: a write is acknowledged only after enough in-sync replicas have the data.

## Observability Design

Prometheus collects metrics from Strimzi and Kafka. Grafana visualizes operational state. Alertmanager receives local alerts.

The first dashboards and alerts should focus on:

- Broker availability.
- Kafka cluster readiness.
- Under-replicated partitions.
- Offline partitions.
- Consumer lag.
- Disk pressure and PVC usage.
- Pod restarts and crash loops.

## Failure Testing Design

The required MVP failure test is deleting one Kafka broker pod.

Expected behavior:

1. Kubernetes marks the pod deleted.
2. Kafka temporarily loses one broker.
3. Replicas on remaining brokers continue serving partitions where ISR is sufficient.
4. Strimzi and Kubernetes recreate the broker pod.
5. Kafka rejoins replicas and returns partitions to a healthy state.
6. Producer and consumer validation succeeds after recovery.

This is a broker restart test. It is not a full disaster recovery test.

## Extension Points

Future versions can add:

- Strimzi manifests pinned to a tested version.
- Grafana dashboards as JSON.
- PrometheusRule resources.
- MirrorMaker 2.
- k3s, kubeadm, or EKS guides.
- GitOps with Argo CD or Flux.
- Load testing and upgrade testing.
