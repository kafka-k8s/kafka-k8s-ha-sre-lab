# Kafka HA Design

![Broker failure recovery diagram](images/broker-failure-recovery.png)

## High Availability Goal

The lab demonstrates how Kafka remains functional during a single broker pod failure when topic replication and producer durability settings are configured correctly.

The target local pattern is:

- Three Kafka brokers where possible.
- Replication factor 3 for `learning-events`.
- `min.insync.replicas=2`.
- Producer `acks=all`.
- Failure simulation by deleting one broker pod.

## Brokers

A Kafka broker stores partition replicas and serves producer and consumer traffic. In this lab, each broker runs as a Kubernetes pod managed by Strimzi.

Kubernetes can restart a failed broker pod. Kafka replication is what keeps data available while a broker is unavailable.

## Controllers

In KRaft mode, Kafka uses its own metadata quorum instead of ZooKeeper. Controllers manage cluster metadata, leader election, and partition leadership state.

For the MVP, the exact controller layout should be chosen based on Strimzi support and local resource budget. The documentation and manifests must make that choice explicit when implemented.

## Replication Factor

Replication factor defines how many copies of each partition exist.

For `learning-events`, the target replication factor is 3 where local resources allow. This means each partition has three replicas across brokers.

Replication factor protects against broker loss only when replicas are placed on different brokers and enough replicas remain healthy.

## ISR

ISR means in-sync replicas. These are replicas that are caught up enough to be considered safe for acknowledged writes.

When a broker fails, replicas on that broker leave ISR. If enough in-sync replicas remain, the topic can continue accepting durable writes.

## min.insync.replicas

`min.insync.replicas` defines the minimum number of in-sync replicas required for a successful write when producers use `acks=all`.

For this lab, the target value is 2. With three replicas and `min.insync.replicas=2`, Kafka can tolerate one broker failure while still accepting durable writes, assuming two replicas remain in sync.

## acks=all

Producer `acks=all` means the producer waits for all required in-sync replicas before treating a write as successful.

This setting is important because replication factor alone is not enough. A producer using weak acknowledgements can receive success before data is safely replicated.

## Broker Failure Behavior

During the broker deletion test:

1. One broker pod is deleted.
2. Kafka detects broker loss.
3. Leaders may move if the deleted broker held partition leadership.
4. ISR shrinks for affected partitions.
5. Kubernetes creates a replacement pod.
6. The broker rejoins the cluster.
7. Replicas catch up.
8. ISR returns to normal.

Expected temporary symptoms:

- Some partitions may briefly report reduced ISR.
- Alerts may fire for broker down or under-replicated partitions.
- Producer sends may retry during leadership changes.
- Consumer lag may temporarily increase.

## Kubernetes Role in HA

Kubernetes provides:

- Pod scheduling.
- Pod restart.
- Persistent volume attachment.
- Service discovery.
- Health and readiness behavior.
- Declarative reconciliation through Strimzi.

Kubernetes does not provide Kafka data replication by itself.

## Kafka Role in HA

Kafka provides:

- Partition replication.
- Leader election.
- ISR tracking.
- Producer acknowledgement semantics.
- Consumer offset management.
- Topic-level durability behavior.

Kafka HA comes from correct Kafka configuration plus healthy infrastructure. Kubernetes is the orchestration layer, not the source of Kafka durability.

## Local HA Limitations

Kind worker nodes are containers on one machine. A local Kind cluster cannot prove:

- Real rack isolation.
- Cloud availability zone tolerance.
- Independent disk failure behavior.
- Production network behavior.
- Sustained throughput under real load.

The lab is still valuable because it makes Kafka and Strimzi failure behavior visible and repeatable.
