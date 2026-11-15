# Onboarding a team

A team joins the mesh with one values file and one pull request. Argo CD does the rest in a few minutes.

## 1. Write the values file

Copy [`examples/teams/payments/values.yaml`](../examples/teams/payments/values.yaml) to `examples/teams/<team>/values.yaml` and change it:

| Key | What it means |
|---|---|
| `namespace` | Namespace that joins the mesh in ambient mode |
| `allowFrom` | Callers allowed into the namespace, by namespace or by service account. Everyone else is denied |
| `ingress.allowed` | Lets the team attach public routes to the shared gateway |
| `routes` | Public hostnames and the services behind them |
| `egress.hosts` | External APIs and databases the namespace talks to |
| `waypoint.enabled` | Turn on L7 features: HTTP authorization, retries, header routing |
| `enrolled` | `true` by default; `false` takes the namespace out of the mesh (rollback) |

If the team exposes public routes, add the gateway itself to `allowFrom`:

```yaml
allowFrom:
  - namespace: istio-ingress
    serviceAccounts: [public-istio]
```

## 2. Open a pull request

CI renders all three charts with the new file and validates them against the Kubernetes, Istio and Gateway API schemas. A typo such as `serviceAccount` instead of `serviceAccounts`, a port of 0 or a namespace with capital letters fails in CI, not in the cluster.

## 3. Merge

The `mesh-onboarding` ApplicationSet creates an Argo CD Application for the new file and syncs it:

1. the namespace appears with the ambient label;
2. default-deny and the allow rules apply at once;
3. routes attach to the shared gateway;
4. external hosts appear as ServiceEntries.

No application code changes and no pod restarts: workloads join the mesh as soon as they run in the labelled namespace.

## 4. Check

```bash
kubectl get namespace <team> --show-labels          # istio.io/dataplane-mode=ambient
istioctl ztunnel-config workloads | grep <team>     # PROTOCOL HBONE for the team's pods
kubectl get httproute -n <team>                      # Accepted and ResolvedRefs are True
```

Then run the team's part of the [validation plan](validation-plan.md).
