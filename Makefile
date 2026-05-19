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
	produce consume kill-broker verify-ha \
	deploy-observability delete-observability observability-status \
	port-forward-prometheus port-forward-grafana port-forward-alertmanager \
	validate-observability \
	clean

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
	@echo "Observability:"
	@echo "  make deploy-observability      Deploy Prometheus, Grafana, Alertmanager"
	@echo "  make delete-observability      Remove observability components"
	@echo "  make observability-status      Show observability pod and service status"
	@echo "  make port-forward-prometheus   Forward Prometheus to localhost:9090"
	@echo "  make port-forward-grafana      Forward Grafana to localhost:3000"
	@echo "  make port-forward-alertmanager Forward Alertmanager to localhost:9093"
	@echo "  make validate-observability    Run observability validation checks"
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
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f manifests/kafka/kafka-metrics-config.yaml
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
# Observability
# Deploy Prometheus, Grafana, and Alertmanager for local Kafka monitoring.
# Run 'make deploy-kafka' before deploying observability so that the Kafka
# cluster is present before Prometheus starts scraping.
# ---------------------------------------------------------------------------

PROM_LOCAL_PORT         ?= 9090
GRAFANA_LOCAL_PORT      ?= 3000
ALERTMANAGER_LOCAL_PORT ?= 9093

deploy-observability:
	@echo "Applying Kafka metrics config and updating Kafka cluster..."
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f manifests/kafka/kafka-metrics-config.yaml
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f manifests/kafka/kafka-cluster.yaml
	@echo ""
	@echo "Applying Prometheus RBAC (cluster-scoped resources)..."
	$(KUBECTL_BIN) apply -f observability/prometheus/prometheus-rbac.yaml
	@echo ""
	@echo "Applying Prometheus components..."
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/prometheus/prometheus-config.yaml
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/prometheus/kafka-alert-rules.yaml
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/prometheus/prometheus-deployment.yaml
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/prometheus/prometheus-service.yaml
	@echo ""
	@echo "Applying Grafana components..."
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/grafana/grafana-datasource.yaml
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/grafana/grafana-dashboard-provider.yaml
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/grafana/kafka-dashboard.yaml
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/grafana/grafana-deployment.yaml
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/grafana/grafana-service.yaml
	@echo ""
	@echo "Applying Alertmanager components..."
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/alertmanager/alertmanager-config.yaml
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/alertmanager/alertmanager-deployment.yaml
	$(KUBECTL_BIN) apply -n $(NAMESPACE) -f observability/alertmanager/alertmanager-service.yaml
	@echo ""
	@echo "Observability components applied."
	@echo "Allow 1-2 minutes for pods to become ready."
	@echo "Monitor with: make observability-status"

delete-observability:
	@echo "Removing observability components..."
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/alertmanager/alertmanager-service.yaml
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/alertmanager/alertmanager-deployment.yaml
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/alertmanager/alertmanager-config.yaml
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/grafana/grafana-service.yaml
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/grafana/grafana-deployment.yaml
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/grafana/kafka-dashboard.yaml
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/grafana/grafana-dashboard-provider.yaml
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/grafana/grafana-datasource.yaml
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/prometheus/prometheus-service.yaml
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/prometheus/prometheus-deployment.yaml
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/prometheus/kafka-alert-rules.yaml
	-$(KUBECTL_BIN) delete -n $(NAMESPACE) -f observability/prometheus/prometheus-config.yaml
	-$(KUBECTL_BIN) delete -f observability/prometheus/prometheus-rbac.yaml
	@echo "Observability components removed."

observability-status:
	@echo "=== Observability Pods ==="
	@$(KUBECTL_BIN) get pods -n $(NAMESPACE) \
	  -l 'app in (prometheus,grafana,alertmanager)' -o wide 2>/dev/null \
	  || echo "No observability pods found."
	@echo ""
	@echo "=== Kafka Exporter ==="
	@$(KUBECTL_BIN) get pods -n $(NAMESPACE) \
	  -l strimzi.io/name=kafka-cluster-kafka-exporter 2>/dev/null \
	  || echo "Kafka Exporter not found."
	@echo ""
	@echo "=== Observability Services ==="
	@$(KUBECTL_BIN) get svc -n $(NAMESPACE) 2>/dev/null | \
	  grep -E 'NAME|prometheus|grafana|alertmanager' || echo "No observability services found."

port-forward-prometheus:
	@echo "Forwarding Prometheus to localhost:$(PROM_LOCAL_PORT)"
	@echo "Open: http://localhost:$(PROM_LOCAL_PORT)"
	@echo "Press Ctrl+C to stop."
	$(KUBECTL_BIN) -n $(NAMESPACE) port-forward svc/prometheus $(PROM_LOCAL_PORT):9090

port-forward-grafana:
	@echo "Forwarding Grafana to localhost:$(GRAFANA_LOCAL_PORT)"
	@echo "Open: http://localhost:$(GRAFANA_LOCAL_PORT)  (admin / admin)"
	@echo "Press Ctrl+C to stop."
	$(KUBECTL_BIN) -n $(NAMESPACE) port-forward svc/grafana $(GRAFANA_LOCAL_PORT):3000

port-forward-alertmanager:
	@echo "Forwarding Alertmanager to localhost:$(ALERTMANAGER_LOCAL_PORT)"
	@echo "Open: http://localhost:$(ALERTMANAGER_LOCAL_PORT)"
	@echo "Press Ctrl+C to stop."
	$(KUBECTL_BIN) -n $(NAMESPACE) port-forward svc/alertmanager $(ALERTMANAGER_LOCAL_PORT):9093

validate-observability:
	NAMESPACE=$(NAMESPACE) KUBECTL_BIN=$(KUBECTL_BIN) bash scripts/validate-observability.sh

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

clean:
	$(KIND_BIN) delete cluster --name $(CLUSTER_NAME)
