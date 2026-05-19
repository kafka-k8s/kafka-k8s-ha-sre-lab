# Security

## Security Posture

This is a local educational lab. It should still teach secure patterns and avoid unsafe habits where practical.

The MVP must clearly separate local convenience from production hardening.

## TLS

Kafka production deployments should use TLS for client and inter-broker communication.

For the lab:

- TLS should be documented from the beginning.
- If local plaintext listeners are used temporarily, they must be labeled as lab-only.
- Future manifests should demonstrate TLS-enabled listeners where practical.

## SASL/SCRAM

SASL/SCRAM is a practical authentication option for Kafka clients.

Future `KafkaUser` manifests should define separate users for:

- Producer access to `learning-events`.
- Consumer access to `learning-events`.

Credentials must be stored in Kubernetes Secrets and never committed as real secret values.

## ACLs

ACLs should follow least privilege:

- Producer can write to `learning-events`.
- Consumer can read from `learning-events`.
- Consumer can use its configured consumer group.
- Admin operations are limited to operational users.

The MVP may defer ACL implementation, but the design should not assume anonymous production access.

## Kubernetes NetworkPolicy

NetworkPolicy can limit which pods can connect to Kafka, Prometheus, Grafana, and Alertmanager.

Future hardening should include:

- Allow producer and consumer pods to connect to Kafka.
- Allow Prometheus to scrape Kafka and Strimzi metrics.
- Restrict Grafana and Alertmanager access.
- Deny unexpected cross-namespace traffic where practical.

NetworkPolicy behavior depends on the Kubernetes CNI. Kind's default networking may not enforce all policies unless a compatible CNI is installed.

## Secrets

Rules:

- Do not commit real passwords, tokens, or certificates.
- Use Kubernetes Secrets for generated credentials.
- Document how to retrieve local lab credentials.
- Rotate credentials in production-like extensions.
- Prefer sealed or external secret patterns only in future GitOps phases.

## Future Hardening

Production-minded hardening should include:

- TLS for all Kafka listeners.
- Authenticated clients.
- Least-privilege ACLs.
- NetworkPolicy enforcement.
- Image version pinning.
- Vulnerability scanning.
- Kubernetes RBAC review.
- Secret rotation procedure.
- Audit logging where available.
- Backup and restore testing.

## Local Security Limitations

Local clusters often expose services through port-forwarding and developer credentials. That is acceptable for learning when documented, but it must not be presented as production security.

