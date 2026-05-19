# Strimzi Operator

Strimzi is installed via the official single-file release manifest downloaded from GitHub. No static YAML is committed here to keep the repository version-agnostic and avoid committing large generated files.

## Installation

Use the Makefile target:

```sh
make install-strimzi
```

Or run the script directly with a custom version:

```sh
STRIMZI_VERSION=0.43.0 NAMESPACE=kafka-lab bash scripts/install-strimzi.sh
```

## How the Script Works

`scripts/install-strimzi.sh`:

1. Creates the `kafka-lab` namespace if it does not exist.
2. Downloads the Strimzi release YAML from the GitHub releases page.
3. Replaces the default `myproject` namespace reference with `kafka-lab` using `sed`.
4. Applies the patched manifest to the cluster with `kubectl apply`.
5. Waits for the `strimzi-cluster-operator` deployment to be ready.

## Version

The default version is defined in the Makefile as `STRIMZI_VERSION`. Override it:

```sh
STRIMZI_VERSION=0.44.0 make install-strimzi
```

Check which Kafka versions a given Strimzi release supports:
<https://strimzi.io/downloads/>

## What Gets Installed

- Strimzi CRDs: `Kafka`, `KafkaNodePool`, `KafkaTopic`, `KafkaUser`, and others.
- ClusterRoles and ClusterRoleBindings for the operator.
- ServiceAccount for the operator.
- The `strimzi-cluster-operator` Deployment.

## Verify After Installation

```sh
kubectl get pods -n kafka-lab
kubectl logs -n kafka-lab deploy/strimzi-cluster-operator --tail=30
```

The operator pod should be in `Running` state. You should see log output indicating the operator is watching the `kafka-lab` namespace.
