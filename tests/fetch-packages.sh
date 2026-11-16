#!/usr/bin/env bash
#
# Downloads the Citrix packages the matrix needs into tests/.cache: the
# previous and the latest release, each as .deb, .rpm and tarball. Files that
# are already there are kept.
#
# usage: tests/fetch-packages.sh [OLD_RELEASE [NEW_RELEASE]]

set -euo pipefail

cd "$(dirname "$0")/.."

OLD_RELEASE=${1:-${OLD_RELEASE:-2604.10}}
NEW_RELEASE=${2:-${NEW_RELEASE:-2608}}

# One os-release sample per package type: .deb, .rpm, tarball.
SAMPLES="ubuntu-24.04:icaclient*_amd64.deb rockylinux-9:ICAClient-rhel-*.rpm rockylinux-10:linuxx64-*.tar.gz"

for release in "$OLD_RELEASE" "$NEW_RELEASE"; do
  dir="tests/.cache/$release"
  mkdir -p "$dir"
  for sample in $SAMPLES; do
    os=${sample%%:*}
    pattern=${sample#*:}
    if compgen -G "$dir/$pattern" >/dev/null; then
      echo "have $release $pattern"
      continue
    fi
    CTXUP_OS_RELEASE="tests/fixtures/os-release/$os" ./ctxup download --version "$release" --dir "$dir"
  done
done
