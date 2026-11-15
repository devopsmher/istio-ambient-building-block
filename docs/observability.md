# Observability

## Kiali with single sign-on

The Terraform module installs Kiali only with OpenID Connect: `kiali.oidc_issuer_url` is required when Kiali is enabled. Create the client secret yourself, outside Terraform state:

```bash
kubectl create secret generic kiali -n istio-system --from-literal="oidc-secret=<client secret>"
```

Kiali shows the service graph with mTLS status per connection, policies per namespace and external hosts from ServiceEntries.

## Metrics and dashboards

- ztunnel exports L4 metrics for every enrolled workload: connections, bytes, mTLS identities.
- Waypoints add L7 metrics: requests, response codes, latency.
- Import the official Istio dashboards from grafana.com into the shared Grafana and keep them next to the cluster dashboards.

## Tracing

L7 spans come from waypoints and gateways, so traces cover namespaces that run a waypoint and all ingress traffic. Configure the tracing backend (for example Jaeger) with the Istio Telemetry API.

## Alerts and runbooks

Alert on symptoms, each with a short runbook:

| Alert | First steps in the runbook |
|---|---|
| istiod unavailable | check the istiod deployment and its logs; existing workloads keep working with cached config |
| ztunnel not ready on a node | pods on that node lose mesh traffic: cordon the node, check the ztunnel pod and istio-cni |
| Spike of denied connections | a new caller or a typo in `allowFrom`: find the source identity in ztunnel logs |
| 5xx growth at the ingress gateway | check route status, backend endpoints and recent deploys of the team |
| Gateway certificate close to expiry | check the cert-manager `Certificate` and the DNS-01 issuer |
