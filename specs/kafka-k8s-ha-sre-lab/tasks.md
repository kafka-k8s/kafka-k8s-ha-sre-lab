# P0 Local MVP Validation Tasks

Only P0 validation tasks are in scope for this pass. Do not add AWS/EKS,
Elasticsearch, observability, or new feature work.

| ID | Priority | Task | Acceptance Criteria |
| --- | --- | --- | --- |
| V-001 | P0 | Validate Makefile targets. | Required targets exist and expand to the expected Kind, Strimzi, Kafka, topic, producer, consumer, and failure-test commands. |
| V-002 | P0 | Validate Kind cluster creation. | `make cluster-up-docker` creates one control-plane node and three workers. |
| V-003 | P0 | Validate Kubernetes nodes. | `make nodes` shows all four nodes as `Ready`. |
| V-004 | P0 | Validate Strimzi installation. | `make install-strimzi` completes and `strimzi-cluster-operator` is `1/1 Running`. |
| V-005 | P0 | Validate Kafka readiness. | `make deploy-kafka` completes and `kubectl get kafka -n kafka-lab` shows `READY=True`, `METADATA STATE=KRaft`. |
| V-006 | P0 | Validate topic creation. | `make create-topic` creates `learning-events` with `READY=True`, 3 partitions, and replication factor 3. |
| V-007 | P0 | Validate producer connectivity. | `make produce` sends all requested records to `learning-events`. |
| V-008 | P0 | Validate consumer connectivity. | `make consume` reads the produced records from `learning-events`. |
| V-009 | P0 | Validate broker failure recovery. | `make kill-broker` deletes one broker pod and `make verify-ha` reports `PASS`. |
| V-010 | P0 | Validate post-recovery message flow. | Producer and consumer still work after broker recovery. |
| V-011 | P0 | Add `docs/demo-output.md`. | File includes real or template command output for each validation step. |
| V-012 | P0 | Add `docs/e2e-validation.md`. | File includes exact commands to reproduce the local validation flow. |
| V-013 | P0 | Update troubleshooting with real fixes. | `docs/troubleshooting.md` documents the actual Kind/Strimzi and port-forward fixes. |
| V-014 | P0 | Fix README only where commands are inaccurate. | README quick-start commands remain accurate for the validated MVP path. |
