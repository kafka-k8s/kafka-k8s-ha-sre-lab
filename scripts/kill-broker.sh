#!/usr/bin/env bash
# kill-broker.sh
# Deletes one running Kafka broker pod to simulate a broker failure.
# Kubernetes and Strimzi will restart the pod automatically.
#
# Environment variables:
#   NAMESPACE   Kubernetes namespace (default: kafka-lab)
#
# Usage:
#   NAMESPACE=kafka-lab bash scripts/kill-broker.sh

set -euo pipefail

NAMESPACE=${NAMESPACE:-"kafka-lab"}

echo "=== Kafka Broker Failure Simulation ==="
echo "Namespace: ${NAMESPACE}"
echo ""

# Find one running Kafka broker pod by the Strimzi cluster label.
# KafkaNodePool pods carry the strimzi.io/cluster label.
POD=$(kubectl get pods -n "${NAMESPACE}" \
  -l "strimzi.io/cluster=kafka-cluster" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [[ -z "${POD}" ]]; then
  echo "ERROR: No running Kafka pods found in namespace '${NAMESPACE}'."
  echo ""
  echo "Check pod state with:"
  echo "  kubectl get pods -n ${NAMESPACE}"
  exit 1
fi

echo "Target pod: ${POD}"
echo ""
echo "Deleting pod..."
kubectl delete pod -n "${NAMESPACE}" "${POD}"

echo ""
echo "Pod '${POD}' deleted."
echo ""
echo "What happens next:"
echo "  1. Kubernetes detects the pod is gone and starts a replacement."
echo "  2. Strimzi reconciles the Kafka cluster state."
echo "  3. Kafka leadership elections occur for any affected partitions."
echo "  4. Replicas on other brokers continue serving clients (if ISR >= min.insync.replicas)."
echo ""
echo "Monitor recovery:"
echo "  kubectl get pods -n ${NAMESPACE} -w"
echo "  make verify-ha"
