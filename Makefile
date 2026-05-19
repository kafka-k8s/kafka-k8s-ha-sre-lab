CLUSTER_NAME ?= kafka-kubernetes-ha-sre-lab
KIND_CONFIG ?= kind/kind-cluster.yaml
NAMESPACE ?= kafka-lab
STRIMZI_MANIFESTS := $(wildcard manifests/strimzi/*.yaml manifests/strimzi/*.yml)
KAFKA_MANIFESTS := $(wildcard manifests/kafka/*.yaml manifests/kafka/*.yml)
TOPIC_MANIFESTS := $(wildcard manifests/topics/*.yaml manifests/topics/*.yml)
PRODUCER_APP := $(wildcard apps/producer.py)
CONSUMER_APP := $(wildcard apps/consumer.py)
KILL_BROKER_SCRIPT := $(wildcard scripts/kill-broker.sh)
VERIFY_HA_SCRIPT := $(wildcard scripts/verify-ha.sh)

.PHONY: help cluster-up-docker cluster-up-podman cluster-down nodes status install-strimzi deploy-kafka create-topic produce consume kill-broker verify-ha

help:
	@echo "Targets:"
	@echo "  cluster-up-docker  Create the Kind cluster using Docker"
	@echo "  cluster-up-podman  Create the Kind cluster using Podman"
	@echo "  cluster-down       Delete the Kind cluster"
	@echo "  nodes              Show Kubernetes nodes"
	@echo "  status             Show cluster pods"
	@echo "  install-strimzi    Apply Strimzi manifests when added"
	@echo "  deploy-kafka       Apply Kafka manifests when added"
	@echo "  create-topic       Apply topic manifests when added"
	@echo "  produce            Run Python producer when implemented"
	@echo "  consume            Run Python consumer when implemented"
	@echo "  kill-broker        Run broker failure script when implemented"
	@echo "  verify-ha          Run HA verification script when implemented"

cluster-up-docker:
	kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG)

cluster-up-podman:
	KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG)

cluster-down:
	kind delete cluster --name $(CLUSTER_NAME)

nodes:
	kubectl get nodes -o wide

status:
	kubectl get pods -A -o wide

install-strimzi:
	@echo "Applying namespace manifest."
	kubectl apply -f manifests/namespace.yaml
ifneq ($(strip $(STRIMZI_MANIFESTS)),)
	kubectl apply -n $(NAMESPACE) -f manifests/strimzi/
else
	@echo "Strimzi manifests are not implemented yet. See specs/kafka-kubernetes-ha-sre-lab/tasks.md P3-002."
endif

deploy-kafka:
ifneq ($(strip $(KAFKA_MANIFESTS)),)
	kubectl apply -n $(NAMESPACE) -f manifests/kafka/
else
	@echo "Kafka manifests are not implemented yet. See specs/kafka-kubernetes-ha-sre-lab/tasks.md P3-003."
endif

create-topic:
ifneq ($(strip $(TOPIC_MANIFESTS)),)
	kubectl apply -n $(NAMESPACE) -f manifests/topics/
else
	@echo "Topic manifests are not implemented yet. See specs/kafka-kubernetes-ha-sre-lab/tasks.md P3-004."
endif

produce:
ifneq ($(strip $(PRODUCER_APP)),)
	python apps/producer.py
else
	@echo "apps/producer.py is not implemented yet. See specs/kafka-kubernetes-ha-sre-lab/tasks.md P4-001."
endif

consume:
ifneq ($(strip $(CONSUMER_APP)),)
	python apps/consumer.py
else
	@echo "apps/consumer.py is not implemented yet. See specs/kafka-kubernetes-ha-sre-lab/tasks.md P4-002."
endif

kill-broker:
ifneq ($(strip $(KILL_BROKER_SCRIPT)),)
	sh scripts/kill-broker.sh
else
	@echo "scripts/kill-broker.sh is not implemented yet. See specs/kafka-kubernetes-ha-sre-lab/tasks.md P6-001."
endif

verify-ha:
ifneq ($(strip $(VERIFY_HA_SCRIPT)),)
	sh scripts/verify-ha.sh
else
	@echo "scripts/verify-ha.sh is not implemented yet. See specs/kafka-kubernetes-ha-sre-lab/tasks.md P6-003."
endif
