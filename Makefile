# kafka-k8s-ha-sre-lab Makefile
# Primary path:     Kind + Docker
# Alternative path: Kind + Podman
# See README.md for the full quick start.

CLUSTER_NAME    ?= kafka-k8s-ha-sre-lab
KIND_CONFIG     ?= kind/kind-cluster.yaml
NAMESPACE       ?= kafka-lab

# Kafka bootstrap address used by the producer and consumer.
# Port-forward must be running when using the default localhost address.
BOOTSTRAP       ?= localhost:9092
TOPIC           ?= learning-events
CONSUMER_GROUP  ?= sre-lab-consumers

# Strimzi version to install. Override to pin a different release.
# Check supported releases: https://strimzi.io/downloads/
STRIMZI_VERSION ?= 0.43.0

.PHONY: help \
	cluster-up-docker cluster-up-podman cluster-down nodes \
	install-strimzi deploy-kafka create-topic status port-forward \
	produce consume kill-broker verify-ha clean

help:
	@echo ""
	@echo "kafka-k8s-ha-sre-lab"
	@echo ""
	@echo "Cluster:"
	@echo "  make cluster-up-docker    Create Kind cluster with Docker (primary path)"
	@echo "  make cluster-up-podman    Create Kind cluster with Podman (alternative)"
	@echo "  make cluster-down         Delete the Kind cluster"
	@echo "  make nodes                Show Kubernetes nodes"
	@echo ""
	@echo "Strimzi and Kafka:"
	@echo "  make install-strimzi      Install Strimzi operator"
	@echo "  make deploy-kafka         Deploy Kafka KRaft cluster"
	@echo "  make create-topic         Create the learning-events topic"
	@echo "  make status               Show cluster, Kafka, and topic status"
	@echo ""
	@echo "Producer and consumer:"
	@echo "  make port-forward         Port-forward Kafka bootstrap to localhost:9092"
	@echo "  make produce              Run Python producer (requires port-forward)"
	@echo "  make consume              Run Python consumer (requires port-forward)"
	@echo ""
	@echo "Failure testing:"
	@echo "  make kill-broker          Delete one Kafka broker pod"
	@echo "  make verify-ha            Wait for all broker pods to recover"
	@echo ""
	@echo "  make clean                Delete the Kind cluster"
	@echo ""
	@echo "Overrides:"
	@echo "  STRIMZI_VERSION=0.44.0 make install-strimzi"
	@echo "  MESSAGE_COUNT=50 make produce"
	@echo "  TIMEOUT_SECONDS=60 make consume"
	@echo ""

# ---------------------------------------------------------------------------
# Cluster lifecycle
# ---------------------------------------------------------------------------

cluster-up-docker:
	kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG)

cluster-up-podman:
	KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG)

cluster-down:
	kind delete cluster --name $(CLUSTER_NAME)

nodes:
	kubectl get nodes -o wide

# ---------------------------------------------------------------------------
# Strimzi and Kafka
# ---------------------------------------------------------------------------

install-strimzi:
	STRIMZI_VERSION=$(STRIMZI_VERSION) NAMESPACE=$(NAMESPACE) bash scripts/install-strimzi.sh

deploy-kafka:
	kubectl apply -n $(NAMESPACE) -f manifests/kafka/kafka-cluster.yaml
	@echo ""
	@echo "Kafka resources applied. Strimzi will provision the cluster."
	@echo "Allow 2-5 minutes for broker pods to reach Running state."
	@echo "Monitor with: make status"

create-topic:
	kubectl apply -n $(NAMESPACE) -f manifests/topics/learning-events.yaml

status:
	@echo "=== Nodes ==="
	@kubectl get nodes -o wide
	@echo ""
	@echo "=== Pods in $(NAMESPACE) ==="
	@kubectl get pods -n $(NAMESPACE) -o wide 2>/dev/null || echo "Namespace not found."
	@echo ""
	@echo "=== Kafka cluster ==="
	@kubectl get kafka -n $(NAMESPACE) 2>/dev/null || echo "No Kafka resources found."
	@echo ""
	@echo "=== KafkaNodePools ==="
	@kubectl get kafkanodepool -n $(NAMESPACE) 2>/dev/null || echo "No KafkaNodePool resources found."
	@echo ""
	@echo "=== Topics ==="
	@kubectl get kafkatopic -n $(NAMESPACE) 2>/dev/null || echo "No topic resources found."

# ---------------------------------------------------------------------------
# Producer and consumer
# Port-forward must be running in a separate terminal before using these.
# ---------------------------------------------------------------------------

port-forward:
	@echo "Forwarding svc/kafka-cluster-kafka-bootstrap -> localhost:9092"
	@echo "Press Ctrl+C to stop."
	kubectl -n $(NAMESPACE) port-forward svc/kafka-cluster-kafka-bootstrap 9092:9092

produce:
	BOOTSTRAP_SERVERS=$(BOOTSTRAP) TOPIC=$(TOPIC) python apps/producer.py

consume:
	BOOTSTRAP_SERVERS=$(BOOTSTRAP) TOPIC=$(TOPIC) CONSUMER_GROUP=$(CONSUMER_GROUP) python apps/consumer.py

# ---------------------------------------------------------------------------
# Failure testing
# ---------------------------------------------------------------------------

kill-broker:
	NAMESPACE=$(NAMESPACE) bash scripts/kill-broker.sh

verify-ha:
	NAMESPACE=$(NAMESPACE) bash scripts/verify-ha.sh

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

clean:
	kind delete cluster --name $(CLUSTER_NAME)

