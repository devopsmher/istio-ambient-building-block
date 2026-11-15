#!/usr/bin/env bash
# Lints and renders every chart with the example team values, then validates the manifests
# against Kubernetes, Istio, Gateway API, cert-manager and Argo CD schemas. No cluster needed.
# Also checks that the values schemas reject broken team files.
#
# Usage: scripts/validate.sh            (helm and kubeconform from PATH,
#                                         or set HELM and KUBECONFORM)

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
helm="${HELM:-helm}"
kubeconform="${KUBECONFORM:-kubeconform}"
team_values="$root/examples/teams/payments/values.yaml"
baseline="$root/terraform/modules/istio-ambient/charts/mesh-baseline"

# shellcheck disable=SC2016 # {{.Group}} and friends are kubeconform templates, not shell
crd_schemas='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

validate() {
  "$kubeconform" -strict -summary -schema-location default -schema-location "$crd_schemas" -
}

render() {
  local chart="$1"
  shift
  "$helm" template "$(basename "$chart")" "$chart" "$@"
}

echo "== mesh-baseline"
"$helm" lint --strict "$baseline"
render "$baseline" | validate
render "$baseline" --set ingress.certificate.enabled=true | validate

for name in mesh-namespace mesh-routes mesh-egress; do
  chart="$root/charts/$name"
  echo "== $name"
  "$helm" lint --strict "$chart" -f "$team_values"
  render "$chart" -f "$team_values" | validate
done

echo "== mesh-namespace with a waypoint and egress through it"
render "$root/charts/mesh-namespace" -f "$team_values" --set waypoint.enabled=true | validate
render "$root/charts/mesh-egress" -f "$team_values" --set egress.useWaypoint=true | validate

echo "== rollback: enrolled=false removes the ambient label and the mesh-only NetworkPolicy"
rollback=$(render "$root/charts/mesh-namespace" -f "$team_values" --set enrolled=false)
validate <<<"$rollback"
if grep -q -E 'istio.io/dataplane-mode|kind: NetworkPolicy' <<<"$rollback"; then
  echo "rollback still enrols the namespace" >&2
  exit 1
fi

echo "== argocd"
validate <"$root/argocd/mesh-onboarding.yaml"

echo "== broken team values must be rejected"
expect_rejected() {
  local chart="$1"
  shift
  if render "$root/charts/$chart" -f "$team_values" "$@" >/dev/null 2>&1; then
    echo "not rejected: $chart $*" >&2
    exit 1
  fi
  echo "rejected as expected: $chart $*"
}
expect_rejected mesh-namespace --set namespace=Payments_Team
expect_rejected mesh-namespace --set 'allowFrom[0].serviceAccount=typo'
expect_rejected mesh-routes --set 'routes[0].rules[0].port=0'
expect_rejected mesh-egress --set 'egress.hosts[0].protocol=FTP'

echo "all charts are valid"
