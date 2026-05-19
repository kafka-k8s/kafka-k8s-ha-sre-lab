#!/usr/bin/env bash
# verify-ha.sh
# Waits for all Kafka broker pods to return to Ready state after a failure.
# Prints PASS or FAIL with elapsed time.
#
# This script verifies local pod recovery behavior only.
# It does not prove production-grade data durability or multi-zone HA.
#
# Environment variables:
#   NAMESPACE   Kubernetes namespace (default: kafka-lab)
#   TIMEOUT     Seconds to wait before failing (default: 180)
#
# Usage:
#   NAMESPACE=kafka-lab TIMEOUT=180 bash scripts/verify-ha.sh

set -euo pipefail

NAMESPACE=${NAMESPACE:-"kafka-lab"}
TIMEOUT=${TIMEOUT:-180}
EXPECTED_PODS=3
POLL_INTERVAL=5

echo "=== HA Recovery Verification ==="
echo ""
echo "NOTE: This verifies local pod recovery behavior only."
echo "      It does not prove production HA, data durability,"
echo "      or multi-zone / multi-region fault tolerance."
echo ""
echo "Namespace:      ${NAMESPACE}"
echo "Expected pods:  ${EXPECTED_PODS}"
echo "Timeout:        ${TIMEOUT}s"
echo ""

START=$(date +%s)

while true; do
  NOW=$(date +%s)
  ELAPSED=$(( NOW - START ))

  # Count pods with 1/1 READY.
  READY_COUNT=$(kubectl get pods -n "${NAMESPACE}" \
    -l "strimzi.io/cluster=kafka-cluster" \
    --no-headers 2>/dev/null \
    | awk '{print $2}' \
    | grep -c "^1/1$" || true)

  TOTAL_COUNT=$(kubectl get pods -n "${NAMESPACE}" \
    -l "strimzi.io/cluster=kafka-cluster" \
    --no-headers 2>/dev/null \
    | wc -l | tr -d ' ' || echo "0")

  echo "  [${ELAPSED}s] Pods total=${TOTAL_COUNT} ready=${READY_COUNT}"

  if [[ "${TOTAL_COUNT}" -ge "${EXPECTED_PODS}" && "${READY_COUNT}" -ge "${EXPECTED_PODS}" ]]; then
    echo ""
    echo "PASS: All ${EXPECTED_PODS} Kafka pods are Ready. Elapsed: ${ELAPSED}s."
    echo ""
    kubectl get pods -n "${NAMESPACE}" -o wide
    echo ""
    echo "The cluster recovered from the simulated broker failure."
    echo "To continue testing, run the producer and consumer:"
    echo "  make port-forward   (in one terminal)"
    echo "  make produce        (in another terminal)"
    echo "  make consume        (in another terminal)"
    exit 0
  fi

  if [[ "${ELAPSED}" -ge "${TIMEOUT}" ]]; then
    echo ""
    echo "FAIL: Timeout after ${ELAPSED}s. Not all pods recovered."
    echo ""
    kubectl get pods -n "${NAMESPACE}" -o wide
    echo ""
    echo "Check pod events:"
    echo "  kubectl describe pod -n ${NAMESPACE} <pod-name>"
    echo "  kubectl get events -n ${NAMESPACE} --sort-by=.lastTimestamp"
    exit 1
  fi

  sleep "${POLL_INTERVAL}"
done
