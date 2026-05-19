#!/usr/bin/env bash
# install-strimzi.sh
# Downloads and installs the Strimzi Cluster Operator into the target namespace.
# Replaces the default 'myproject' namespace reference with the target namespace.
#
# Environment variables:
#   STRIMZI_VERSION   Strimzi release version (default: 0.43.0)
#   NAMESPACE         Kubernetes namespace (default: kafka-lab)
#
# Usage:
#   STRIMZI_VERSION=0.43.0 NAMESPACE=kafka-lab bash scripts/install-strimzi.sh

set -euo pipefail

STRIMZI_VERSION=${STRIMZI_VERSION:-"0.43.0"}
NAMESPACE=${NAMESPACE:-"kafka-lab"}

STRIMZI_URL="https://github.com/strimzi/strimzi-kafka-operator/releases/download/${STRIMZI_VERSION}/strimzi-cluster-operator-${STRIMZI_VERSION}.yaml"

echo "=== Installing Strimzi ${STRIMZI_VERSION} ==="
echo "Namespace:  ${NAMESPACE}"
echo "Source URL: ${STRIMZI_URL}"
echo ""

# Ensure the namespace exists (idempotent).
kubectl apply -f manifests/namespace.yaml

echo ""
echo "Downloading Strimzi release manifest..."

# Download the release YAML, patch all namespace references from 'myproject'
# to our target namespace, then apply. The Strimzi single-file installer
# defaults to 'myproject'; the sed substitution is the standard install method.
if command -v curl &>/dev/null; then
  curl -sL "${STRIMZI_URL}" \
    | sed "s/namespace: myproject/namespace: ${NAMESPACE}/g" \
    | kubectl apply -n "${NAMESPACE}" -f -
elif command -v wget &>/dev/null; then
  wget -qO- "${STRIMZI_URL}" \
    | sed "s/namespace: myproject/namespace: ${NAMESPACE}/g" \
    | kubectl apply -n "${NAMESPACE}" -f -
else
  echo "ERROR: Neither curl nor wget found. Install one and retry."
  exit 1
fi

echo ""
echo "Waiting for Strimzi Cluster Operator to be ready (timeout: 5 minutes)..."
kubectl rollout status deployment/strimzi-cluster-operator \
  -n "${NAMESPACE}" --timeout=300s

echo ""
echo "Strimzi ${STRIMZI_VERSION} is ready in namespace '${NAMESPACE}'."
echo ""
echo "Next step:"
echo "  make deploy-kafka"
