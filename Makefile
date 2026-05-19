# kafka-k8s-ha-sre-lab Makefile
# Primary path:     Kind + Docker
# Alternative path: Kind + Podman
# See README.md for the full quick start.

CLUSTER_NAME    ?= kafka-k8s-ha-sre-lab
KIND_CONFIG     ?= kind/kind-cluster.yaml
NAMESPACE       ?= kafka-lab
KIND_BIN        ?= kind
KUBECTL_BIN     ?= kubectl
PYTHON_BIN      ?= python3

# Kafka bootstrap address used by the producer and consumer.
# Port-forward must be running when using the default localhost address.
BOOTSTRAP       ?= localhost:9092
TOPIC           ?= learning-events
CONSUMER_GROUP  ?= sre-lab-consumers
LOCAL_LISTENER_PORT   ?= 9094
LOCAL_BOOTSTRAP_PORT  ?= 9092
LOCAL_BROKER_0_PORT   ?= 19092
LOCAL_BROKER_1_PORT   ?= 19093
LOCAL_BROKER_2_PORT   ?= 19094

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
	@echo "  make port-forward         Port-forward Kafka local bootstrap and broker ports"
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
	@echo "  KIND_BIN=kind.exe KUBECTL_BIN=kubectl.exe make cluster-up-docker"
	@echo ""

# ---------------------------------------------------------------------------
# Cluster lifecycle
# ---------------------------------------------------------------------------

cluster-up-docker:
	$(KIND_BIN) create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG)

cluster-up-podman:
	KIND_EXPERIMENTAL_PROVIDER=podman $(KIND_BIN) create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG)

cluster-down:
	$(KIND_BIN) delete cluster --name $(CLUSTER_NAME)

nodes:
	$(KUBECTL_BIN) get nodes -o wide

# ---------------------------------------------------------------------------
# Strimzi and Kafka
# ---------------------------------------------------------------------------

install-strimzi:
	STRIMZI_VERSION=$(STRIMZI_VERSION) NAMESPACE=$(NAMESPACE) KUBECTL_BIN=$(KUBECTL_BIN) bash scripts/install-strimzi.sh

deploy-kafka:
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f manifests/kafka/kafka-cluster.yaml
	@echo ""
	@echo "Kafka resources applied. Strimzi will provision the cluster."
	@echo "Allow 2-5 minutes for broker pods to reach Running state."
	@echo "Monitor with: make status"

create-topic:
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f manifests/topics/learning-events.yaml

status:
	@echo "=== Nodes ==="
	@$(KUBECTL_BIN) get nodes -o wide
	@echo ""
	@echo "=== Pods in $(NAMESPACE) ==="
	@$(KUBECTL_BIN) get pods -n $(NAMESPACE) -o wide 2>/dev/null || echo "Namespace not found."
	@echo ""
	@echo "=== Kafka cluster ==="
	@$(KUBECTL_BIN) get kafka -n $(NAMESPACE) 2>/dev/null || echo "No Kafka resources found."
	@echo ""
	@echo "=== KafkaNodePools ==="
	@$(KUBECTL_BIN) get kafkanodepool -n $(NAMESPACE) 2>/dev/null || echo "No KafkaNodePool resources found."
	@echo ""
	@echo "=== Topics ==="
	@$(KUBECTL_BIN) get kafkatopic -n $(NAMESPACE) 2>/dev/null || echo "No topic resources found."

# ---------------------------------------------------------------------------
# Producer and consumer
# Port-forward must be running in a separate terminal before using these.
# ---------------------------------------------------------------------------

port-forward:
	@echo "Forwarding Kafka local listener services to localhost ports"
	@echo "  bootstrap -> localhost:$(LOCAL_BOOTSTRAP_PORT)"
	@echo "  broker 0  -> localhost:$(LOCAL_BROKER_0_PORT)"
	@echo "  broker 1  -> localhost:$(LOCAL_BROKER_1_PORT)"
	@echo "  broker 2  -> localhost:$(LOCAL_BROKER_2_PORT)"
	@echo "Press Ctrl+C to stop."
	@set -e; \
	$(KUBECTL_BIN) -n $(NAMESPACE) port-forward svc/kafka-cluster-kafka-local-bootstrap $(LOCAL_BOOTSTRAP_PORT):$(LOCAL_LISTENER_PORT) & \
	pf_bootstrap=$$!; \
	$(KUBECTL_BIN) -n $(NAMESPACE) port-forward svc/kafka-cluster-combined-local-0 $(LOCAL_BROKER_0_PORT):$(LOCAL_LISTENER_PORT) & \
	pf_broker_0=$$!; \
	$(KUBECTL_BIN) -n $(NAMESPACE) port-forward svc/kafka-cluster-combined-local-1 $(LOCAL_BROKER_1_PORT):$(LOCAL_LISTENER_PORT) & \
	pf_broker_1=$$!; \
	$(KUBECTL_BIN) -n $(NAMESPACE) port-forward svc/kafka-cluster-combined-local-2 $(LOCAL_BROKER_2_PORT):$(LOCAL_LISTENER_PORT) & \
	pf_broker_2=$$!; \
	trap 'kill $$pf_bootstrap $$pf_broker_0 $$pf_broker_1 $$pf_broker_2 2>/dev/null || true' INT TERM EXIT; \
	wait

produce:
	BOOTSTRAP_SERVERS=$(BOOTSTRAP) TOPIC=$(TOPIC) $(PYTHON_BIN) apps/producer.py

consume:
	BOOTSTRAP_SERVERS=$(BOOTSTRAP) TOPIC=$(TOPIC) CONSUMER_GROUP=$(CONSUMER_GROUP) $(PYTHON_BIN) apps/consumer.py

# ---------------------------------------------------------------------------
# Failure testing
# ---------------------------------------------------------------------------

kill-broker:
	NAMESPACE=$(NAMESPACE) KUBECTL_BIN=$(KUBECTL_BIN) bash scripts/kill-broker.sh

verify-ha:
	NAMESPACE=$(NAMESPACE) KUBECTL_BIN=$(KUBECTL_BIN) bash scripts/verify-ha.sh

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

clean:
	$(KIND_BIN) delete cluster --name $(CLUSTER_NAME)
