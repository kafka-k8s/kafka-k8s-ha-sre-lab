# Incident Runbook

## General Incident Flow

1. Identify the failing symptom.
2. Check Kubernetes pod and node state.
3. Check Strimzi custom resource readiness.
4. Check Kafka metrics and alerts.
5. Confirm producer and consumer impact.
6. Apply the smallest safe corrective action.
7. Validate recovery.
8. Record what happened and update docs or automation.

Useful commands:

```sh
kubectl get nodes -o wide
kubectl get pods -n kafka-lab -o wide
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
kubectl describe pod -n kafka-lab <pod-name>
kubectl logs -n kafka-lab <pod-name>
```

## Broker Down

Symptoms:

- One Kafka broker pod is not running or not ready.
- Alerts report broker down.
- Under-replicated partitions may appear.

Checks:

```sh
kubectl get pods -n kafka-lab -o wide
kubectl describe pod -n kafka-lab <broker-pod>
kubectl logs -n kafka-lab <broker-pod>
```

Actions:

- Wait briefly if this was an intentional delete test.
- Confirm Kubernetes creates a replacement pod.
- Check for scheduling, image pull, or volume attach errors.
- Confirm Kafka readiness returns.
- Produce and consume a test message after recovery.

Escalate if:

- The broker cannot mount its volume.
- Multiple brokers are down.
- Under-replicated partitions do not clear.
- Producers or consumers remain unavailable.

## Consumer Lag High

Symptoms:

- Grafana shows lag increasing for the demo consumer group.
- Consumers are running but not keeping up.

Checks:

```sh
kubectl get pods -n kafka-lab
kubectl logs -n kafka-lab <consumer-pod>
```

Actions:

- Confirm consumer is running and connected.
- Confirm topic partitions are available.
- Check for application errors.
- Restart the local consumer only if it is stuck and stateless.
- Reduce producer rate for local testing if the workstation is overloaded.

Escalate if:

- Lag grows after broker recovery.
- Consumers repeatedly crash.
- Topic partitions are unavailable.

## Under-Replicated Partitions

Symptoms:

- Prometheus alert for under-replicated partitions.
- Grafana partition health panel is unhealthy.

Checks:

```sh
kubectl get pods -n kafka-lab -o wide
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Actions:

- Identify whether a broker is down or restarting.
- Check disk, CPU, and memory pressure.
- Wait for replicas to catch up after an intentional broker delete.
- Validate that the alert clears.

Escalate if:

- Under-replication persists after all brokers are ready.
- More than one broker is unavailable.
- Disk pressure or volume errors appear.

## Disk Pressure

Symptoms:

- Kubernetes reports disk pressure.
- Kafka pods are evicted or cannot write.
- PVC usage is high.

Checks:

```sh
kubectl describe node <node-name>
kubectl get pvc -n kafka-lab
kubectl describe pvc -n kafka-lab <pvc-name>
```

Actions:

- Stop producers if this is a local test.
- Delete unneeded local clusters or images.
- Increase local disk allocation if using Docker Desktop or Podman machine.
- Review Kafka retention settings before resuming load.

Escalate if:

- Kafka logs show write failures.
- PVCs cannot bind or mount.
- Data loss is suspected.

## Pod Crash Loop

Symptoms:

- Pod status is `CrashLoopBackOff`.
- Restart count is increasing.

Checks:

```sh
kubectl describe pod -n kafka-lab <pod-name>
kubectl logs -n kafka-lab <pod-name> --previous
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Actions:

- Read the previous container logs.
- Check resource limits and local memory.
- Check configuration errors.
- Check image pull and command errors.
- Apply a targeted fix and watch reconciliation.

Escalate if:

- Strimzi repeatedly rolls Kafka pods.
- The same error affects multiple brokers.
- The operator itself is crash looping.

## Kafka Unavailable

Symptoms:

- Producer cannot send.
- Consumer cannot read.
- Kafka custom resource is not ready.
- Multiple broker pods are unavailable.

Checks:

```sh
kubectl get pods -n kafka-lab -o wide
kubectl get kafka -n kafka-lab
kubectl describe kafka -n kafka-lab <cluster-name>
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
```

Actions:

- Confirm Kubernetes cluster nodes are ready.
- Confirm Strimzi operator is running.
- Check Kafka broker pod status.
- Check persistent volume state.
- Check recent config changes.
- Roll back only the specific bad change if identified.

Escalate if:

- More than one broker is permanently unavailable.
- Volumes are missing or corrupted.
- Kafka custom resources cannot reconcile.
- The issue is outside the local lab and affects shared infrastructure.

