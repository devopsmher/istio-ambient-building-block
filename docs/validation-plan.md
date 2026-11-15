# Validation plan

Every scenario has a command and an expected result. Run the whole plan after installing the mesh and after every Istio upgrade; keep the output as evidence for audits.

The examples use the `payments` team from `examples/teams/payments/values.yaml` and a test client pod with `curl` in each namespace.

| # | Scenario | How | Expected |
|---|---|---|---|
| 1 | Ingress | `curl https://api.payments.example.com/` from outside | `200`; the route is `Accepted` on the shared gateway |
| 2 | Route from a namespace without the ingress label | apply an `HTTPRoute` in such a namespace | route status `Accepted=False`, reason `NotAllowedByListeners` |
| 3 | East-west, allowed caller | from `orders`, pod with service account `checkout`: `curl http://payments-api.payments:8080/` | `200`; ztunnel logs show source identity `cluster.local/ns/orders/sa/checkout` |
| 4 | East-west, other caller | same request from another namespace in the mesh | connection rejected; ztunnel logs a policy rejection |
| 5 | Plain text from outside the mesh | request from a namespace without the ambient label | rejected: STRICT mTLS and the `mesh-only` NetworkPolicy |
| 6 | Egress to an API | from `payments`: `curl https://api.payment-provider.example` | succeeds; the host appears as an external service in Kiali |
| 7 | External database | from `payments`: connect to `orders-db.example.internal:5432` | TCP connection succeeds; visible in ztunnel telemetry |
| 8 | Health probes | `kubectl get pods -n payments` after enrolment | all pods `Ready`: probes pass the NetworkPolicy |
| 9 | Waypoint (if enabled) | repeat 1, 3 and 4 with `waypoint.enabled: true` | same results; ztunnel admits only the waypoint identity |
| 10 | Rollback | set `enrolled: false` in the team file and merge | the ambient label and the `mesh-only` NetworkPolicy disappear, traffic flows without the mesh; no pod restarts |

## Useful commands

```bash
# Which workloads are in the mesh, and through which protocol
istioctl ztunnel-config workloads

# Policy decisions of ztunnel on a node
kubectl logs -n istio-system ds/ztunnel --since=10m | grep -i -E 'denied|rbac'

# Route status on the shared gateway
kubectl get httproute -A -o wide
```
