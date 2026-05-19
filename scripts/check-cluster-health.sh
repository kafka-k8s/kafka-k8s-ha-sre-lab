#!/usr/bin/env bash
# check-cluster-health.sh
# Prints a summary of the Kafka cluster health for quick SRE triage.
#
# Environment variables:
#   NAMESPACE   Kubernetes namespace (default: kafka-lab)
#   KUBECTL_BIN kubectl executable (default: kubectl)
#
# Usage:
#   NAMESPACE=kafka-lab bash scripts/check-cluster-health.sh

set -euo pipefail

NAMESPACE=${NAMESPACE:-"kafka-lab"}
KUBECTL_BIN=${KUBECTL_BIN:-"kubectl"}

echo "=== Kubernetes Nodes ==="
"${KUBECTL_BIN}" get nodes -o wide

echo ""
echo "=== Pods in ${NAMESPACE} ==="
"${KUBECTL_BIN}" get pods -n "${NAMESPACE}" -o wide

echo ""
echo "=== Kafka Cluster Status ==="
if "${KUBECTL_BIN}" get kafka -n "${NAMESPACE}" &>/dev/null; then
  "${KUBECTL_BIN}" get kafka -n "${NAMESPACE}"
  echo ""
  # Print the Conditions section from the Kafka CR status.
  "${KUBECTL_BIN}" get kafka -n "${NAMESPACE}" -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data.get('items', []):
  name = item['metadata']['name']
  conditions = item.get('status', {}).get('conditions', [])
  print(f'Cluster: {name}')
  for c in conditions:
    print(f'  {c.get(\"type\",\"?\")} = {c.get(\"status\",\"?\")}  ({c.get(\"message\",\"\")})')
" 2>/dev/null || true
else
  echo "No Kafka resources found. Has 'make deploy-kafka' been run?"
fi

echo ""
echo "=== KafkaNodePools ==="
"${KUBECTL_BIN}" get kafkanodepool -n "${NAMESPACE}" 2>/dev/null \
  || echo "No KafkaNodePool resources found."

echo ""
echo "=== Topics ==="
"${KUBECTL_BIN}" get kafkatopic -n "${NAMESPACE}" 2>/dev/null \
  || echo "No KafkaTopic resources found."

echo ""
echo "=== Recent Events ==="
"${KUBECTL_BIN}" get events -n "${NAMESPACE}" \
  --sort-by=.lastTimestamp 2>/dev/null \
  | tail -20
