#!/usr/bin/env bash
# Installs a pinned kubeconform release on a Linux CI runner and verifies its checksum.
#
# Usage: scripts/install-kubeconform.sh <version>, for example v0.8.0

set -euo pipefail

version="${1:?usage: install-kubeconform.sh <version>}"
asset="kubeconform-linux-amd64.tar.gz"
base="https://github.com/yannh/kubeconform/releases/download/${version}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/$asset" "$base/$asset"
curl -fsSL -o "$tmp/CHECKSUMS" "$base/CHECKSUMS"
(cd "$tmp" && grep " ${asset}\$" CHECKSUMS | sha256sum -c -)

tar -xzf "$tmp/$asset" -C "$tmp" kubeconform
sudo install -m 0755 "$tmp/kubeconform" /usr/local/bin/kubeconform
kubeconform -v
