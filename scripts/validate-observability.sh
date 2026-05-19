#!/usr/bin/env bash
# validate-observability.sh
# Checks that Prometheus, Grafana, and Alertmanager are running, that their
# pods are ready, and (optionally) that Prometheus targets are reachable.
#
# This script performs Kubernetes-level checks only. For full target
# validation, start a port-forward and use the Prometheus API directly:
#   make port-forward-prometheus
#   curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool
#
# Environment variables:
#   NAMESPACE   Kubernetes namespace (default: kafka-lab)
#   KUBECTL_BIN kubectl executable (default: kubectl)
#
# Usage:
#   NAMESPACE=kafka-lab bash scripts/validate-observability.sh

set -euo pipefail

NAMESPACE=${NAMESPACE:-"kafka-lab"}
KUBECTL_BIN=${KUBECTL_BIN:-"kubectl"}
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$(( PASS + 1 )); }
fail() { echo "  FAIL: $1"; FAIL=$(( FAIL + 1 )); }

echo "=== Observability Validation ==="
echo ""
echo "Namespace: ${NAMESPACE}"
echo ""

# ---------------------------------------------------------------------------
# Check Prometheus
# ---------------------------------------------------------------------------
echo "--- Prometheus ---"
PROM_READY=$("${KUBECTL_BIN}" get pods -n "${NAMESPACE}" \
  -l app=prometheus --no-headers 2>/dev/null \
  | awk '{print $2}' | grep -c "^1/1$" || true)

if [[ "${PROM_READY}" -ge 1 ]]; then
  pass "Prometheus pod is 1/1 Ready"
else
  fail "Prometheus pod is not ready (found ${PROM_READY} ready pods)"
  echo "       Check: ${KUBECTL_BIN} get pods -n ${NAMESPACE} -l app=prometheus"
  echo "       Logs:  ${KUBECTL_BIN} logs -n ${NAMESPACE} deploy/prometheus"
fi

# Check Prometheus Service
PROM_SVC=$("${KUBECTL_BIN}" get svc -n "${NAMESPACE}" prometheus \
  --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [[ "${PROM_SVC}" -ge 1 ]]; then
  pass "Prometheus service exists"
else
  fail "Prometheus service not found"
fi

echo ""

# ---------------------------------------------------------------------------
# Check Grafana
# ---------------------------------------------------------------------------
echo "--- Grafana ---"
GRAFANA_READY=$("${KUBECTL_BIN}" get pods -n "${NAMESPACE}" \
  -l app=grafana --no-headers 2>/dev/null \
  | awk '{print $2}' | grep -c "^1/1$" || true)

if [[ "${GRAFANA_READY}" -ge 1 ]]; then
  pass "Grafana pod is 1/1 Ready"
else
  fail "Grafana pod is not ready (found ${GRAFANA_READY} ready pods)"
  echo "       Check: ${KUBECTL_BIN} get pods -n ${NAMESPACE} -l app=grafana"
  echo "       Logs:  ${KUBECTL_BIN} logs -n ${NAMESPACE} deploy/grafana"
fi

GRAFANA_SVC=$("${KUBECTL_BIN}" get svc -n "${NAMESPACE}" grafana \
  --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [[ "${GRAFANA_SVC}" -ge 1 ]]; then
  pass "Grafana service exists"
else
  fail "Grafana service not found"
fi

echo ""

# ---------------------------------------------------------------------------
# Check Alertmanager
# ---------------------------------------------------------------------------
echo "--- Alertmanager ---"
AM_READY=$("${KUBECTL_BIN}" get pods -n "${NAMESPACE}" \
  -l app=alertmanager --no-headers 2>/dev/null \
  | awk '{print $2}' | grep -c "^1/1$" || true)

if [[ "${AM_READY}" -ge 1 ]]; then
  pass "Alertmanager pod is 1/1 Ready"
else
  fail "Alertmanager pod is not ready (found ${AM_READY} ready pods)"
  echo "       Check: ${KUBECTL_BIN} get pods -n ${NAMESPACE} -l app=alertmanager"
  echo "       Logs:  ${KUBECTL_BIN} logs -n ${NAMESPACE} deploy/alertmanager"
fi

AM_SVC=$("${KUBECTL_BIN}" get svc -n "${NAMESPACE}" alertmanager \
  --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [[ "${AM_SVC}" -ge 1 ]]; then
  pass "Alertmanager service exists"
else
  fail "Alertmanager service not found"
fi

echo ""

# ---------------------------------------------------------------------------
# Check Kafka Exporter
# ---------------------------------------------------------------------------
echo "--- Kafka Exporter ---"
EXPORTER_READY=$("${KUBECTL_BIN}" get pods -n "${NAMESPACE}" \
  -l "strimzi.io/name=kafka-cluster-kafka-exporter" \
  --no-headers 2>/dev/null \
  | awk '{print $2}' | grep -c "^1/1$" || true)

if [[ "${EXPORTER_READY}" -ge 1 ]]; then
  pass "Kafka Exporter pod is 1/1 Ready"
else
  fail "Kafka Exporter pod is not ready (found ${EXPORTER_READY} ready pods)"
  echo "       The kafkaExporter field must be set in the Kafka CR."
  echo "       Check: ${KUBECTL_BIN} get pods -n ${NAMESPACE} | grep exporter"
fi

echo ""

# ---------------------------------------------------------------------------
# Check Kafka broker metrics targets (requires Prometheus port-forward)
# ---------------------------------------------------------------------------
echo "--- Prometheus target check (requires port-forward on localhost:9090) ---"
if curl -sf --max-time 3 \
    "http://localhost:9090/api/v1/targets" > /tmp/prom_targets.json 2>/dev/null; then

  TOTAL=$( python3 -c "
import json, sys
data = json.load(open('/tmp/prom_targets.json'))
targets = data.get('data', {}).get('activeTargets', [])
print(len(targets))
" 2>/dev/null || echo "0")

  UP=$( python3 -c "
import json, sys
data = json.load(open('/tmp/prom_targets.json'))
targets = data.get('data', {}).get('activeTargets', [])
print(sum(1 for t in targets if t.get('health') == 'up'))
" 2>/dev/null || echo "0")

  KAFKA_UP=$( python3 -c "
import json, sys
data = json.load(open('/tmp/prom_targets.json'))
targets = data.get('data', {}).get('activeTargets', [])
print(sum(1 for t in targets
  if t.get('labels', {}).get('job') == 'kafka-brokers'
  and t.get('health') == 'up'))
" 2>/dev/null || echo "0")

  echo "  Total targets:         ${TOTAL}"
  echo "  Targets up:            ${UP}"
  echo "  Kafka brokers up:      ${KAFKA_UP}"

  if [[ "${KAFKA_UP}" -ge 3 ]]; then
    pass "All 3 Kafka broker targets are up"
  elif [[ "${KAFKA_UP}" -ge 1 ]]; then
    fail "Only ${KAFKA_UP}/3 Kafka broker targets are up"
  else
    fail "No Kafka broker targets are up (metrics may not be enabled yet)"
  fi
else
  echo "  SKIP: Prometheus not reachable on localhost:9090"
  echo "        Run 'make port-forward-prometheus' in a separate terminal first."
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Summary ==="
echo "  PASS: ${PASS}"
echo "  FAIL: ${FAIL}"
echo ""

if [[ "${FAIL}" -eq 0 ]]; then
  echo "Observability validation PASSED."
  echo ""
  echo "Next steps:"
  echo "  make port-forward-prometheus   -> http://localhost:9090"
  echo "  make port-forward-grafana      -> http://localhost:3000 (admin/admin)"
  echo "  make port-forward-alertmanager -> http://localhost:9093"
  echo "  make kill-broker               -> trigger KafkaBrokerDown alert"
  exit 0
else
  echo "Observability validation FAILED. Review the errors above."
  echo ""
  echo "Common fixes:"
  echo "  make deploy-observability   re-apply all observability components"
  echo "  make observability-status   show pod and service status"
  echo "  See docs/troubleshooting.md for detailed troubleshooting steps."
  exit 1
fi
