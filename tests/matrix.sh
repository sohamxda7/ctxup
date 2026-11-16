#!/usr/bin/env bash
#
# Runs tests/scenario.sh in a systemd container for every supported release.
#
# The Citrix packages are not downloaded here: put them in tests/.cache first
# (see README, "Running the tests"), so a full run does not fetch gigabytes
# from citrix.com.
#
# usage: tests/matrix.sh [-j JOBS] [TARGET ...]     (default: all targets)

set -euo pipefail

cd "$(dirname "$0")/.."

OLD_RELEASE=${OLD_RELEASE:-2604.10}
NEW_RELEASE=${NEW_RELEASE:-2608}
CACHE=tests/.cache
RESULTS=tests/.results
JOBS=3
# Set PODMAN="sudo podman" where rootless podman cannot run systemd.
read -r -a PODMAN <<<"${PODMAN:-podman}"

# target|base image|package type|does the old release work here
TARGETS='
ubuntu-22.04|docker.io/library/ubuntu:22.04|deb|ok
ubuntu-24.04|docker.io/library/ubuntu:24.04|deb|ok
ubuntu-26.04|docker.io/library/ubuntu:26.04|deb|unsupported
ubuntu-26.10|docker.io/library/ubuntu:26.10|deb|unsupported
debian-12|docker.io/library/debian:12|deb|ok
debian-13|docker.io/library/debian:13|deb|ok
rocky-8|quay.io/rockylinux/rockylinux:8|rpm|ok
rocky-9|quay.io/rockylinux/rockylinux:9|rpm|ok
rocky-10|quay.io/rockylinux/rockylinux:10|tarball|ok
alma-8|docker.io/library/almalinux:8|rpm|ok
alma-9|docker.io/library/almalinux:9|rpm|ok
alma-10|docker.io/library/almalinux:10|tarball|ok
fedora-44|docker.io/library/fedora:44|tarball|ok
fedora-45|docker.io/library/fedora:45|tarball|ok
'

if [[ ${1:-} == -j ]]; then
  JOBS=$2
  shift 2
fi

package() { # release type -> path inside the container
  local release=$1 type=$2 pattern file
  case $type in
    deb) pattern='icaclient*_amd64.deb' ;;
    rpm) pattern='ICAClient-rhel-*.x86_64.rpm' ;;
    *) pattern='linuxx64-*.tar.gz' ;;
  esac
  file=$(find "$CACHE/$release" -maxdepth 1 -name "$pattern" 2>/dev/null | head -n1)
  [[ -n $file ]] || {
    echo "missing $type package for $release in $CACHE/$release" >&2
    return 1
  }
  echo "/cache/$release/${file##*/}"
}

run_target() {
  local target=$1 base=$2 type=$3 expect=$4 family=rpm old new name="ctxup-matrix-$1" log="$RESULTS/$1.log"
  [[ $type == deb ]] && family=deb
  old=$(package "$OLD_RELEASE" "$type")
  new=$(package "$NEW_RELEASE" "$type")
  {
    "${PODMAN[@]}" build --quiet --build-arg "BASE=$base" -t "localhost/ctxup-test:$target" \
      -f "tests/containers/Containerfile.$family" tests/containers
    "${PODMAN[@]}" rm -f "$name" >/dev/null 2>&1 || true
    "${PODMAN[@]}" run -d --name "$name" --systemd=always --security-opt label=disable \
      -v "$PWD:/ctxup:ro" -v "$PWD/$CACHE:/cache:ro" "localhost/ctxup-test:$target"
    sleep 5
  } >"$log" 2>&1 || {
    echo "FAIL container-setup" >"$RESULTS/$target.steps"
    return 0
  }
  "${PODMAN[@]}" exec "$name" bash /ctxup/tests/scenario.sh "$old" "$new" "$expect" >"$RESULTS/$target.steps" 2>>"$log" || true
  {
    echo "===== scenario log"
    "${PODMAN[@]}" exec "$name" cat /tmp/scenario.log
    echo "===== ctxup log"
    "${PODMAN[@]}" exec "$name" cat /var/log/ctxup.log
  } >>"$log" 2>&1 || true
  "${PODMAN[@]}" rm -f "$name" >/dev/null 2>&1 || true
}

mkdir -p "$RESULTS"
selected=("$@")
running=0
names=()
while IFS='|' read -r target base type expect; do
  [[ -n $target ]] || continue
  if ((${#selected[@]})) && [[ " ${selected[*]} " != *" $target "* ]]; then
    continue
  fi
  names+=("$target")
  rm -f "$RESULTS/$target.steps"
  echo "starting $target" >&2
  run_target "$target" "$base" "$type" "$expect" &
  running=$((running + 1))
  if ((running >= JOBS)); then
    wait -n || true
    running=$((running - 1))
  fi
done <<<"$TARGETS"
wait

failed=0
printf '\n%-14s %s\n' TARGET RESULT
for target in "${names[@]}"; do
  steps="$RESULTS/$target.steps"
  if [[ ! -s $steps ]]; then
    printf '%-14s %s\n' "$target" "no result (see $RESULTS/$target.log)"
    failed=1
    continue
  fi
  bad=$(grep -c '^FAIL' "$steps" || true)
  total=$(grep -c '' "$steps")
  if [[ $bad -eq 0 ]]; then
    printf '%-14s %s\n' "$target" "all $total steps passed"
  else
    printf '%-14s %s\n' "$target" "$bad of $total failed: $(grep '^FAIL' "$steps" | cut -d' ' -f2 | tr '\n' ' ')"
    failed=1
  fi
done
exit "$failed"
